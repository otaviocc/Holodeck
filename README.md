# holodeck

A macOS CLI and TUI for managing iOS simulators, built with
[ratatui](https://ratatui.rs).

<img width="1351" height="952" alt="Screenshot" src="https://github.com/user-attachments/assets/08508b9d-ee81-4fd2-89d6-89c7c0b5ed8d" />

> This is a Rust rewrite of the original Swift implementation, which remains
> available on the [`swift` branch](https://github.com/otaviocc/Holodeck/tree/swift).

```bash
holodeck                                 # full-screen TUI (default)
holodeck list                            # scripting subcommands for CI / shell composition
holodeck boot "iPhone 17 Pro"
holodeck record "iPhone 17 Pro" -o demo.mp4
```

## Install

### Homebrew

```bash
brew install otaviocc/apps/holodeck
```

Builds from source on your machine — no signing or notarization involved,
and no Gatekeeper prompt on first run.

### Cargo

```bash
cargo install holodeck-simctl
```

Or, for a specific tag from source:

```bash
cargo install --git https://github.com/otaviocc/Holodeck --tag v0.5.0 holodeck-simctl --locked
```

Both require Xcode (`xcrun simctl` must be on `PATH`) and, for Cargo, a Rust
1.88+ toolchain.

## Usage

Run `holodeck` with no arguments to launch the TUI. For scripting, every
subcommand accepts `--help`:

```bash
holodeck --help              # all subcommands
holodeck record --help       # one subcommand's options
```

| Subcommand | What it does |
| --- | --- |
| `list` | List simulators |
| `boot` / `shutdown` | Boot or shut down a simulator |
| `create` | Create a new simulator |
| `erase` / `delete` | Erase a simulator's contents, or delete it entirely |
| `focus` | Bring Simulator.app to the front |
| `record` | Record a video |
| `screenshot` | Capture a screenshot |
| `appearance` | Set light or dark appearance |
| `statusbar override` / `statusbar clear` | Override or clear status bar fields |
| `locale` | Set the simulator's locale |
| `location set` / `location clear` | Set or clear the simulated GPS location |
| `privacy` | Grant, revoke, or reset a privacy permission |
| `keychain reset` | Reset the simulator's keychain |
| `apps list` | List installed apps |
| `openurl` | Open a URL or deep link |
| `tui` | Launch the interactive TUI (same as bare `holodeck`) |

Every command that takes a simulator accepts either its full UDID or a
name/substring (e.g. `"iPhone 17 Pro"` or just `"17 Pro"`).

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
crates/holodeck-core/      pkg: holodeck-simctl-core, models, SimctlClient trait + Live impl, decoders, config, recorder
crates/holodeck-services/  pkg: holodeck-simctl-services, SimulatorService/RecordingService/ScreenshotService + AppDependencies
crates/holodeck-tui/       pkg: holodeck-simctl-tui, state/ (pure, 6 reducers) + app.rs (event loop) + view.rs (ratatui) + theme.rs + input.rs
crates/holodeck-cli/       pkg: holodeck-simctl, 18 clap subcommands, bin: holodeck
```

Package names carry a `holodeck-simctl` prefix for crates.io (the bare
`holodeck`/`holodeck-core` names were already taken by unrelated crates); the
binary is still `holodeck` and the Rust import paths are still
`holodeck_core`/`holodeck_services`/`holodeck_tui` (remapped via `package =`
in the workspace `Cargo.toml`).

## Commands

```bash
cargo build --workspace
cargo test --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo fmt --all -- --check

# Launch the TUI (needs a real terminal):
cargo run -p holodeck-simctl -- tui        # or just: cargo run -p holodeck-simctl

# Manual smoke tests against real xcrun simctl (not part of `cargo test`):
cargo run -p holodeck-simctl-core --example smoke
cargo run -p holodeck-simctl-core --example record_smoke -- <booted-udid>
```
