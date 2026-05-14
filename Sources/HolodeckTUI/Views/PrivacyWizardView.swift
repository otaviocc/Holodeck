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

enum PrivacyWizardView {

    // MARK: - Public

    static func render(state: AppState, wizard: PrivacyWizard) -> String {
        let cols = max(40, state.cols)
        let rows = max(8, state.rows)
        let simName = state.simulators.first { $0.id == wizard.simulatorID }?.name ?? "?"
        let apps = wizard.apps
        let selectedApp = appAt(apps: apps, index: wizard.appIndex)

        var lines: [String] = []
        lines.append(header(width: cols, simName: simName, wizard: wizard, selectedApp: selectedApp))
        lines.append(ViewSupport.pad("", width: cols))

        let bodyHeight = PrivacyWizard.appViewport(rows: rows)
        let body = renderBody(wizard: wizard, apps: apps, selectedApp: selectedApp, bodyHeight: bodyHeight, width: cols)
        lines.append(contentsOf: body)

        while lines.count < rows - 3 {
            lines.append(ViewSupport.pad("", width: cols))
        }
        if let error = wizard.error {
            lines.append(ViewSupport.pad(
                "  \(ANSI.red)⚠ \(error)\(ANSI.reset)",
                width: cols,
                visibleWidth: error.count + 4
            ))
        } else {
            lines.append(ViewSupport.pad("", width: cols))
        }
        lines.append(ViewSupport.pad("  \(ANSI.gray)\(footerKeys(wizard: wizard))\(ANSI.reset)", width: cols))
        lines.append(ViewSupport.statusBar(state: state, width: cols))
        return lines.joined(separator: "\r\n")
    }

    // MARK: - Private

    private static let permissionLabels = PrivacyPermission.allCases.map(\.rawValue)
    private static let actionLabels = PrivacyAction.allCases.map(\.rawValue)

    private static func appAt(apps: [InstalledApp], index: Int) -> InstalledApp? {
        guard !apps.isEmpty, index >= 0, index < apps.count else { return nil }
        return apps[index]
    }

    private static func header(
        width: Int,
        simName: String,
        wizard: PrivacyWizard,
        selectedApp: InstalledApp?
    ) -> String {
        let crumbs = breadcrumb(wizard: wizard, selectedApp: selectedApp)
        let text = " Privacy — \(simName)  ·  \(crumbs) "
        let truncated = ViewSupport.truncate(text, to: width)
        let space = max(0, width - truncated.count)
        return "\(ANSI.inverse)\(truncated)\(String(repeating: " ", count: space))\(ANSI.reset)"
    }

    private static func breadcrumb(wizard: PrivacyWizard, selectedApp: InstalledApp?) -> String {
        let appName = selectedApp?.name ?? "—"
        let permissionName = wizard.selectedPermission?.rawValue ?? "—"
        switch wizard.step {
        case .loadingApps:
            return "loading apps…"
        case .pickApp:
            let scope = wizard.showSystem ? "all apps" : "user apps"
            return "Step 1/3: pick app (\(scope))"
        case .pickPermission:
            return "Step 2/3: \(appName) → pick permission"
        case .pickAction:
            return "Step 3/3: \(appName) → \(permissionName) → pick action"
        case .submitting:
            return "applying…"
        }
    }

    private static func renderBody(
        wizard: PrivacyWizard,
        apps: [InstalledApp],
        selectedApp: InstalledApp?,
        bodyHeight: Int,
        width: Int
    ) -> [String] {
        switch wizard.step {
        case .loadingApps:
            return [ViewSupport.pad("  Loading installed apps…", width: width)]
        case .submitting:
            let target = selectedApp?.bundleID ?? "?"
            return [ViewSupport.pad("  Applying privacy change to \(target)…", width: width)]
        case .pickApp:
            return renderAppList(wizard: wizard, apps: apps, bodyHeight: bodyHeight, width: width)
        case .pickPermission:
            return renderList(
                items: permissionLabels,
                focusedIndex: wizard.permissionIndex,
                bodyHeight: bodyHeight,
                width: width
            )
        case .pickAction:
            return renderList(
                items: actionLabels,
                focusedIndex: wizard.actionIndex,
                bodyHeight: bodyHeight,
                width: width
            )
        }
    }

    private static func renderAppList(
        wizard: PrivacyWizard,
        apps: [InstalledApp],
        bodyHeight: Int,
        width: Int
    ) -> [String] {
        guard !apps.isEmpty else {
            return [ViewSupport.pad("  (no apps installed)", width: width)]
        }
        let offset = max(0, min(wizard.appScrollOffset, max(0, apps.count - bodyHeight)))
        let end = min(apps.count, offset + bodyHeight)
        return (offset..<end).map { index in
            let app = apps[index]
            return row(label: app.name, suffix: app.bundleID, selected: index == wizard.appIndex, width: width)
        }
    }

    private static func renderList(items: [String], focusedIndex: Int, bodyHeight: Int, width: Int) -> [String] {
        guard !items.isEmpty else { return [ViewSupport.pad("  (empty)", width: width)] }
        let centered = max(0, focusedIndex - bodyHeight / 2)
        let offset = max(0, min(centered, max(0, items.count - bodyHeight)))
        let end = min(items.count, offset + bodyHeight)
        return (offset..<end).map { index in
            row(label: items[index], suffix: nil, selected: index == focusedIndex, width: width)
        }
    }

    private static func row(label: String, suffix: String?, selected: Bool, width: Int) -> String {
        let marker = selected ? "› " : "  "
        let detail = suffix.map { "  \(ANSI.gray)\($0)\(ANSI.reset)" } ?? ""
        let padded = ViewSupport.pad("  \(marker)\(label)\(detail)", width: width)
        if selected {
            return "\(ANSI.bold)\(ANSI.cyan)\(padded)\(ANSI.reset)"
        }
        return padded
    }

    private static func footerKeys(wizard: PrivacyWizard) -> String {
        switch wizard.step {
        case .loadingApps, .submitting:
            "Esc cancel"
        case .pickApp:
            "↑↓ navigate  ⏎ next  s toggle system  Esc cancel"
        case .pickPermission, .pickAction:
            "↑↓ navigate  ⏎ next  b back  Esc cancel"
        }
    }
}
