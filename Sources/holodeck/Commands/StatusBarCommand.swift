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

struct StatusBarCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "statusbar",
        abstract: "Override or clear the simulator status bar. Overrides only persist while the simulator runs.",
        subcommands: [Override.self, Clear.self]
    )

    struct Override: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "override",
            abstract: "Set one or more status bar fields on a booted simulator."
        )

        @Argument(help: "Simulator name or UDID.")
        var query: String

        @Option(help: "Time string, e.g. 9:41.")
        var time: String?

        @Option(help: "Battery state: charging, charged, discharging.")
        var batteryState: String?

        @Option(help: "Battery level (0–100).")
        var batteryLevel: Int?

        @Option(help: "Wi-Fi bars (0–3).")
        var wifiBars: Int?

        @Option(help: "Cellular bars (0–4).")
        var cellularBars: Int?

        @Option(help: "Operator name.")
        var operatorName: String?

        func run() async throws {
            let batteryState = try batteryState.map { raw -> BatteryState in
                guard let value = BatteryState(rawValue: raw.lowercased()) else {
                    throw ValidationError("Invalid battery state '\(raw)'. Use charging, charged, or discharging.")
                }
                return value
            }
            let overrides = StatusBarOverrides(
                time: time,
                batteryState: batteryState,
                batteryLevel: batteryLevel,
                wifiBars: wifiBars,
                cellularBars: cellularBars,
                operatorName: operatorName
            )
            guard !overrides.isEmpty else {
                throw ValidationError("Provide at least one --option to override.")
            }
            let service = SimulatorService()
            let sim = try await service.resolve(query: query)
            guard sim.state == .booted else {
                throw ValidationError("\(sim.name) is \(sim.state.rawValue); the simulator must be booted.")
            }
            try await StatusBarService().override(udid: sim.id, overrides: overrides)
            print("Applied status bar overrides to \(sim.name).")
        }
    }

    struct Clear: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear status bar overrides."
        )

        @Argument(help: "Simulator name or UDID.")
        var query: String

        func run() async throws {
            let service = SimulatorService()
            let sim = try await service.resolve(query: query)
            guard sim.state == .booted else {
                throw ValidationError("\(sim.name) is \(sim.state.rawValue); the simulator must be booted.")
            }
            try await StatusBarService().clear(udid: sim.id)
            print("Cleared status bar overrides on \(sim.name).")
        }
    }
}
