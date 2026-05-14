// MIT License
//
// Copyright (c) 2026 Otávio C.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import HolodeckCore

public enum SimulatorListView {

    // MARK: - Public

    public static func render(_ state: AppState) -> String {
        if state.modal == .help {
            return renderHelp(state: state)
        }
        var lines: [String] = []
        let cols = max(40, state.cols)
        let rows = max(8, state.rows)

        lines.append(header(width: cols))

        var bodyOffset = 0
        if state.isRecording {
            lines.append(recordingBanner(state: state, width: cols))
            bodyOffset = 1
        }
        if let modal = state.modal {
            lines.append(modalBanner(modal: modal, width: cols, state: state))
            bodyOffset += 1
        }

        let bodyHeight = rows - 4 - bodyOffset
        let listSlice = bodyHeight > 0 ? Array(state.simulators.prefix(bodyHeight)) : []

        if listSlice.isEmpty {
            lines.append(pad("  (no simulators)", width: cols))
        } else {
            var currentRuntime: Runtime?
            for (index, sim) in listSlice.enumerated() {
                if sim.runtime != currentRuntime {
                    lines.append(pad(
                        "\(ANSI.bold)\(ANSI.cyan)\(sim.runtime.displayName)\(ANSI.reset)",
                        width: cols,
                        visibleWidth: sim.runtime.displayName.count
                    ))
                    currentRuntime = sim.runtime
                }
                lines.append(renderRow(
                    sim: sim,
                    selected: index == state.selectedIndex,
                    pending: state.pendingOperations.contains(sim.id),
                    width: cols
                ))
            }
        }

        while lines.count < rows - 1 {
            lines.append(pad("", width: cols))
        }

        lines.append(statusBar(state: state, width: cols))
        return lines.joined(separator: "\r\n")
    }

    static func stripANSI(_ text: String) -> String {
        ANSI.stripEscapes(from: text)
    }

    // MARK: - Private

    private static let headerTitle = " holodeck "
    private static let headerFullHint = " ⏎ toggle  f focus  r rec  p shot  a appear  n new  e erase  d delete  P privacy  ? help  q quit "
    private static let headerShortHint = " ⏎ toggle  ? help  q quit "
    private static let headerTitleCount = headerTitle.count
    private static let headerFullHintCount = headerFullHint.count
    private static let headerShortHintCount = headerShortHint.count

    private static func header(width: Int) -> String {
        let useFull = width >= headerTitleCount + headerFullHintCount
        let hint = useFull ? headerFullHint : headerShortHint
        let hintCount = useFull ? headerFullHintCount : headerShortHintCount
        let space = max(0, width - headerTitleCount - hintCount)
        return "\(ANSI.inverse)\(headerTitle)\(String(repeating: " ", count: space))\(hint)\(ANSI.reset)"
    }

    private static func modalBanner(modal: Modal, width: Int, state: AppState) -> String {
        let text: String
        switch modal {
        case .appearance:
            text = "Appearance:  l = light    d = dark    Esc = cancel"
        case let .confirmErase(id):
            let name = state.simulators.first { $0.id == id }?.name ?? "?"
            text = "Erase \(name)?  y = confirm    n / Esc = cancel"
        case let .confirmDelete(id):
            let name = state.simulators.first { $0.id == id }?.name ?? "?"
            text = "Delete \(name)?  y = confirm    n / Esc = cancel"
        case let .createWizard(wizard):
            text = createWizardBanner(wizard: wizard)
        case let .privacyWizard(wizard):
            text = privacyWizardBanner(wizard: wizard)
        case .help:
            text = "Help — press any key to dismiss"
        }
        let truncated = text.count > width ? String(text.prefix(width)) : text
        let space = max(0, width - truncated.count)
        return "\(ANSI.cyan)\(ANSI.bold)\(truncated)\(ANSI.reset)\(String(repeating: " ", count: space))"
    }

    private static func createWizardBanner(wizard: CreateWizard) -> String {
        switch wizard.step {
        case .loading:
            return "Create simulator: loading device types and runtimes…"
        case .pickDeviceType:
            let current = wizard.selectedDeviceType?.name ?? "—"
            return "Create — device type (\(wizard.deviceTypeIndex + 1)/\(wizard.deviceTypes.count))  ↑↓ navigate  ⏎ next  Esc cancel  →  \(current)"
        case .pickRuntime:
            let current = wizard.selectedRuntime?.displayName ?? "—"
            return "Create — runtime (\(wizard.runtimeIndex + 1)/\(wizard.runtimes.count))  ↑↓ navigate  ⏎ next  b back  Esc cancel  →  \(current)"
        case .confirm:
            let suffix = wizard.error.map { "  ⚠ \($0)" } ?? ""
            return "Confirm: create \"\(wizard.defaultName)\"?  y/⏎ create  b back  Esc cancel\(suffix)"
        case .submitting:
            return "Creating \(wizard.defaultName)…"
        }
    }

    private static func privacyWizardBanner(wizard: PrivacyWizard) -> String {
        switch wizard.step {
        case .loadingApps:
            return "Privacy: loading installed apps…"
        case .pickApp:
            let count = wizard.apps.count
            let current = wizard.selectedApp.map { "\($0.name) (\($0.bundleID))" } ?? "—"
            let scope = wizard.showSystem ? "all" : "user"
            return "Privacy — app (\(wizard.appIndex + 1)/\(count), \(scope))  ↑↓ navigate  s toggle system  ⏎ next  Esc cancel  →  \(current)"
        case .pickAction:
            let actions = PrivacyAction.allCases
            let current = wizard.selectedAction?.rawValue ?? "—"
            return "Privacy — action (\(wizard.actionIndex + 1)/\(actions.count))  ↑↓ navigate  ⏎ next  b back  Esc cancel  →  \(current)"
        case .pickPermission:
            let permissions = PrivacyPermission.allCases
            let current = wizard.selectedPermission?.rawValue ?? "—"
            let suffix = wizard.error.map { "  ⚠ \($0)" } ?? ""
            return "Privacy — permission (\(wizard.permissionIndex + 1)/\(permissions.count))  ↑↓ navigate  ⏎ apply  b back  Esc cancel  →  \(current)\(suffix)"
        case .submitting:
            let target = wizard.selectedApp?.bundleID ?? "?"
            return "Applying privacy change to \(target)…"
        }
    }

    private static func recordingBanner(state: AppState, width: Int) -> String {
        let name = state.recordingDeviceID.flatMap { id in state.simulators.first { $0.id == id }?.name } ?? "?"
        let path = state.recordingPath?.path ?? ""
        let text = "● REC \(name) → \(path)  (r/q to stop)"
        let truncated = text.count > width ? String(text.prefix(width)) : text
        let space = max(0, width - truncated.count)
        return "\(ANSI.red)\(ANSI.bold)\(truncated)\(ANSI.reset)\(String(repeating: " ", count: space))"
    }

    private static func renderRow(sim: Simulator, selected: Bool, pending: Bool, width: Int) -> String {
        let marker = selected ? "› " : "  "
        let stateColor: String
        let stateGlyph: String
        switch sim.state {
        case .booted: stateColor = ANSI.green
            stateGlyph = "●"
        case .booting, .shuttingDown, .creating: stateColor = ANSI.yellow
            stateGlyph = "◐"
        case .shutdown: stateColor = ANSI.gray
            stateGlyph = "○"
        }
        let pendingTag = pending ? " \(ANSI.yellow)[pending]\(ANSI.reset)" : ""
        let visibleLeft = "\(marker)\(sim.name)"
        let visibleRight = "\(stateGlyph) \(sim.state.rawValue)\(pending ? " [pending]" : "")"
        let gap = max(1, width - visibleLeft.count - visibleRight.count - 2)
        let coloredRight = "\(stateColor)\(stateGlyph) \(sim.state.rawValue)\(ANSI.reset)\(pendingTag)"
        let raw = "  \(marker)\(sim.name)\(String(repeating: " ", count: gap))\(coloredRight)"
        if selected {
            return "\(ANSI.bold)\(raw)\(ANSI.reset)"
        }
        return raw
    }

    private static func statusBar(state: AppState, width: Int) -> String {
        let left = if let err = state.lastError {
            "\(ANSI.red)\(err)\(ANSI.reset)"
        } else if let msg = state.statusMessage {
            "\(ANSI.yellow)\(msg)\(ANSI.reset)"
        } else if let sim = state.selectedSimulator {
            "\(sim.name) — \(sim.id.uuidString)"
        } else {
            ""
        }
        let leftVisible = ANSI.stripEscapes(from: left)
        let available = max(0, width - 1)
        let truncated = leftVisible.count > available ? String(leftVisible.prefix(available)) : leftVisible
        let padding = max(0, available - truncated.count)
        return "\(ANSI.inverse) \(left)\(String(repeating: " ", count: padding))\(ANSI.reset)"
    }

    private static func pad(_ text: String, width: Int, visibleWidth: Int? = nil) -> String {
        let visible = visibleWidth ?? ANSI.stripEscapes(from: text).count
        let space = max(0, width - visible)
        return "\(text)\(String(repeating: " ", count: space))"
    }

    private static func renderHelp(state: AppState) -> String {
        let cols = max(40, state.cols)
        let rows = max(8, state.rows)
        let entries: [(String, String)] = [
            ("↑ ↓ / j k", "navigate"),
            ("Enter / Space", "boot or shutdown selected"),
            ("R", "force refresh"),
            ("r", "start / stop recording"),
            ("p", "screenshot"),
            ("a", "appearance (light / dark)"),
            ("n", "new simulator (wizard)"),
            ("f", "focus Simulator.app on selected"),
            ("e", "erase (shutdown sims only)"),
            ("d", "delete"),
            ("P", "privacy wizard (app → action → permission)"),
            ("s", "toggle system apps in privacy wizard"),
            ("?", "this help"),
            ("q / Esc", "quit (or close modal)")
        ]
        var lines: [String] = []
        lines.append(header(width: cols))
        lines.append(pad("", width: cols))
        lines.append(pad("  \(ANSI.bold)Keybindings\(ANSI.reset)", width: cols, visibleWidth: 13))
        lines.append(pad("", width: cols))
        let keyWidth = entries.map(\.0.count).max() ?? 0
        for (key, description) in entries {
            let padded = key.padding(toLength: keyWidth, withPad: " ", startingAt: 0)
            lines.append(pad("  \(ANSI.cyan)\(padded)\(ANSI.reset)   \(description)", width: cols))
        }
        while lines.count < rows - 1 {
            lines.append(pad("", width: cols))
        }
        lines.append(statusBar(state: state, width: cols))
        return lines.joined(separator: "\r\n")
    }
}
