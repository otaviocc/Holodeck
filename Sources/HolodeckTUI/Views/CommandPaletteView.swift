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

enum CommandPaletteView {

    // MARK: - Public

    /// Splices a centered 5-line palette box into pre-rendered list lines.
    /// `listLines` are the main-list rows (excluding the status bar), already
    /// padded to `width`. `topReserve` is the count of header+banner rows the
    /// overlay must not overwrite. The status bar is appended by the caller.
    static func overlay(
        listLines: [String],
        palette: CommandPalette,
        state: AppState,
        width: Int,
        topReserve: Int = 0
    ) -> [String] {
        let box = renderBox(palette: palette, state: state, width: width)
        guard !listLines.isEmpty else { return box }
        let boxHeight = box.count
        let centered = max(0, (listLines.count - boxHeight) / 2)
        let top = max(topReserve, centered)
        var out = listLines
        for offset in 0..<boxHeight where top + offset < out.count {
            out[top + offset] = box[offset]
        }
        return out
    }

    // MARK: - Private

    private static func renderBox(palette: CommandPalette, state: AppState, width: Int) -> [String] {
        let boxWidth = min(60, max(24, width - 4))
        let left = max(0, (width - boxWidth) / 2)
        let leftPad = String(repeating: " ", count: left)
        let rightPad = String(repeating: " ", count: max(0, width - left - boxWidth))

        let topMatch = CommandPaletteReducer.topMatch(for: palette.query, state: state)
        let inputLine = inputContent(palette: palette, topMatch: topMatch, innerWidth: boxWidth - 2)
        let hintLine = hintContent(palette: palette, topMatch: topMatch, innerWidth: boxWidth - 2)

        let horizontal = String(repeating: "─", count: boxWidth - 2)
        let topBorder = "┌\(horizontal)┐"
        let bottomBorder = "└\(horizontal)┘"
        let blank = "│\(String(repeating: " ", count: boxWidth - 2))│"

        let colored: (String) -> String = { content in
            "\(leftPad)\(ANSI.cyan)\(content)\(ANSI.reset)\(rightPad)"
        }

        return [
            colored(topBorder),
            "\(leftPad)\(ANSI.cyan)│\(ANSI.reset)\(inputLine)\(ANSI.cyan)│\(ANSI.reset)\(rightPad)",
            colored(blank),
            "\(leftPad)\(ANSI.cyan)│\(ANSI.reset)\(hintLine)\(ANSI.cyan)│\(ANSI.reset)\(rightPad)",
            colored(bottomBorder)
        ]
    }

    private static func inputContent(
        palette: CommandPalette,
        topMatch: PaletteCommand?,
        innerWidth: Int
    ) -> String {
        let prompt = " : "
        let available = max(0, innerWidth - prompt.count)
        let fullQuery = palette.query
        let fullGhost = ghostSuffix(query: fullQuery, topMatch: topMatch)

        // When the query alone overflows, show its tail so the cursor stays
        // visible and drop the ghost suffix. Otherwise show as much of the
        // ghost as still fits.
        let visibleQuery: String
        let visibleGhost: String
        if fullQuery.count >= available {
            visibleQuery = String(fullQuery.suffix(available))
            visibleGhost = ""
        } else {
            visibleQuery = fullQuery
            let remaining = available - visibleQuery.count
            visibleGhost = String(fullGhost.prefix(remaining))
        }

        let used = visibleQuery.count + visibleGhost.count
        let space = max(0, available - used)
        let ghostAnsi = visibleGhost.isEmpty ? "" : "\(ANSI.dim)\(visibleGhost)\(ANSI.reset)"
        return "\(prompt)\(visibleQuery)\(ghostAnsi)\(String(repeating: " ", count: space))"
    }

    private static func hintContent(
        palette: CommandPalette,
        topMatch: PaletteCommand?,
        innerWidth: Int
    ) -> String {
        let plain = if palette.query.isEmpty {
            "type to search · esc cancel"
        } else if topMatch == nil {
            "no match"
        } else {
            "tab accept · enter run · esc cancel"
        }
        let truncated = ViewSupport.truncate(" \(plain)", to: innerWidth)
        let space = max(0, innerWidth - truncated.count)
        return "\(ANSI.dim)\(truncated)\(ANSI.reset)\(String(repeating: " ", count: space))"
    }

    private static func ghostSuffix(query: String, topMatch: PaletteCommand?) -> String {
        guard !query.isEmpty, let match = topMatch else { return "" }
        let name = match.displayName
        guard name.count > query.count else { return "" }
        let prefix = String(name.prefix(query.count))
        guard prefix.lowercased() == query.lowercased() else { return "" }
        return String(name.dropFirst(query.count))
    }
}
