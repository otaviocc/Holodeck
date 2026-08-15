# holodeck (Rust port)

A Rust port of [Holodeck](https://github.com/otaviocc/Holodeck) — a macOS CLI
and TUI for managing iOS simulators — using [ratatui](https://ratatui.rs) for
the terminal UI instead of a hand-rolled renderer.

See the port plan for the full effort analysis, phase breakdown, and risk
register this crate layout follows.

## Status

**Phase 1 (holodeck-core) — done.** `crates/holodeck-core` reimplements every
model, the 20-operation `simctl` client, both JSON decoders, config loading,
URL history, default media paths, and the SIGINT-based video recorder. 63
tests pass (`cargo test -p holodeck-core`), and two real-hardware risks called
out in the port plan have been verified against actual `xcrun simctl` on this
machine:

- `simctl listapps` emits an OpenStep/ASCII plist with no `--json` option and
  no pure-Rust parser reads that format. Piping through
  `plutil -convert json -o - -` (see `SimctlClient::list_apps`) works — 42
  apps decoded correctly against a real booted simulator.
- `Recorder::stop()` sends SIGINT via `libc::kill`, not `Child::kill()`
  (SIGKILL), because only SIGINT lets `simctl io recordVideo` finalize a valid
  MP4. Confirmed with `ffprobe` against a real recording — valid H.264/MP4
  container, not a truncated file.

Not yet implemented: `crates/holodeck-services` (Phase 2), the `holodeck` CLI
(Phase 3), and the ratatui TUI (Phases 4–5) — all present as workspace members
with stub crates so `cargo build --workspace` succeeds.

## Crate layout

```
crates/holodeck-core/      models, SimctlClient trait + Live impl, decoders, config, recorder
crates/holodeck-services/  facades + AppDependencies-equivalent          (Phase 2)
crates/holodeck-tui/       state/ (pure) + ratatui rendering             (Phases 4-5)
crates/holodeck-cli/       clap subcommands, bin: holodeck               (Phase 3)
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
