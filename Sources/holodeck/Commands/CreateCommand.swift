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
import Foundation
import HolodeckCore
import HolodeckServices

struct CreateCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new simulator by device type and runtime."
    )

    @Argument(help: "Name for the new simulator.")
    var name: String

    @Option(help: "Device type (substring matched against the device type name, e.g. \"iPhone 16 Pro\").")
    var device: String

    @Option(help: "Runtime (substring matched against the runtime display name, e.g. \"iOS 18.2\").")
    var runtime: String

    func run() async throws {
        let service = SimulatorService()
        let targets = try await service.availableTargets()

        let deviceMatches = matchDeviceTypes(in: targets.deviceTypes, query: device)
        guard let deviceType = try deviceMatches.uniqueOrThrow(label: "device type", query: device) else {
            return
        }

        let runtimeMatches = matchRuntimes(in: targets.runtimes, query: runtime)
        guard let runtime = try runtimeMatches.uniqueOrThrow(label: "runtime", query: runtime) else {
            return
        }

        let udid = try await service.create(name: name, deviceType: deviceType, runtime: runtime)
        print("Created \(name) (\(udid.uuidString)) — \(deviceType.name) / \(runtime.displayName)")
    }

    private func matchDeviceTypes(in types: [DeviceType], query: String) -> [DeviceType] {
        let needle = query.lowercased()
        let exact = types.filter { $0.name.lowercased() == needle }
        if !exact.isEmpty { return exact }
        return types.filter { $0.name.lowercased().contains(needle) }
    }

    private func matchRuntimes(in runtimes: [Runtime], query: String) -> [Runtime] {
        let needle = query.lowercased()
        let exact = runtimes.filter { $0.displayName.lowercased() == needle }
        if !exact.isEmpty { return exact }
        return runtimes.filter { $0.displayName.lowercased().contains(needle) }
    }
}

private extension Array {

    func uniqueOrThrow(label: String, query: String) throws -> Element? {
        if isEmpty {
            throw ValidationError("No \(label) matches '\(query)'.")
        }
        if count > 1 {
            throw ValidationError("Multiple \(label)s match '\(query)'. Be more specific.")
        }
        return first
    }
}
