# holodeck (Rust port)

A Rust port of [Holodeck](https://github.com/otaviocc/Holodeck) — a macOS CLI
and TUI for managing iOS simulators — using [ratatui](https://ratatui.rs) for
the terminal UI instead of a hand-rolled renderer.

See the port plan for the full effort analysis, phase breakdown, and risk
register this crate layout follows.

## Status

**All 5 phases done, plus theming.** Every crate is ported and verified
end-to-end against real `xcrun simctl` on this machine — not just
unit-tested. 179 tests pass across the workspace (`cargo test --workspace`),
`cargo clippy --workspace --all-targets -- -D warnings` is clean, and `cargo
fmt --all -- --check` is clean.

The TUI ships with 8 built-in color themes (default:
[Default+](https://github.com/otaviocc/default-plus)) — see
[Theming](#theming) below.

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
- **holodeck-tui**: the pure `state/` layer (`AppState`, `Modal`, `AppEvent`,
  `SideEffect`, `PaletteCommand`, and the 6 reducers) ported near 1:1 from the
  Swift Elm/TEA architecture, plus a from-scratch ratatui rendering layer
  (`view.rs`) covering all 10 render paths (main list, help, inline
  appearance/confirm banners, inspector, open-URL prompt, create wizard,
  privacy wizard, command-palette overlay) and an `app.rs` event loop —
  `ratatui::init()`/`restore()` for terminal lifecycle, a background OS
  thread doing blocking `crossterm::event::poll`/`read` for input (no
  `event-stream` feature needed, and no second `crossterm` dependency
  declaration — see the crate's `Cargo.toml` comment), a `tokio::time::interval`
  poll-tick task, and one generic `spawn`/`spawn_per_simulator` pair replacing
  the ~18 near-identical `AppSpawn` helpers from the Swift original.

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

The CLI was exercised end-to-end for boot/shutdown idempotence, ambiguous-match
and not-found errors, the `y/N` confirm prompt (erase), validation errors
(statusbar override with no fields, privacy grant without a bundle ID,
delete/erase with neither a query nor a flag), and a real screenshot capture.
The TUI was driven interactively under a real PTY (via a small Python harness
allocating a pty and setting its window size, since this environment has no
attached terminal) — real simulator data rendered correctly (runtime grouping,
states, status bar), `j`/`k` navigation, the `?` help overlay, and `q` all
worked, with the terminal cleanly restored (`\x1b[?1049l\x1b[?25h`) on exit
rather than left in alt-screen/hidden-cursor state.

## Theming

The TUI's colors are a `Theme` struct of named semantic styles
(`crates/holodeck-tui/src/theme.rs`) rather than `Color` literals scattered
through the view layer — architecture borrowed from
[vigia](https://github.com/breferrari/vigia)'s `theme.rs`. Set `theme` in
`~/.config/holodeck/config.json` to any of the values below (default:
`default-plus`):

| `theme` value | Theme | Source |
| --- | --- | --- |
| `default-plus` | Default+ *(default)* | [otaviocc/default-plus](https://github.com/otaviocc/default-plus) |
| `ansi` | Terminal's own 16-color scheme | — |
| `tokyo-night` | Tokyo Night | [folke/tokyonight.nvim](https://github.com/folke/tokyonight.nvim) |
| `nord` | Nord | [nordtheme.com](https://www.nordtheme.com) |
| `dracula` | Dracula | [draculatheme.com](https://draculatheme.com) |
| `gruvbox` | Gruvbox (dark) | [morhetz/gruvbox](https://github.com/morhetz/gruvbox) |
| `catppuccin-mocha` | Catppuccin Mocha | [catppuccin.com](https://catppuccin.com) |
| `solarized-dark` | Solarized Dark | [ethanschoonover.com/solarized](https://ethanschoonover.com/solarized/) |

```json
{
  "theme": "nord"
}
```

Every built-in (aside from `ansi`, which intentionally inherits whatever the
reader's terminal defines) is ported verbatim from that project's own
canonical palette — see `Theme::default_plus()`/`Theme::nord()`/etc. in
`theme.rs` for the exact hex values and a note on any per-theme quirks (e.g.
Dracula has no distinct "blue" and borrows its purple for that slot, matching
Dracula's own ANSI spec).

## Crate layout

```
crates/holodeck-core/      models, SimctlClient trait + Live impl, decoders, config, recorder
crates/holodeck-services/  SimulatorService/RecordingService/ScreenshotService + AppDependencies
crates/holodeck-tui/       state/ (pure, 6 reducers) + app.rs (event loop) + view.rs (ratatui) + theme.rs + input.rs
crates/holodeck-cli/       18 clap subcommands, bin: holodeck
```

## Commands

```bash
cargo build --workspace
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check

# Launch the TUI (needs a real terminal):
cargo run -p holodeck -- tui        # or just: cargo run -p holodeck

# Manual smoke tests against real xcrun simctl (not part of `cargo test`):
cargo run -p holodeck-core --example smoke
cargo run -p holodeck-core --example record_smoke -- <booted-udid>
```
