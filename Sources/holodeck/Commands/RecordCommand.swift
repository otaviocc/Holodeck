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

import ArgumentParser
import Darwin
import Foundation
import HolodeckCore
import HolodeckServices

struct RecordCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record video from a booted simulator. Press Ctrl-C to stop cleanly."
    )

    @Argument(help: "Simulator name or UDID.")
    var query: String

    @Option(name: .shortAndLong, help: "Output file path (default: ~/Screenshots/sim_record_<ts>.mp4).")
    var output: String?

    @Option(help: "Video codec: h264 or hevc. Defaults to value from ~/.config/holodeck/config.json.")
    var codec: String?

    func run() async throws {
        let config = (try? ConfigLoader.load()) ?? .default
        let codecValue: VideoCodec
        if let raw = codec {
            guard let parsed = VideoCodec(rawValue: raw.lowercased()) else {
                throw ValidationError("Invalid codec '\(raw)'. Use h264 or hevc.")
            }
            codecValue = parsed
        } else {
            codecValue = config.videoCodec
        }
        let service = SimulatorService()
        let sim = try await service.resolve(query: query)
        guard sim.state == .booted else {
            throw ValidationError("\(sim.name) is \(sim.state.rawValue); only booted simulators can be recorded.")
        }

        let recording = RecordingService()
        let outURL = output.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? defaultOutputURL(config: config)
        let path = try await recording.start(udid: sim.id, output: outURL, codec: codecValue)
        FileHandle.standardError.write(Data("Recording to \(path.path) — press Ctrl-C to stop.\n".utf8))

        await waitForSIGINT()

        FileHandle.standardError.write(Data("\nFinalizing…\n".utf8))
        _ = await recording.stop()
        print(path.path)
    }

    private func defaultOutputURL(config: Config) -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.timeZone = TimeZone.current
        let stamp = formatter.string(from: Date())
        return config.resolvedScreenshotsDirectory.appendingPathComponent("sim_record_\(stamp).mp4")
    }

    private func waitForSIGINT() async {
        signal(SIGINT, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let box = ContinuationBox(continuation: continuation)
            source.setEventHandler {
                box.fire()
            }
            source.resume()
        }
        source.cancel()
    }

    private final class ContinuationBox: @unchecked Sendable {

        private var continuation: CheckedContinuation<Void, Never>?
        private let lock = NSLock()
        init(continuation: CheckedContinuation<Void, Never>) {
            self.continuation = continuation
        }

        func fire() {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume()
        }
    }
}
