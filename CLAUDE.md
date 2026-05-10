# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Build, run, and test from the repo root:

```
swift build                    # debug build
swift test                     # all tests (uses Swift Testing, not XCTest)
swift test --filter <Suite>    # run one suite, e.g. --filter ReducerTests
swift run holodeck list        # exercise a CLI subcommand
swift run holodeck --help      # see the full subcommand surface
swiftformat Sources Tests      # apply formatting (.swiftformat)
swiftlint --quiet              # apply lint (.swiftlint.yml)
```

Tests use the Swift Testing framework — `@Test`, `#expect`, `try #require`, `Issue.record` — not `XCTest`. The TUI itself can't run under `swift test`; verify it interactively with `swift run holodeck`.

### Toolchain note

The project targets Swift 6.2+. If `swift --version` reports an older Swift than the installed Xcode SDK (e.g. system Swift 5.9 with the MacOSX26.x SDK), the build fails parsing the Foundation interface. Either install a current toolchain via `swiftly` (`swiftly install latest && swiftly use latest`) or invoke `xcrun swift …` to use Xcode's bundled compiler.

## Architecture

Four-target SwiftPM package with strict downward-only dependencies:

```
holodeck (executable, ArgumentParser subcommands) ─┐
HolodeckTUI (raw-mode renderer + reducer + driver) ─┼─> HolodeckServices ─> HolodeckCore
                                                    │
                                  (executable also depends on Services + Core)
```

Layer purposes:

- **HolodeckCore** — models, `SimctlClient` (a `Sendable struct` shelling out to `xcrun simctl`), `ProcessRunner`, `Recorder` (the only actor — owns a long-running child process), `Config`, `DefaultMediaPath`. No UI, no service composition.
- **HolodeckServices** — thin facades (`SimulatorService`, `RecordingService`, `ScreenshotService`, `AppearanceService`, `StatusBarService`, `LocaleService`). They exist as a stable seam for the TUI and CLI, not to add behavior.
- **HolodeckTUI** — pure reducer + impure driver:
  - `AppState`, `Reducer`, `ModalReducer`/`WizardReducer` are pure: `(state, event) -> (state, [SideEffect])`. All keypress/event handling lives here and is fully unit-tested.
  - `HolodeckApp` (`final class`) owns the alt-screen, raw-mode terminal, signal handlers, event loop, and renders by writing ANSI to stdout. It dispatches each `SideEffect` to a static helper in `AppSpawn` which spawns a `Task.detached` and yields the response back into the event stream.
  - `SimulatorListView` is a pure `(AppState) -> String` renderer. Help, recording banner, modals, and the create wizard are all branches of this single function.
- **holodeck** (executable) — `ArgumentParser` subcommands. Enum-to-CLI conversions (`Platform`, `VideoCodec`, `ScreenshotType`, `Appearance`, `BatteryState`) live in `Sources/holodeck/ArgumentParserSupport.swift` as `ExpressibleByArgument` extensions, alongside a `SimulatorService.resolveInState(_:state:purpose:)` helper that consolidates the "resolve query and validate state" pattern used across most commands.

### Things that are easy to break

- **`ProcessRunner` pipe drain** — stdout and stderr must be drained concurrently (via `async let`), not sequentially. `simctl list --json` output frequently exceeds the 64 KB pipe buffer; sequential drain deadlocks on the 2-second TUI poll path.
- **Recording stop** — `Recorder.stop()` calls `Process.interrupt()` (SIGINT), not `terminate()` / `kill()`. Only SIGINT lets `simctl io recordVideo` finalize a valid MP4. The CLI `record` command installs a `DispatchSourceSignal` handler that forwards Ctrl-C through the same path; the TUI reducer's `r`/`q` keys do the same via `.stopRecording`.
- **TUI render guard** — `HolodeckApp.render()` short-circuits when `state == lastRenderedState`. Effects that produce identical states must be allowed to be no-ops; don't introduce always-mutating updates into the reducer.
- **Polling pause during recording** — `Reducer.reduce` on `.pollTick` returns no effects while `state.isRecording` is true. Don't fire fresh refresh tasks from anywhere else during recording.

## Conventions

- **Swift Testing test names** use `@Test("It should …")` describing observable behavior. Helper builders on test suites can `throw` and use `try #require(...)` for unwrap.
- **`// MARK: -` section headers** within a type body use exactly these five names, in this fixed order, and only when the type has 2+ of these sections:
  ```
  // MARK: - Nested types
  // MARK: - Properties
  // MARK: - Lifecycle
  // MARK: - Public
  // MARK: - Private
  ```
  Trivial types (pure enums with just cases, structs with only stored properties) get no MARKs. Declarations within a type are ordered to match.
- **`.swiftformat`** ships with the project: `--organize-types`, MIT license header inserted on every file, 4-space indent, 120-col wrap, type/extension MARKs enabled. Run `swiftformat Sources Tests` before committing.
- **`.swiftlint.yml`** opts in to several rules and excludes a handful of short identifiers (`up/down/left/right/dt/id`). Function and type body length thresholds are enforced — use `// swiftlint:disable function_body_length` around the specific function when it's genuinely required (e.g., `Reducer.reduce`, `WizardReducer.handle`). Both build/lint/tests must be clean before committing.

## Configuration

`Config.swift` defines a JSON-backed user config read from `~/.config/holodeck/config.json` (honors `$XDG_CONFIG_HOME`). Missing file → defaults; malformed JSON or unknown enum values → typed error. CLI flags override config; config overrides hard-coded defaults. The `HolodeckApp` takes a `Config` in init; CLI commands call `ConfigLoader.loadOrDefault()` themselves. See README for the schema.
