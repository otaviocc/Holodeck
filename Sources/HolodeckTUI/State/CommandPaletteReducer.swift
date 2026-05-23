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

enum CommandPaletteReducer {

    // MARK: - Public

    static func handle(state: AppState, palette: CommandPalette, key: Key) -> ReducerOutput {
        var next = state
        var updated = palette

        switch key {
        case .escape:
            next.modal = nil
            return ReducerOutput(state: next)

        case .enter:
            guard !updated.query.isEmpty else {
                next.modal = nil
                return ReducerOutput(state: next)
            }
            guard let command = topMatch(for: updated.query, state: next) else {
                next.modal = nil
                next.lastError = "No matching command: \(updated.query)"
                return ReducerOutput(state: next)
            }
            next.modal = nil
            return Reducer.runCommand(command, state: next)

        case .tab:
            guard let command = topMatch(for: updated.query, state: next) else { break }
            // Preserve the user's typed casing; only append the unmatched suffix.
            let name = command.displayName
            let suffix = name.count > updated.query.count
                ? String(name.dropFirst(updated.query.count))
                : ""
            updated.query.append(suffix)

        case .backspace:
            if !updated.query.isEmpty {
                updated.query.removeLast()
            }

        case let .char(character) where TextInput.isPrintable(character):
            updated.query.append(character)

        default:
            break
        }

        next.modal = .commandPalette(updated)
        return ReducerOutput(state: next)
    }

    /// First applicable command whose `displayName` begins with `query`.
    /// Empty query returns the first applicable command (for Enter-from-empty).
    static func topMatch(for query: String, state: AppState) -> PaletteCommand? {
        let sim = state.selectedSimulator
        let isRecording = state.isRecording
        return PaletteCommand.all.first {
            $0.isApplicable(to: sim, isRecording: isRecording) && $0.matches(prefix: query)
        }
    }
}
