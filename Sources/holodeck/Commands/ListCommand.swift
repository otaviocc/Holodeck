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

struct PlatformArgument: ExpressibleByArgument {

    let platform: Platform

    init?(argument: String) {
        switch argument.lowercased() {
        case "ios": platform = .iOS
        case "watchos": platform = .watchOS
        case "tvos": platform = .tvOS
        case "visionos": platform = .visionOS
        default: return nil
        }
    }
}

struct ListCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available simulators."
    )

    @Option(name: .long, help: "Filter by platform: ios, watchos, tvos, visionos.")
    var platform: PlatformArgument?

    @Flag(name: .long, help: "Only show available simulators (default).")
    var available = false

    @Flag(name: .long, help: "Emit JSON instead of a table.")
    var json = false

    func run() async throws {
        let service = SimulatorService()
        var simulators = try await service.list()
        let config = (try? ConfigLoader.load()) ?? .default
        let effectivePlatform = platform?.platform ?? config.defaultPlatform
        if let filter = effectivePlatform {
            simulators = simulators.filter { $0.runtime.platform == filter }
        }
        if json {
            printJSON(simulators)
        } else {
            printTable(simulators)
        }
    }

    private func printJSON(_ simulators: [Simulator]) {
        struct Out: Encodable {

            let udid: String
            let name: String
            let runtime: String
            let deviceType: String
            let state: String
            let isAvailable: Bool
        }
        let out = simulators.map {
            Out(
                udid: $0.id.uuidString,
                name: $0.name,
                runtime: $0.runtime.displayName,
                deviceType: $0.deviceType.name,
                state: $0.state.rawValue,
                isAvailable: $0.isAvailable
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(out), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    private func printTable(_ simulators: [Simulator]) {
        let sorted = simulators.sorted { lhs, rhs in
            if lhs.runtime != rhs.runtime { return lhs.runtime > rhs.runtime }
            return lhs.name < rhs.name
        }
        let headers = ("RUNTIME", "NAME", "STATE", "UDID")
        let runtimeW = max(headers.0.count, sorted.map(\.runtime.displayName.count).max() ?? 0)
        let nameW = max(headers.1.count, sorted.map(\.name.count).max() ?? 0)
        let stateW = max(headers.2.count, sorted.map(\.state.rawValue.count).max() ?? 0)

        func row(_ runtime: String, _ name: String, _ state: String, _ udid: String) -> String {
            let paddedRuntime = runtime.padding(toLength: runtimeW, withPad: " ", startingAt: 0)
            let paddedName = name.padding(toLength: nameW, withPad: " ", startingAt: 0)
            let paddedState = state.padding(toLength: stateW, withPad: " ", startingAt: 0)
            return "\(paddedRuntime)  \(paddedName)  \(paddedState)  \(udid)"
        }

        print(row(headers.0, headers.1, headers.2, headers.3))
        for sim in sorted {
            print(row(
                sim.runtime.displayName,
                sim.name,
                sim.state.rawValue,
                sim.id.uuidString
            ))
        }
    }
}
