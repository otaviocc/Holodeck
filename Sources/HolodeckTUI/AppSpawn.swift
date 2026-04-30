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

    static func inputTask(
        parser: InputParser,
        continuation: AsyncStream<AppEvent>.Continuation
    ) -> Task<Void, Never> {
        Task.detached {
            await readInputLoop(parser: parser, continuation: continuation)
        }
    }

    static func pollTask(continuation: AsyncStream<AppEvent>.Continuation) -> Task<Void, Never> {
        Task.detached {
            await pollLoop(continuation: continuation)
        }
    }

    static func boot(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        Task.detached {
            do {
                try await service.boot(id)
                continuation.yield(.operationCompleted(id))
            } catch {
                continuation.yield(.operationFailed(id, errorDescription(error)))
            }
        }
    }

    static func shutdown(
        service: SimulatorService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        Task.detached {
            do {
                try await service.shutdown(id)
                continuation.yield(.operationCompleted(id))
            } catch {
                continuation.yield(.operationFailed(id, errorDescription(error)))
            }
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
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        Task.detached {
            do {
                let path = try await recording.start(udid: id)
                continuation.yield(.recordingStarted(id, path))
            } catch {
                continuation.yield(.recordingFailed(errorDescription(error)))
            }
        }
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
        Task.detached {
            do {
                try await service.set(udid: id, appearance: appearance)
                continuation.yield(.appearanceChanged(id, appearance))
            } catch {
                continuation.yield(.appearanceFailed(errorDescription(error)))
            }
        }
    }

    static func screenshot(
        screenshots: ScreenshotService,
        id: UUID,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        Task.detached {
            do {
                let path = try await screenshots.capture(udid: id)
                continuation.yield(.screenshotSaved(path))
            } catch {
                continuation.yield(.screenshotFailed(errorDescription(error)))
            }
        }
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

    static func pollLoop(continuation: AsyncStream<AppEvent>.Continuation) async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
        if let simctl = error as? SimctlError {
            switch simctl {
            case let .commandFailed(_, _, stderr):
                return stderr.isEmpty ? "command failed" : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            case let .simulatorNotFound(query): return "not found: \(query)"
            case let .ambiguousMatch(query, _): return "ambiguous: \(query)"
            case .decodingFailed: return "decode failed"
            case let .alreadyInState(state): return "already \(state.rawValue)"
            case .xcodeNotFound: return "Xcode not found"
            case let .unsupportedOperation(reason): return reason
            }
        }
        return "\(error)"
    }
}
