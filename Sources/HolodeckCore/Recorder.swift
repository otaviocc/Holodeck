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

public struct Recorder: Sendable {

    // MARK: - Properties

    public var start: @Sendable (_ launchPath: String, _ arguments: [String]) async throws -> Void
    public var stop: @Sendable () async -> Void
    public var isRunning: @Sendable () async -> Bool

    // MARK: - Lifecycle

    package init(
        start: @Sendable @escaping (String, [String]) async throws -> Void,
        stop: @Sendable @escaping () async -> Void,
        isRunning: @Sendable @escaping () async -> Bool
    ) {
        self.start = start
        self.stop = stop
        self.isRunning = isRunning
    }
}

public extension Recorder {

    static func live() -> Self {
        let backing = RecorderActor()
        return Self(
            start: { launchPath, arguments in
                try await backing.start(launchPath: launchPath, arguments: arguments)
            },
            stop: { await backing.stop() },
            isRunning: { await backing.isRunning }
        )
    }
}

// MARK: - Private

/// Owns the long-running child process. Sending `Process.interrupt()` (SIGINT)
/// — not `terminate()` / `kill()` — is required for `simctl io recordVideo` to
/// finalize a valid MP4.
actor RecorderActor {

    // MARK: - Properties

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    // MARK: - Public

    func start(launchPath: String, arguments: [String]) throws {
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

    func stop() async {
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
