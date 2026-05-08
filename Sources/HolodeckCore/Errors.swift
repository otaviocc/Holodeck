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

public enum SimctlError: Error, Sendable, CustomStringConvertible {

    // MARK: - Properties

    case xcodeNotFound
    case simulatorNotFound(query: String)
    case ambiguousMatch(query: String, candidates: [Simulator])
    case alreadyInState(SimulatorState)
    case commandFailed(command: String, exitCode: Int32, stderr: String)
    case decodingFailed(underlying: Error)
    case unsupportedOperation(reason: String)

    // MARK: - Public

    public var description: String {
        switch self {
        case .xcodeNotFound:
            return "Xcode not found"
        case let .simulatorNotFound(query):
            return "not found: \(query)"
        case let .ambiguousMatch(query, _):
            return "ambiguous: \(query)"
        case let .alreadyInState(state):
            return "already \(state.rawValue)"
        case let .commandFailed(_, _, stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "command failed" : trimmed
        case .decodingFailed:
            return "decode failed"
        case let .unsupportedOperation(reason):
            return reason
        }
    }
}
