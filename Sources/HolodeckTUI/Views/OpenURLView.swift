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

enum OpenURLView {

    // MARK: - Public

    static func render(state: AppState, prompt: OpenURLPrompt) -> String {
        let simName = state.simulators.first { $0.id == prompt.simulatorID }?.name ?? "—"
        let cols = max(40, state.cols)
        let body = prompt.isSubmitting
            ? [ViewSupport.pad("  Opening \(prompt.url)…", width: cols)]
            : inputBody(state: state, prompt: prompt, width: cols)
        return WizardChrome.render(
            state: state,
            breadcrumb: "Open URL — \(simName)",
            body: body,
            error: prompt.error,
            footerKeys: footerKeys(prompt: prompt)
        )
    }

    // MARK: - Private

    private static func inputBody(state: AppState, prompt: OpenURLPrompt, width: Int) -> [String] {
        let cursor = "▌"
        let line = "  \(ANSI.gray)URL:\(ANSI.reset)  \(prompt.url)\(cursor)"
        let hint = state.urlHistory.isEmpty
            ? "  \(ANSI.gray)(no history yet — type a URL and press ⏎)\(ANSI.reset)"
            : "  \(ANSI.gray)↑/↓ recall  (\(state.urlHistory.count) in history)\(ANSI.reset)"
        return [
            ViewSupport.pad(line, width: width),
            ViewSupport.pad("", width: width),
            ViewSupport.pad(hint, width: width)
        ]
    }

    private static func footerKeys(prompt: OpenURLPrompt) -> String {
        if prompt.isSubmitting { return "Esc cancel" }
        return "↑↓ recall  ⏎ open  Esc cancel"
    }
}
