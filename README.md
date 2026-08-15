# holodeck (Rust port)

A Rust port of [Holodeck](https://github.com/otaviocc/Holodeck) — a macOS CLI
and TUI for managing iOS simulators — using [ratatui](https://ratatui.rs) for
the terminal UI instead of a hand-rolled renderer.

See the port plan for the full effort analysis, phase breakdown, and risk
register this crate layout follows.

## Status

**Phases 1-3 — done.** `crates/holodeck-core`, `crates/holodeck-services`, and
the `holodeck` CLI (`crates/holodeck-cli`) are fully ported and verified
end-to-end against real `xcrun simctl` on this machine — not just unit-tested.
77 tests pass across the workspace (`cargo test --workspace`).

- **holodeck-core**: every model, the 20-operation `simctl` client, both JSON
  decoders, config loading, URL history, default media paths, and the
  SIGINT-based video recorder.
- **holodeck-services**: `SimulatorService::resolve` (exact/substring/
  ambiguous precedence), the stateful `RecordingService`, `ScreenshotService`,
  and the `AppDependencies` composition root. The other Swift facades
  (appearance, locale, location, privacy, status bar, keychain) were collapsed
  — callers hold the `SimctlClient` trait object directly instead.
- **holodeck CLI**: all 18 subcommands (`list`, `boot`, `shutdown`, `record`,
  `screenshot`, `appearance`, `statusbar override|clear`, `locale`, `create`,
  `erase`, `delete`, `focus`, `location set|clear`, `privacy`, `keychain
  reset`, `apps list`, `openurl`, `tui`), with the bare `holodeck` invocation
  defaulting to `tui` exactly like the Swift `defaultSubcommand`.

Two real-hardware risks called out in the port plan have been verified against
actual `xcrun simctl` on this machine, not just reasoned about:

- `simctl listapps` emits an OpenStep/ASCII plist with no `--json` option and
  no pure-Rust parser reads that format. Piping through
  `plutil -convert json -o - -` (see `SimctlClient::list_apps`) works — 42
  apps decoded correctly against a real booted simulator, and `holodeck apps
  list` prints them in both table and `--json` form.
- `Recorder::stop()` sends SIGINT via `libc::kill`, not `Child::kill()`
  (SIGKILL), because only SIGINT lets `simctl io recordVideo` finalize a valid
  MP4. Confirmed with `ffprobe` against a real recording — valid H.264/MP4
  container, not a truncated file.

The CLI was also exercised end-to-end for boot/shutdown idempotence,
ambiguous-match and not-found errors, the `y/N` confirm prompt (erase),
validation errors (statusbar override with no fields, privacy grant without a
bundle ID, delete/erase with neither a query nor a flag), and a real
screenshot capture.

Not yet implemented: the ratatui TUI (Phases 4-5, `crates/holodeck-tui`) —
present as a stub crate so `cargo build --workspace` succeeds and `holodeck
tui` / bare `holodeck` print a "not yet ported" message instead of launching.

## Crate layout

```
crates/holodeck-core/      models, SimctlClient trait + Live impl, decoders, config, recorder
crates/holodeck-services/  SimulatorService/RecordingService/ScreenshotService + AppDependencies
crates/holodeck-tui/       state/ (pure) + ratatui rendering             (Phases 4-5, not yet done)
crates/holodeck-cli/       18 clap subcommands, bin: holodeck
```

## Commands

```bash
cargo build --workspace
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check

# Manual smoke tests against real xcrun simctl (not part of `cargo test`):
cargo run -p holodeck-core --example smoke
cargo run -p holodeck-core --example record_smoke -- <booted-udid>
```
