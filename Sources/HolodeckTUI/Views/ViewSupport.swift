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

enum ViewSupport {

    // MARK: - Public

    static func pad(_ text: String, width: Int, visibleWidth: Int? = nil) -> String {
        let visible = visibleWidth ?? ANSI.stripEscapes(from: text).count
        let space = max(0, width - visible)
        return "\(text)\(String(repeating: " ", count: space))"
    }

    static func truncate(_ text: String, to width: Int) -> String {
        text.count > width ? String(text.prefix(width)) : text
    }

    static func statusBar(state: AppState, width: Int) -> String {
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
        let truncated = truncate(leftVisible, to: available)
        let padding = max(0, available - truncated.count)
        return "\(ANSI.inverse) \(left)\(String(repeating: " ", count: padding))\(ANSI.reset)"
    }
}
