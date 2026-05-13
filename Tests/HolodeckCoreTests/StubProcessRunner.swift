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

final class StubProcessRunner: ProcessRunning, @unchecked Sendable {

    struct Invocation {

        let launchPath: String
        let arguments: [String]
    }

    var responses: [ProcessResult]
    private(set) var invocations: [Invocation] = []
    private let lock = NSRecursiveLock()

    init(responses: [ProcessResult] = [ProcessResult(stdout: Data(), stderr: Data(), exitCode: 0)]) {
        self.responses = responses
    }

    func run(_ launchPath: String, _ arguments: [String]) async throws -> ProcessResult {
        lock.withLock {
            invocations.append(Invocation(launchPath: launchPath, arguments: arguments))
            return responses.isEmpty
                ? ProcessResult(stdout: Data(), stderr: Data(), exitCode: 0)
                : responses.removeFirst()
        }
    }

    static func ok(stdout: String = "") -> ProcessResult {
        ProcessResult(stdout: Data(stdout.utf8), stderr: Data(), exitCode: 0)
    }

    static func failure(stderr: String = "", exitCode: Int32 = 1) -> ProcessResult {
        ProcessResult(stdout: Data(), stderr: Data(stderr.utf8), exitCode: exitCode)
    }
}
