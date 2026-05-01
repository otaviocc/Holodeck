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

    public static func render(_ state: AppState) -> String {
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

        let sorted = state.sortedSimulators
        let bodyHeight = rows - 4 - bodyOffset
        let listSlice = bodyHeight > 0 ? Array(sorted.prefix(bodyHeight)) : []

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

    private static func header(width: Int) -> String {
        let title = " holodeck "
        let hint = " ⏎ boot/shutdown  r rec  p shot  a appear  n new  e erase  d delete  q quit "
        let space = max(0, width - title.count - hint.count)
        return "\(ANSI.inverse)\(title)\(String(repeating: " ", count: space))\(hint)\(ANSI.reset)"
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
        let leftVisible = stripANSI(left)
        let truncated = leftVisible.count > width ? String(leftVisible.prefix(width)) : leftVisible
        let padding = max(0, width - truncated.count)
        return "\(ANSI.inverse) \(left)\(String(repeating: " ", count: padding - 1))\(ANSI.reset)"
    }

    private static func pad(_ text: String, width: Int, visibleWidth: Int? = nil) -> String {
        let visible = visibleWidth ?? stripANSI(text).count
        let space = max(0, width - visible)
        return "\(text)\(String(repeating: " ", count: space))"
    }

    static func stripANSI(_ text: String) -> String {
        var out = ""
        var inEscape = false
        for char in text {
            if inEscape {
                if char.isLetter { inEscape = false }
                continue
            }
            if char == "\u{1B}" { inEscape = true
                continue
            }
            out.append(char)
        }
        return out
    }
}
