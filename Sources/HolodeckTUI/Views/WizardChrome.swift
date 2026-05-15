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

/// Shared chrome for full-screen wizard views (create, privacy). Each wizard
/// builds its own breadcrumb header text, body lines, and footer key hint; this
/// helper composes them with the standard padding, error banner, and statusBar.
enum WizardChrome {

    // MARK: - Public

    static func render(
        state: AppState,
        breadcrumb: String,
        body: [String],
        error: String?,
        footerKeys: String
    ) -> String {
        let cols = max(40, state.cols)
        let rows = max(8, state.rows)

        var lines: [String] = []
        lines.append(header(width: cols, breadcrumb: breadcrumb))
        lines.append(ViewSupport.pad("", width: cols))
        lines.append(contentsOf: body)

        while lines.count < rows - 3 {
            lines.append(ViewSupport.pad("", width: cols))
        }
        if let error {
            lines.append(ViewSupport.pad(
                "  \(ANSI.red)⚠ \(error)\(ANSI.reset)",
                width: cols,
                visibleWidth: error.count + 4
            ))
        } else {
            lines.append(ViewSupport.pad("", width: cols))
        }
        lines.append(ViewSupport.pad("  \(ANSI.gray)\(footerKeys)\(ANSI.reset)", width: cols))
        lines.append(ViewSupport.statusBar(state: state, width: cols))
        return lines.joined(separator: "\r\n")
    }

    static func row(label: String, suffix: String?, selected: Bool, width: Int) -> String {
        let marker = selected ? "› " : "  "
        let detail = suffix.map { "  \(ANSI.gray)\($0)\(ANSI.reset)" } ?? ""
        let padded = ViewSupport.pad("  \(marker)\(label)\(detail)", width: width)
        if selected {
            return "\(ANSI.bold)\(ANSI.cyan)\(padded)\(ANSI.reset)"
        }
        return padded
    }

    // MARK: - Private

    private static func header(width: Int, breadcrumb: String) -> String {
        let text = " \(breadcrumb) "
        let truncated = ViewSupport.truncate(text, to: width)
        let space = max(0, width - truncated.count)
        return "\(ANSI.inverse)\(truncated)\(String(repeating: " ", count: space))\(ANSI.reset)"
    }
}
