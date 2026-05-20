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

enum InspectorView {

    // MARK: - Public

    static func render(state: AppState, udid: UUID) -> String {
        let sim = state.simulators.first { $0.id == udid }
        let body = sim.map(fields(for:)) ?? [ViewSupport.pad(
            "  (simulator no longer available)",
            width: max(40, state.cols)
        )]
        return WizardChrome.render(
            state: state,
            breadcrumb: "Inspector — \(sim?.name ?? "—")",
            body: body,
            error: nil,
            footerKeys: "i / Esc / q  close"
        )
    }

    // MARK: - Private

    private static let labelWidth = 14

    private static func fields(for sim: Simulator) -> [String] {
        let rows: [(String, String)] = [
            ("UDID", sim.id.uuidString),
            ("State", sim.state.rawValue),
            ("Runtime", sim.runtime.displayName),
            ("Device type", sim.deviceType.name),
            ("Available", sim.isAvailable ? "yes" : "no"),
            ("Data path", sim.dataPath?.path ?? "—"),
            ("Log path", sim.logPath?.path ?? "—")
        ]
        return rows.map { label, value in
            let padded = label.padding(toLength: labelWidth, withPad: " ", startingAt: 0)
            return "  \(ANSI.gray)\(padded)\(ANSI.reset)  \(value)"
        }
    }
}
