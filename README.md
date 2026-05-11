# holodeck

A macOS CLI and TUI for managing iOS simulators. A Swift replacement for ad-hoc
`xcrun simctl` wrappers, built as a single SwiftPM binary with no external
runtime dependencies beyond `swift-argument-parser`.

```
holodeck                # full-screen TUI (default)
holodeck list           # scripting subcommands for CI / shell composition
holodeck boot "iPhone 17 Pro"
holodeck record "iPhone 17 Pro" -o demo.mp4
```

## Requirements

- macOS with Xcode installed (`simctl` lives there)
- Swift 6.2+ (via `swiftly` or the Xcode toolchain — `xcrun swift` works)

## Build

```
swift build -c release
cp .build/release/holodeck /usr/local/bin/   # or anywhere on PATH
```

For development, `swift build`, `swift test`, and `swift run holodeck …` all
work from the repo root.

## CLI

| Command | Notes |
| --- | --- |
| `list [--platform ios\|watchos\|tvos\|visionos] [--json]` | Grouped table by runtime. `--json` emits a machine-readable array. |
| `boot <name-or-udid>` | Fuzzy-resolves the name; ambiguous matches error out with candidates. |
| `shutdown <name-or-udid>` | Same name resolution as `boot`. |
| `record <name-or-udid> [-o path] [--codec h264\|hevc]` | Ctrl-C cleanly finalizes the MP4 (forwards SIGINT to `simctl io`). |
| `screenshot <name-or-udid> [-o path] [--type png\|jpeg\|tiff\|bmp]` | Prints the saved path. |
| `appearance <name-or-udid> light\|dark` | Booted simulators only. |
| `statusbar override <name> [--time --battery-state --battery-level --wifi-bars --cellular-bars --operator-name]` | Overrides reset on shutdown. |
| `statusbar clear <name>` | |
| `locale <name-or-udid> <bcp47>` | e.g. `en`, `en-US`, `pt-BR`. Writes both `AppleLanguages` and `AppleLocale`; reboot the simulator to apply. |
| `create <name> --device <substr> --runtime <substr>` | Substring-fuzzy matches against the live device-type / runtime catalog. |
| `erase <name-or-udid>` / `erase --all` | Prompts before erasing; `-y` skips. |
| `delete <name-or-udid>` / `delete --unavailable` | Prompts before deleting; `-y` skips. |

Run `holodeck --help` or `holodeck <sub> --help` for the authoritative usage.

## TUI

Run `holodeck` with no arguments. The TUI polls `simctl list --json` every two
seconds (polling pauses during recording) and uses a pure reducer
(`state, event → state, effects`) so screen updates and keybindings stay
testable.

| Key | Action |
| --- | --- |
| `↑ ↓` / `j k` | Navigate the simulator list |
| `Enter` / `Space` | Boot or shut down the selection |
| `R` | Force refresh |
| `r` | Start / stop recording (modal banner while active) |
| `p` | Screenshot |
| `a` | Appearance submenu (`l` light / `d` dark / `Esc` cancel) |
| `n` | New simulator wizard (pick device type → runtime → confirm) |
| `e` | Erase (shut-down simulators only; `y`/`n` confirm) |
| `d` | Delete (`y`/`n` confirm) |
| `?` | Help overlay |
| `q` / `Esc` | Quit (or cancel the active modal) |

The terminal enters the alt-screen and raw mode on launch; SIGINT, SIGTERM, and
SIGHUP handlers restore the terminal before exit so a crash never leaves the
shell broken.

## Configuration

holodeck reads `~/.config/holodeck/config.json` (or `$XDG_CONFIG_HOME/holodeck/config.json`).
A missing file falls back to defaults; malformed JSON or unknown enum values
raise an error. Sample:

```json
{
  "defaultPlatform": "iOS",
  "screenshotsDirectory": "~/Captures",
  "videoCodec": "hevc",
  "screenshotType": "png",
  "pollIntervalSeconds": 2.0
}
```

| Field | Default | Affects |
| --- | --- | --- |
| `defaultPlatform` | `null` | `list --platform` and (eventually) TUI default filter |
| `screenshotsDirectory` | `~/Desktop` | Default output dir for `record` and `screenshot` |
| `videoCodec` | `h264` | `record --codec` default |
| `screenshotType` | `png` | `screenshot --type` default |
| `pollIntervalSeconds` | `2.0` | TUI refresh cadence |

CLI flags always win over config; config wins over hard-coded defaults.

## Architecture

```
┌─────────────────────────────────────────┐
│  Presentation (HolodeckTUI + holodeck)  │  ← argument-parser subcommands, raw-mode TUI
├─────────────────────────────────────────┤
│  HolodeckServices                       │  ← SimulatorService, RecordingService, etc.
├─────────────────────────────────────────┤
│  HolodeckCore                           │  ← models, SimctlClient (actor), ProcessRunner
└─────────────────────────────────────────┘
```

- `SimctlClient` shells out to `xcrun simctl` and decodes `--json` output with
  `Codable` — no regex parsing of the human-readable form.
- `ProcessRunner` is an injectable protocol; services can be unit-tested with
  stubs (though most tests just hit the real reducer / decoder / `Process`).
- The TUI is pure-data-driven: `Reducer.reduce` returns the next `AppState`
  plus a list of `SideEffect` values; `HolodeckApp` dispatches each effect on a
  detached `Task` and feeds responses back into the event stream.
- Recording uses `Process.interrupt()` (SIGINT) to stop `simctl io recordVideo`
  so the MP4 finalizes cleanly. SIGKILL would corrupt the file.

## Tests

```
swift test
```

Covers JSON decoding (against a captured fixture), input parsing, the full
reducer (navigation, recording state, lifecycle modals, wizard), terminal-mode
basics, the config loader, and `Recorder`'s interrupt-and-wait semantics.

## Linting and formatting

Project ships `.swiftformat` and `.swiftlint.yml` configurations.

```
swiftformat Sources Tests
swiftlint --quiet
```

Both should run clean on a fresh checkout.

## License

MIT — see file headers.
