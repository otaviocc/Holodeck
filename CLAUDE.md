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

Five-target SwiftPM package with strict downward-only dependencies:

```
holodeck (executable, ArgumentParser subcommands) ─┐
HolodeckTUI (raw-mode renderer + reducer + driver) ─┼─> HolodeckServices ─> HolodeckCore
                                                    │
                                  (executable also depends on Services + Core)

HolodeckTestSupport (mock factories + test helpers) ─> HolodeckServices, HolodeckCore
  (depended on only by the three test targets; never linked into production)
```

Layer purposes:

- **HolodeckCore** — models plus the I/O-owning protocol witnesses (`SimctlClient`, `Recorder`, `URLHistoryStore`, `HolodeckConfigResolver`), `ProcessRunner`, `Config`/`ConfigLoader`, `DefaultMediaPath`. No UI, no service composition. The witnesses are `Sendable` structs of `@Sendable` closure properties; each has a `.live(...)` factory that builds the real implementation. `Recorder.live()` is backed by a private `RecorderActor` that owns the long-running `Process`.
- **HolodeckServices** — facades (`SimulatorService`, `ScreenshotService`, `AppearanceService`, `StatusBarService`, `LocaleService`, `PrivacyService`, `KeychainService`, `LocationService`) plus the `RecordingService` witness and the `AppDependencies` composition root. The facades are thin `Sendable` structs wrapping a `SimctlClient`; they exist as a stable seam, not to add behavior, except for `SimulatorService.resolve(query:)` which carries the exact/substring/ambiguous matching logic.
- **HolodeckTUI** — pure reducer + impure driver:
  - `AppState`, `Reducer`, `ModalReducer`/`WizardReducer` are pure: `(state, event) -> (state, [SideEffect])`. All keypress/event handling lives here and is fully unit-tested.
  - `HolodeckApp` (`final class`) takes an `AppDependencies` (default `.live()`), owns the alt-screen, raw-mode terminal, signal handlers, event loop, and renders by writing ANSI to stdout. It dispatches each `SideEffect` to a static helper in `AppSpawn` which spawns a `Task.detached` and yields the response back into the event stream.
  - `SimulatorListView` is a pure `(AppState) -> String` renderer. Help, recording banner, modals, and the create wizard are all branches of this single function.
- **holodeck** (executable) — `ArgumentParser` subcommands. Enum-to-CLI conversions (`Platform`, `VideoCodec`, `ScreenshotType`, `Appearance`, `BatteryState`) live in `Sources/holodeck/ArgumentParserSupport.swift` as `ExpressibleByArgument` extensions, alongside a `SimulatorService.resolveInState(_:state:purpose:)` helper that consolidates the "resolve query and validate state" pattern used across most commands. Commands that need config (`list`, `record`, `screenshot`) and the TUI build `AppDependencies.live()` at the top of `run()`; simpler commands still construct individual facade services with their default-arg `SimctlClient`.
- **HolodeckTestSupport** — library target hosting every `.mock(...)` factory (one file per witness in `Sources/HolodeckTestSupport/Mocks/`), the `MockHistoryStorage` helper, and a `withTemporaryDirectory(_:)` test helper (sync + async overloads). All three test targets depend on it.

## Design patterns

### Protocol witnesses

Every type that owns I/O is a `Sendable` struct of `@Sendable` closure properties:

```swift
public struct URLHistoryStore: Sendable {
    public var load: @Sendable () -> [String]
    public var record: @Sendable (String) throws -> [String]
    package init(load: ..., record: ...) { ... }
}

public extension URLHistoryStore {
    static func live(configResolver: HolodeckConfigResolver) -> Self { ... }
}
```

Rules of the pattern as applied here:

- **Closures are the public API.** No wrapper methods that forward to underscored backing properties. Callers do `store.load()`, `recorder.start(path, args)` — losing argument labels at multi-arg call sites is the accepted cost. The exception is `SimctlClient`: it kept underscore-backed wrappers in an earlier iteration but those have been removed too, so callers now use positional args at the 30+ facade-service and test sites.
- **`.live(...)` and `.mock(...)` are the only construction paths.** The memberwise init is `package`-access, not `public`. Callers go through factories. `SimctlClient.init(runner:)` is a `package` convenience that delegates to `.live(runner:)`, kept because facade services use `SimctlClient()` as a default argument.
- **`.live` factories live next to the type** in production source. **`.mock` factories live in `HolodeckTestSupport`** so production code never links them. Default closures in `.mock` are no-ops or empty-collection returns (`{ _ in [] }`), so a test only overrides the closures it cares about.
- **Stateful witnesses delegate to a private actor.** `Recorder.live()` constructs a `RecorderActor` (owns the `Process`); `RecordingService.live()` constructs a `RecordingState` actor (tracks `currentOutput`). The witness's closures capture the actor and forward.

### Dependency injection via `AppDependencies`

`Sources/HolodeckServices/AppDependencies.swift` is the composition root. It's a `Sendable` struct holding `configuration`, `simulatorClient`, `urlHistoryStore`, and all eight facade services. Two public factories:

- `.live(configResolver:simulatorClient:recorder:)` — defaults wire the real graph. The internal `make(configuration:simulatorClient:urlHistoryStore:recordingService:)` helper constructs all eight facade services from one `SimctlClient`.
- `.mock(configuration:simulatorClient:urlHistoryStore:recordingService:)` — in `HolodeckTestSupport`. Each parameter defaults to its witness's `.mock()`, so `AppDependencies.mock()` is a fully fake graph with one keystroke.

Tests pass a custom `AppDependencies` (or skip it entirely if they only need one witness — the `.mock()` factories work standalone).

### Cross-target access with `package`

Witness memberwise inits, `URLHistoryStore.updated(_:inserting:)`, and `ConfigFileName` use Swift 6.2's `package` access. That lets `HolodeckTestSupport` reach them without `@testable` (which only works for test targets, not library targets). External SwiftPM consumers of `HolodeckCore`/`HolodeckServices` only see the `.live(...)` / `.mock(...)` factories.

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

`Config.swift` defines a JSON-backed user config read from `~/.config/holodeck/config.json` (honors `$XDG_CONFIG_HOME`). Missing file → defaults; malformed JSON or unknown enum values → typed error. CLI flags override config; config overrides hard-coded defaults.

The location is resolved by `HolodeckConfigResolver` (a witness): `.live()` honors `$XDG_CONFIG_HOME` with a `~/.config/holodeck` fallback; `.mock(base:)` (in `HolodeckTestSupport`) points at an arbitrary directory for tests. Both `ConfigLoader` and `URLHistoryStore.live` take a `HolodeckConfigResolver`, so swapping the resolver redirects every read/write — there is no parameterless `ConfigLoader()` / `URLHistoryStore()` constructor that hides the dependency.

`HolodeckApp` takes an `AppDependencies` in init (default `.live()`); CLI commands that need config build `AppDependencies.live()` and read `dependencies.configuration`. See README for the schema.
