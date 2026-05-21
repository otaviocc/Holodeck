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

public struct RecordingService: Sendable {

    // MARK: - Properties

    public var start: @Sendable (_ udid: UUID, _ output: URL, _ codec: VideoCodec) async throws -> URL
    public var stop: @Sendable () async -> URL?
    public var isRecording: @Sendable () async -> Bool
    public var currentOutput: @Sendable () async -> URL?

    // MARK: - Lifecycle

    package init(
        start: @Sendable @escaping (UUID, URL, VideoCodec) async throws -> URL,
        stop: @Sendable @escaping () async -> URL?,
        isRecording: @Sendable @escaping () async -> Bool,
        currentOutput: @Sendable @escaping () async -> URL?
    ) {
        self.start = start
        self.stop = stop
        self.isRecording = isRecording
        self.currentOutput = currentOutput
    }
}

public extension RecordingService {

    static func live(recorder: Recorder = .live()) -> Self {
        let state = RecordingState()
        return Self(
            start: { udid, output, codec in
                if await recorder.isRunning() {
                    throw SimctlError.unsupportedOperation(reason: "already recording")
                }
                try DefaultMediaPath.ensureDirectoryExists(for: output)
                let command = SimctlClient.recordVideoCommand(udid: udid, output: output, codec: codec)
                try await recorder.start(command.launchPath, command.arguments)
                await state.set(output)
                return output
            },
            stop: {
                await recorder.stop()
                return await state.takeCurrent()
            },
            isRecording: { await recorder.isRunning() },
            currentOutput: { await state.current }
        )
    }
}

// MARK: - Private

private actor RecordingState {

    // MARK: - Properties

    private(set) var current: URL?

    // MARK: - Public

    func set(_ value: URL?) {
        current = value
    }

    func takeCurrent() -> URL? {
        let value = current
        current = nil
        return value
    }
}
