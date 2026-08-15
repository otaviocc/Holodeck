# holodeck

A macOS CLI and TUI for managing iOS simulators, built with
[ratatui](https://ratatui.rs).

```bash
holodeck                                 # full-screen TUI (default)
holodeck list                            # scripting subcommands for CI / shell composition
holodeck boot "iPhone 17 Pro"
holodeck record "iPhone 17 Pro" -o demo.mp4
```

## Status

179 tests pass across the workspace (`cargo test --workspace`), `cargo
clippy --workspace --all-targets -- -D warnings` is clean, and `cargo fmt
--all -- --check` is clean.

- **holodeck-core**: models, the 20-operation `simctl` client, JSON
  decoders, config loading, URL history, default media paths, and the
  SIGINT-based video recorder.
- **holodeck-services**: `SimulatorService` (name/UDID resolution with
  exact/substring/ambiguous matching), the stateful `RecordingService`,
  `ScreenshotService`, and the `AppDependencies` composition root.
- **holodeck CLI**: 18 subcommands (`list`, `boot`, `shutdown`, `record`,
  `screenshot`, `appearance`, `statusbar override|clear`, `locale`, `create`,
  `erase`, `delete`, `focus`, `location set|clear`, `privacy`, `keychain
  reset`, `apps list`, `openurl`, `tui`). Bare `holodeck` defaults to `tui`.
- **holodeck-tui**: a pure `state/` layer (`AppState`, `Modal`, `AppEvent`,
  `SideEffect`, `PaletteCommand`, and 6 reducers) driving a ratatui rendering
  layer (`view.rs`) across 10 screens (main list, help, inline
  appearance/confirm banners, inspector, open-URL prompt, create wizard,
  privacy wizard, command-palette overlay), plus an `app.rs` event loop using
  `ratatui::init()`/`restore()` for terminal lifecycle, a background thread
  for input, and a `tokio::time::interval` poll-tick task.

## Theming

The TUI's colors are a `Theme` struct of named semantic styles
(`crates/holodeck-tui/src/theme.rs`) rather than `Color` literals scattered
through the view layer. Set `theme` in `~/.config/holodeck/config.json` to
any of the values below (default: `default-plus`):

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

## Configuration

`~/.config/holodeck/config.json` (honors `$XDG_CONFIG_HOME`) is read once at
launch. A missing file uses the defaults below; a malformed file errors out.
All fields are optional.

```json
{
  "defaultPlatform": "iOS",
  "screenshotsDirectory": "~/Desktop",
  "videoCodec": "h264",
  "screenshotType": "png",
  "pollIntervalSeconds": 2.0,
  "theme": "default-plus"
}
```

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
