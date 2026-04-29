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

public actor SimctlClient {

    private let runner: any ProcessRunning

    public init(runner: any ProcessRunning = ProcessRunner()) {
        self.runner = runner
    }

    public func listDevices(includeUnavailable: Bool = false) async throws -> [Simulator] {
        var args = ["simctl", "list", "--json", "devices"]
        if !includeUnavailable { args.append("available") }
        let result: ProcessResult
        do {
            result = try await runner.run("/usr/bin/xcrun", args)
        } catch {
            throw SimctlError.commandFailed(
                command: "xcrun \(args.joined(separator: " "))",
                exitCode: -1,
                stderr: String(describing: error)
            )
        }
        guard result.exitCode == 0 else {
            throw SimctlError.commandFailed(
                command: "xcrun \(args.joined(separator: " "))",
                exitCode: result.exitCode,
                stderr: String(data: result.stderr, encoding: .utf8) ?? ""
            )
        }
        do {
            return try DeviceListDecoder.decode(result.stdout)
        } catch {
            throw SimctlError.decodingFailed(underlying: error)
        }
    }

    public func boot(_ udid: UUID) async throws {
        try await runSimctl(["boot", udid.uuidString])
    }

    public func shutdown(_ udid: UUID) async throws {
        try await runSimctl(["shutdown", udid.uuidString])
    }

    public func screenshot(udid: UUID, to path: URL, type: ScreenshotType) async throws {
        try await runSimctl([
            "io", udid.uuidString, "screenshot",
            "--type", type.rawValue,
            path.path
        ])
    }

    private func runSimctl(_ subcommand: [String]) async throws {
        let args = ["simctl"] + subcommand
        let result: ProcessResult
        do {
            result = try await runner.run("/usr/bin/xcrun", args)
        } catch {
            throw SimctlError.commandFailed(
                command: "xcrun \(args.joined(separator: " "))",
                exitCode: -1,
                stderr: String(describing: error)
            )
        }
        guard result.exitCode == 0 else {
            throw SimctlError.commandFailed(
                command: "xcrun \(args.joined(separator: " "))",
                exitCode: result.exitCode,
                stderr: String(data: result.stderr, encoding: .utf8) ?? ""
            )
        }
    }
}
