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

enum OpenURLModalReducer {

    static func handle(state: AppState, prompt: OpenURLPrompt, key: Key) -> ReducerOutput {
        var next = state
        var updated = prompt

        switch key {
        case .escape:
            next.modal = nil
            return ReducerOutput(state: next)

        case .enter:
            guard !updated.url.isEmpty, !updated.isSubmitting else {
                next.modal = .openURL(updated)
                return ReducerOutput(state: next)
            }
            updated.isSubmitting = true
            updated.error = nil
            next.modal = .openURL(updated)
            return ReducerOutput(
                state: next,
                effects: [.openURL(udid: updated.simulatorID, url: updated.url)]
            )

        case .backspace:
            if !updated.url.isEmpty {
                updated.url.removeLast()
            }
            updated.historyIndex = -1
            updated.error = nil

        case .up:
            let history = state.urlHistory
            guard !history.isEmpty else { break }
            updated.historyIndex = min(history.count - 1, updated.historyIndex + 1)
            updated.url = history[updated.historyIndex]
            updated.error = nil

        case .down:
            let history = state.urlHistory
            updated.historyIndex = max(-1, updated.historyIndex - 1)
            if updated.historyIndex >= 0, updated.historyIndex < history.count {
                updated.url = history[updated.historyIndex]
            } else {
                updated.url = ""
            }
            updated.error = nil

        case let .char(character) where Reducer.isFilterPrintable(character):
            updated.url.append(character)
            updated.historyIndex = -1
            updated.error = nil

        default:
            break
        }

        next.modal = .openURL(updated)
        return ReducerOutput(state: next)
    }
}
