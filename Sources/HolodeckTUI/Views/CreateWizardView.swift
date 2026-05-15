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

enum CreateWizardView {

    // MARK: - Public

    static func render(state: AppState, wizard: CreateWizard) -> String {
        let cols = max(40, state.cols)
        let bodyHeight = CreateWizard.viewport(rows: max(8, state.rows))

        return WizardChrome.render(
            state: state,
            breadcrumb: "Create simulator  ·  \(breadcrumb(wizard: wizard))",
            body: renderBody(wizard: wizard, bodyHeight: bodyHeight, width: cols),
            error: wizard.error,
            footerKeys: footerKeys(wizard: wizard)
        )
    }

    // MARK: - Private

    private static func breadcrumb(wizard: CreateWizard) -> String {
        let deviceName = wizard.selectedDeviceType?.name ?? "—"
        let runtimeName = wizard.selectedRuntime?.displayName ?? "—"
        switch wizard.step {
        case .loading:
            return "loading device types and runtimes…"
        case .pickDeviceType:
            return "Step 1/3: pick device type"
        case .pickRuntime:
            return "Step 2/3: \(deviceName) → pick runtime"
        case .confirm:
            return "Step 3/3: \(deviceName) → \(runtimeName) → confirm"
        case .submitting:
            return "creating \(wizard.defaultName)…"
        }
    }

    private static func renderBody(wizard: CreateWizard, bodyHeight: Int, width: Int) -> [String] {
        switch wizard.step {
        case .loading:
            [ViewSupport.pad("  Loading device types and runtimes…", width: width)]
        case .submitting:
            [ViewSupport.pad("  Creating \(wizard.defaultName)…", width: width)]
        case .pickDeviceType:
            renderDeviceTypes(wizard: wizard, bodyHeight: bodyHeight, width: width)
        case .pickRuntime:
            renderRuntimes(wizard: wizard, bodyHeight: bodyHeight, width: width)
        case .confirm:
            renderConfirm(wizard: wizard, width: width)
        }
    }

    private static func renderDeviceTypes(wizard: CreateWizard, bodyHeight: Int, width: Int) -> [String] {
        guard !wizard.deviceTypes.isEmpty else {
            return [ViewSupport.pad("  (no device types available)", width: width)]
        }
        let offset = max(0, min(wizard.deviceTypeScrollOffset, max(0, wizard.deviceTypes.count - bodyHeight)))
        let end = min(wizard.deviceTypes.count, offset + bodyHeight)
        return (offset..<end).map { index in
            let dtype = wizard.deviceTypes[index]
            return WizardChrome.row(
                label: dtype.name,
                suffix: nil,
                selected: index == wizard.deviceTypeIndex,
                width: width
            )
        }
    }

    private static func renderRuntimes(wizard: CreateWizard, bodyHeight: Int, width: Int) -> [String] {
        guard !wizard.runtimes.isEmpty else {
            return [ViewSupport.pad("  (no runtimes available)", width: width)]
        }
        let offset = max(0, min(wizard.runtimeScrollOffset, max(0, wizard.runtimes.count - bodyHeight)))
        let end = min(wizard.runtimes.count, offset + bodyHeight)
        return (offset..<end).map { index in
            let runtime = wizard.runtimes[index]
            return WizardChrome.row(
                label: runtime.displayName,
                suffix: nil,
                selected: index == wizard.runtimeIndex,
                width: width
            )
        }
    }

    private static func renderConfirm(wizard: CreateWizard, width: Int) -> [String] {
        let deviceName = wizard.selectedDeviceType?.name ?? "—"
        let runtimeName = wizard.selectedRuntime?.displayName ?? "—"
        return [
            ViewSupport.pad("  \(ANSI.bold)Create \"\(wizard.defaultName)\"?\(ANSI.reset)", width: width),
            ViewSupport.pad("", width: width),
            ViewSupport.pad("  \(ANSI.gray)Device:\(ANSI.reset)  \(deviceName)", width: width),
            ViewSupport.pad("  \(ANSI.gray)Runtime:\(ANSI.reset) \(runtimeName)", width: width)
        ]
    }

    private static func footerKeys(wizard: CreateWizard) -> String {
        switch wizard.step {
        case .loading, .submitting:
            "Esc cancel"
        case .pickDeviceType:
            "↑↓ navigate  ⏎ next  Esc cancel"
        case .pickRuntime:
            "↑↓ navigate  ⏎ next  b back  Esc cancel"
        case .confirm:
            "y / ⏎ create  b back  Esc cancel"
        }
    }
}
