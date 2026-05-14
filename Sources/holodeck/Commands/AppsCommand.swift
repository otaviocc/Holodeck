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

struct AppsCommand: AsyncParsableCommand {

    // MARK: - Nested types

    struct List: AsyncParsableCommand {

        // MARK: - Properties

        static let configuration = CommandConfiguration(
            commandName: "list",
            abstract: "List apps installed on a booted simulator."
        )

        @Argument(help: "Simulator name or UDID.")
        var query: String

        @Flag(name: .long, help: "Include system apps (default: user apps only).")
        var system = false

        @Flag(name: .long, help: "Emit JSON instead of a table.")
        var json = false

        // MARK: - Public

        func run() async throws {
            let service = SimulatorService()
            let sim = try await service.resolveInState(
                query, .booted, purpose: "listapps only works on booted simulators"
            )
            var apps = try await service.listApps(sim.id)
            if !system {
                apps = apps.filter(\.isUserApp)
            }
            if json {
                printJSON(apps)
            } else {
                printTable(apps)
            }
        }

        // MARK: - Private

        private func printJSON(_ apps: [InstalledApp]) {
            struct Out: Encodable {

                let bundleID: String
                let name: String
                let version: String?
                let isUserApp: Bool
            }
            let out = apps.map {
                Out(bundleID: $0.bundleID, name: $0.name, version: $0.version, isUserApp: $0.isUserApp)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? encoder.encode(out), let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        }

        private func printTable(_ apps: [InstalledApp]) {
            let headers = ("NAME", "BUNDLE ID", "VERSION", "TYPE")
            let nameW = max(headers.0.count, apps.map(\.name.count).max() ?? 0)
            let bundleW = max(headers.1.count, apps.map(\.bundleID.count).max() ?? 0)
            let versionW = max(headers.2.count, apps.compactMap(\.version).map(\.count).max() ?? 0)

            func row(_ name: String, _ bundle: String, _ version: String, _ type: String) -> String {
                let paddedName = name.padding(toLength: nameW, withPad: " ", startingAt: 0)
                let paddedBundle = bundle.padding(toLength: bundleW, withPad: " ", startingAt: 0)
                let paddedVersion = version.padding(toLength: versionW, withPad: " ", startingAt: 0)
                return "\(paddedName)  \(paddedBundle)  \(paddedVersion)  \(type)"
            }

            print(row(headers.0, headers.1, headers.2, headers.3))
            for app in apps {
                print(row(
                    app.name,
                    app.bundleID,
                    app.version ?? "—",
                    app.isUserApp ? "user" : "system"
                ))
            }
        }
    }

    // MARK: - Properties

    static let configuration = CommandConfiguration(
        commandName: "apps",
        abstract: "Inspect apps installed on a simulator.",
        subcommands: [List.self]
    )
}
