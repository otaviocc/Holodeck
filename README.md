# holodeck

<img width="1059" height="664" alt="" src="https://github.com/user-attachments/assets/ad98aab5-a791-476c-80b2-e2b96a57f6a4" />

A macOS CLI and TUI for managing iOS simulators. A Swift replacement for ad-hoc
`xcrun simctl` wrappers, built as a single SwiftPM binary with no external
runtime dependencies beyond `swift-argument-parser`.

```bash
holodeck                                 # full-screen TUI (default)
holodeck list                            # scripting subcommands for CI / shell composition
holodeck boot "iPhone 17 Pro"
holodeck record "iPhone 17 Pro" -o demo.mp4
```

## Install

### Mint

[Mint](https://github.com/yonaskolb/Mint) is the easiest path:

```bash
mint install otaviocc/Holodeck
```

This pulls a tagged release, builds it once, and drops `holodeck` on your
`PATH`.

### Build from source

```bash
git clone https://github.com/otaviocc/Holodeck.git
cd Holodeck
swift build -c release
cp .build/release/holodeck /usr/local/bin/   # or anywhere on PATH
```

Requirements: macOS with Xcode installed (`simctl` lives there) and Swift 6.2+
— either via [`swiftly`](https://github.com/swiftlang/swiftly) or the Xcode
toolchain (`xcrun swift …` works).

For development, `swift build`, `swift test`, and `swift run holodeck …` all
work from the repo root.

## Quick start

Run `holodeck` with no arguments to launch the TUI. The list refreshes every
two seconds; arrow keys move the selection; `Enter` boots or shuts down;
`?` opens an overlay listing every keybinding; `q` quits.

For CLI use, every subcommand accepts `--help`:

```bash
holodeck --help              # all subcommands
holodeck record --help       # one subcommand's options
```

## TUI

The TUI polls `simctl list --json` every two seconds (polling pauses while
recording). User config is read once at launch from
`~/.config/holodeck/config.json` — see [Configuration](#configuration).

| Key             | Action                                             |
| ---             | ---                                                |
| `↑ ↓` / `j k`   | Navigate the simulator list                        |
| `Enter` / Space | Boot or shut down the selection                    |
| `R`             | Force refresh                                      |
| `r`             | Start / stop recording (banner while active)       |
| `p`             | Screenshot                                         |
| `a`             | Appearance submenu (`l` light / `d` dark / Esc)    |
| `n`             | New simulator wizard (device type → runtime)       |
| `f`             | Focus Simulator.app on the selection               |
| `e`             | Erase (shut-down sims only; `y`/`n` confirm)       |
| `d`             | Delete (`y`/`n` confirm)                           |
| `P`             | Privacy wizard (app → action → permission)         |
| `?`             | Help overlay                                       |
| `q` / `Esc`     | Quit (or cancel the active modal)                  |

The terminal enters the alt-screen and raw mode on launch; SIGINT, SIGTERM,
and SIGHUP handlers restore it before exit so a crash never leaves the shell
broken.

## CLI

Every command resolves a simulator by full UDID or by name (substring-fuzzy).
Ambiguous names error out with the matching candidates. Pass `--help` to any
command for the authoritative usage.

### Inspect

List installed simulators, grouped by runtime. `--json` emits a machine-readable
array suitable for piping to `jq`; `--platform` filters by OS family.

```bash
holodeck list [--platform ios|watchos|tvos|visionos] [--json]

holodeck list --platform ios --json | jq '.[].name'
```

List apps installed on a booted simulator. Default filters to user apps;
`--system` includes Apple's preinstalled bundles. `--json` emits an array of
`{bundleID, name, version, isUserApp}` records:

```bash
holodeck apps list <name-or-udid> [--system] [--json]

holodeck apps list "iPhone 17 Pro" --json | jq '.[].bundleID'
```

### Lifecycle

Boot a shut-down simulator:

```bash
holodeck boot <name-or-udid>

holodeck boot "iPhone 17 Pro"
```

Shut down a booted simulator:

```bash
holodeck shutdown <name-or-udid>

holodeck shutdown "iPhone 17 Pro"
```

Create a new simulator. `--device` and `--runtime` accept substrings matched
against the live `simctl` device-type and runtime catalogs:

```bash
holodeck create <name> --device <substr> --runtime <substr>

holodeck create "Demo iPhone" --device "iPhone 17 Pro" --runtime "iOS 18"
```

Erase a single shut-down simulator (or all of them with `--all`). Prompts
before erasing; `-y` skips the prompt:

```bash
holodeck erase <name-or-udid> [-y]
holodeck erase --all [-y]

holodeck erase "Demo iPhone" -y
```

Delete a simulator (or every simulator whose runtime is no longer available
with `--unavailable`). Prompts unless `-y`:

```bash
holodeck delete <name-or-udid> [-y]
holodeck delete --unavailable [-y]

holodeck delete --unavailable -y
```

### Capture

Record video from a booted simulator. Press Ctrl-C to stop — SIGINT is
forwarded to `simctl io` so the MP4 finalizes cleanly (SIGKILL would corrupt
it):

```bash
holodeck record <name-or-udid> [-o path] [--codec h264|hevc]

holodeck record "iPhone 17 Pro" --codec hevc -o ~/Desktop/demo.mp4
```

Capture a screenshot from a booted simulator. Prints the saved path on
success:

```bash
holodeck screenshot <name-or-udid> [-o path] [--type png|jpeg|tiff|bmp]

holodeck screenshot "iPhone 17 Pro" --type png
```

### Device state

Set light or dark appearance (booted simulators only):

```bash
holodeck appearance <name-or-udid> light|dark

holodeck appearance "iPhone 17 Pro" dark
```

Override one or more status-bar fields. Overrides reset when the simulator
shuts down:

```bash
holodeck statusbar override <name-or-udid> \
  [--time <hh:mm>] [--battery-state charging|charged|discharging] \
  [--battery-level 0-100] [--wifi-bars 0-3] [--cellular-bars 0-4] \
  [--operator-name <string>]

holodeck statusbar override "iPhone 17 Pro" --time 9:41 --battery-level 100
```

Clear status-bar overrides:

```bash
holodeck statusbar clear <name-or-udid>

holodeck statusbar clear "iPhone 17 Pro"
```

Set the simulator's locale and language (BCP-47). Writes both `AppleLanguages`
and `AppleLocale`; reboot the simulator to apply:

```bash
holodeck locale <name-or-udid> <bcp47>

holodeck locale "iPhone 17 Pro" pt-BR
```

Override the simulated GPS location (booted simulators only):

```bash
holodeck location set <name-or-udid> <latitude> <longitude>

holodeck location set "iPhone 17 Pro" 37.7749 -122.4194
```

Clear the simulated location:

```bash
holodeck location clear <name-or-udid>

holodeck location clear "iPhone 17 Pro"
```

### Privacy & data

Grant, revoke, or reset a privacy permission. The bundle ID is required for
`grant` and `revoke`; for `reset` it's optional (omit it to reset every app's
prompt state for that permission).

Permissions: `all`, `calendar`, `contacts`, `contacts-limited`, `location`,
`location-always`, `photos`, `photos-add`, `media-library`, `microphone`,
`motion`, `reminders`, `siri`.

```bash
holodeck privacy <name-or-udid> grant|revoke|reset <permission> [bundle-id]

holodeck privacy "iPhone 17 Pro" grant photos com.example.MyApp
holodeck privacy "iPhone 17 Pro" reset all
```

Wipe the simulator's keychain without erasing the whole device (handy for
clearing test credentials between runs):

```bash
holodeck keychain reset <name-or-udid>

holodeck keychain reset "iPhone 17 Pro"
```

### Window

Bring Simulator.app to the front, focused on the selected device:

```bash
holodeck focus <name-or-udid>

holodeck focus "iPhone 17 Pro"
```

> **Note.** Under the hood this runs `open -a Simulator --args
> -CurrentDeviceUDID <udid>`, which Simulator.app persists into its
> preferences. If you later quit Simulator.app and relaunch it (from
> anywhere), it will start with that device focused. This is Simulator.app's
> own behavior, not something holodeck tracks.

## Configuration

holodeck reads `~/.config/holodeck/config.json` (honoring `$XDG_CONFIG_HOME`)
at launch. A missing file uses the defaults below; a malformed file errors
out. All fields are optional — include only the ones you want to override.

```json
{
  "defaultPlatform": "iOS",
  "screenshotsDirectory": "~/Captures",
  "videoCodec": "hevc",
  "screenshotType": "png",
  "pollIntervalSeconds": 2.0
}
```

| Field                  | Default     | Affects                                             |
| ---                    | ---         | ---                                                 |
| `defaultPlatform`      | `null`      | `list --platform` default                           |
| `screenshotsDirectory` | `~/Desktop` | Output dir for `record` and `screenshot`            |
| `videoCodec`           | `h264`      | `record --codec` default                            |
| `screenshotType`       | `png`       | `screenshot --type` default                         |
| `pollIntervalSeconds`  | `2.0`       | TUI refresh cadence                                 |

CLI flags always win over config; config wins over hard-coded defaults.

## Architecture

```
┌─────────────────────────────────────────┐
│  Presentation (HolodeckTUI + holodeck)  │  ← argument-parser subcommands, raw-mode TUI
├─────────────────────────────────────────┤
│  HolodeckServices                       │  ← SimulatorService, RecordingService, etc.
├─────────────────────────────────────────┤
│  HolodeckCore                           │  ← models, SimctlClient, ProcessRunner
└─────────────────────────────────────────┘
```

- `SimctlClient` shells out to `xcrun simctl` and decodes `--json` output with
  `Codable` — no regex parsing of the human-readable form.
- `ProcessRunner` is an injectable protocol so services can be unit-tested with
  stubs.
- The TUI is pure-data-driven: `Reducer.reduce` returns the next `AppState`
  plus a list of `SideEffect` values; `HolodeckApp` dispatches each effect on a
  detached `Task` and feeds responses back into the event stream.
- Recording uses `Process.interrupt()` (SIGINT) to stop `simctl io recordVideo`
  so the MP4 finalizes cleanly. SIGKILL would corrupt the file.

## Development

```bash
swift test                   # run the suite (Swift Testing, ~140 tests)
swiftformat Sources Tests    # apply formatting (.swiftformat)
swiftlint --quiet            # apply lint (.swiftlint.yml)
```

Both format and lint should run clean on a fresh checkout. Tests cover JSON
decoding, input parsing, the full reducer (navigation, recording, lifecycle
modals, wizard), terminal-mode basics, the config loader, and `Recorder`'s
interrupt-and-wait semantics.

## License

MIT — see file headers.
