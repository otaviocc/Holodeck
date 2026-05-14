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

import Darwin
import Foundation
import HolodeckCore
import HolodeckServices

enum AppSpawn {

    // MARK: - Public

    static func inputTask(
        parser: InputParser,
        continuation: AsyncStream<AppEvent>.Continuation
    ) -> Task<Void, Never> {
        Task.detached {
            await readInputLoop(parser: parser, continuation: continuation)
        }
    }

    static func pollTask(
        interval: Double,
        continuation: AsyncStream<AppEvent>.Continuation
    ) -> Task<Void, Never> {
        Task.detached {
            await pollLoop(interval: interval, continuation: continuation)
        }
    }

    static func boot(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawnPerSimulator(id: id, continuation: continuation) {
            try await service.boot(id)
        }
    }

    static func shutdown(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawnPerSimulator(id: id, continuation: continuation) {
            try await service.shutdown(id)
        }
    }

    static func erase(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawnPerSimulator(id: id, continuation: continuation) {
            try await service.erase(id)
        }
    }

    static func delete(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawnPerSimulator(id: id, continuation: continuation) {
            try await service.delete(id)
        }
    }

    static func refresh(
        service: SimulatorService,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        Task.detached {
            await kickoffRefresh(service: service, continuation: continuation)
        }
    }

    static func startRecording(
        recording: RecordingService,
        id: UUID,
        output: URL,
        codec: VideoCodec,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await recording.start(udid: id, output: output, codec: codec) },
            success: { .recordingStarted(id, $0) },
            failure: { .recordingFailed($0) }
        )
    }

    static func stopRecording(
        recording: RecordingService,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        Task.detached {
            let path = await recording.stop()
            continuation.yield(.recordingStopped(path))
        }
    }

    static func appearance(
        service: AppearanceService,
        id: UUID,
        appearance: Appearance,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await service.set(udid: id, appearance: appearance) },
            success: { .appearanceChanged(id, appearance) },
            failure: { .appearanceFailed($0) }
        )
    }

    static func screenshot(
        screenshots: ScreenshotService,
        id: UUID,
        output: URL,
        type: ScreenshotType,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await screenshots.capture(udid: id, output: output, type: type) },
            success: { .screenshotSaved($0) },
            failure: { .screenshotFailed($0) }
        )
    }

    static func focus(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawnPerSimulator(id: id, continuation: continuation) {
            try await service.focus(id)
        }
    }

    static func loadTargets(
        service: SimulatorService,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await service.availableTargets() },
            success: { .targetsLoaded($0) },
            failure: { .targetsFailed($0) }
        )
    }

    static func loadInstalledApps(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await service.listApps(id) },
            success: { .appsLoaded($0) },
            failure: { .appsLoadFailed($0) }
        )
    }

    static func applyPrivacy(
        service: PrivacyService,
        udid: UUID,
        action: PrivacyAction,
        permission: PrivacyPermission,
        bundleID: String,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await service.apply(udid: udid, action: action, permission: permission, bundleID: bundleID) },
            success: { _ in .privacyApplied(bundleID: bundleID) },
            failure: { .privacyApplyFailed($0) }
        )
    }

    static func create(
        service: SimulatorService,
        name: String,
        deviceType: DeviceType,
        runtime: Runtime,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        spawn(
            continuation: continuation,
            work: { try await service.create(name: name, deviceType: deviceType, runtime: runtime) },
            success: { .simulatorCreated($0, name) },
            failure: { .simulatorCreateFailed($0) }
        )
    }

    static func kickoffRefresh(
        service: SimulatorService,
        continuation: AsyncStream<AppEvent>.Continuation
    ) async {
        do {
            let sims = try await service.list()
            continuation.yield(.refreshed(sims))
        } catch {
            continuation.yield(.refreshFailed(errorDescription(error)))
        }
    }

    static func pollLoop(
        interval: Double,
        continuation: AsyncStream<AppEvent>.Continuation
    ) async {
        let nanos = UInt64(max(0.1, interval) * 1_000_000_000)
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: nanos)
            if Task.isCancelled { break }
            continuation.yield(.pollTick)
        }
    }

    static func readInputLoop(
        parser: InputParser,
        continuation: AsyncStream<AppEvent>.Continuation
    ) async {
        let stdinFD = STDIN_FILENO
        var buf = [UInt8](repeating: 0, count: 64)
        while !Task.isCancelled {
            let bytesRead = buf.withUnsafeMutableBufferPointer { ptr -> Int in
                read(stdinFD, ptr.baseAddress, ptr.count)
            }
            if bytesRead > 0 {
                let bytes = Array(buf.prefix(bytesRead))
                for key in parser.parse(bytes) {
                    continuation.yield(.key(key))
                }
            } else {
                try? await Task.sleep(nanoseconds: 30_000_000)
            }
        }
    }

    static func errorDescription(_ error: Error) -> String {
        (error as? SimctlError).map(\.description) ?? "\(error)"
    }

    // MARK: - Private

    private static func spawnPerSimulator(
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation,
        work: @Sendable @escaping () async throws -> Void
    ) {
        Task.detached {
            do {
                try await work()
                continuation.yield(.operationCompleted(id))
            } catch {
                continuation.yield(.operationFailed(id, errorDescription(error)))
            }
        }
    }

    private static func spawn<T: Sendable>(
        continuation: AsyncStream<AppEvent>.Continuation,
        work: @Sendable @escaping () async throws -> T,
        success: @Sendable @escaping (T) -> AppEvent,
        failure: @Sendable @escaping (String) -> AppEvent
    ) {
        Task.detached {
            do {
                let value = try await work()
                continuation.yield(success(value))
            } catch {
                continuation.yield(failure(errorDescription(error)))
            }
        }
    }
}
