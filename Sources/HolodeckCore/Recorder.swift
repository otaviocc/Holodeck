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

public actor Recorder {

    // MARK: - Properties

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    public var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Lifecycle

    public init() {}

    // MARK: - Public

    public func start(launchPath: String, arguments: [String]) throws {
        guard process == nil || !(process?.isRunning ?? false) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: launchPath)
        proc.arguments = arguments
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        try proc.run()
        process = proc
        stdoutPipe = outPipe
        stderrPipe = errPipe
    }

    public func stop() async {
        guard let proc = process, proc.isRunning else {
            cleanup()
            return
        }
        proc.interrupt()
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                proc.waitUntilExit()
                continuation.resume()
            }
        }
        cleanup()
    }

    // MARK: - Private

    private func cleanup() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil
        process = nil
    }
}
