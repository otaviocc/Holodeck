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
import HolodeckServices
import HolodeckTestSupport
import Testing

struct RecordingServiceTests {

    private let udid = UUID()

    @Test("It should return the output URL after a successful start")
    func startReturnsOutput() async throws {
        try await withTemporaryDirectory { dir in
            // Given
            let service = RecordingService.live(recorder: .mock())
            let output = dir.appendingPathComponent("video.mp4")

            // When
            let path = try await service.start(udid, output, .h264)

            // Then
            #expect(path == output)
        }
    }

    @Test("It should track currentOutput between start and stop")
    func currentOutputTrackedAcrossLifecycle() async throws {
        try await withTemporaryDirectory { dir in
            // Given
            let service = RecordingService.live(recorder: .mock())
            let output = dir.appendingPathComponent("video.mp4")

            // When
            let before = await service.currentOutput()
            _ = try await service.start(udid, output, .h264)
            let during = await service.currentOutput()
            let stopped = await service.stop()
            let after = await service.currentOutput()

            // Then
            #expect(before == nil)
            #expect(during == output)
            #expect(stopped == output)
            #expect(after == nil)
        }
    }

    @Test("It should throw unsupportedOperation when already recording")
    func startWhileRecordingThrows() async throws {
        try await withTemporaryDirectory { dir in
            // Given
            // swiftlint:disable:next trailing_closure
            let service = RecordingService.live(recorder: .mock(isRunning: { true }))

            // Then
            await #expect(throws: SimctlError.self) {
                _ = try await service.start(udid, dir.appendingPathComponent("video.mp4"), .h264)
            }
        }
    }

    @Test("It should reflect the recorder's isRunning through isRecording")
    func isRecordingProxiesRecorder() async {
        // Given
        // swiftlint:disable:next trailing_closure
        let running = RecordingService.live(recorder: .mock(isRunning: { true }))
        // swiftlint:disable:next trailing_closure
        let idle = RecordingService.live(recorder: .mock(isRunning: { false }))

        // Then
        #expect(await running.isRecording())
        #expect(await !(idle.isRecording()))
    }

    @Test("It should forward start to the recorder with the simctl recordVideo command")
    func startForwardsRecordVideoCommand() async throws {
        try await withTemporaryDirectory { dir in
            // Given
            let capturedArgs = CapturedArgs()
            // swiftlint:disable:next trailing_closure
            let recorder = Recorder.mock(start: { _, args in
                await capturedArgs.set(args)
            })
            let service = RecordingService.live(recorder: recorder)
            let output = dir.appendingPathComponent("video.mp4")

            // When
            _ = try await service.start(udid, output, .hevc)

            // Then
            let args = await capturedArgs.value
            #expect(args?.contains("simctl") == true)
            #expect(args?.contains("recordVideo") == true)
            #expect(args?.contains("hevc") == true)
            #expect(args?.contains(udid.uuidString) == true)
        }
    }

    @Test("It should clear currentOutput even when stop is called without a prior start")
    func stopWithoutStartIsNoop() async {
        // Given
        let service = RecordingService.live(recorder: .mock())

        // When
        let result = await service.stop()

        // Then
        #expect(result == nil)
        #expect(await service.currentOutput() == nil)
    }
}

// MARK: - Private

private actor CapturedArgs {

    // MARK: - Properties

    private(set) var value: [String]?

    // MARK: - Public

    func set(_ value: [String]) {
        self.value = value
    }
}
