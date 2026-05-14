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

struct LocationCommand: AsyncParsableCommand {

    // MARK: - Nested types

    struct Set: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "set",
            abstract: "Set the simulated GPS location."
        )

        @Argument(help: "Simulator name or UDID.")
        var query: String

        @Argument(help: "Latitude (e.g. 37.7749).")
        var latitude: Double

        @Argument(help: "Longitude (e.g. -122.4194).")
        var longitude: Double

        func run() async throws {
            let service = SimulatorService()
            let sim = try await service.resolveInState(
                query, .booted, purpose: "the simulator must be booted"
            )
            try await LocationService().set(udid: sim.id, latitude: latitude, longitude: longitude)
            print("Set \(sim.name) location to \(latitude),\(longitude).")
        }
    }

    struct Clear: AsyncParsableCommand {

        static let configuration = CommandConfiguration(
            commandName: "clear",
            abstract: "Clear the simulated GPS location."
        )

        @Argument(help: "Simulator name or UDID.")
        var query: String

        func run() async throws {
            let service = SimulatorService()
            let sim = try await service.resolveInState(
                query, .booted, purpose: "the simulator must be booted"
            )
            try await LocationService().clear(udid: sim.id)
            print("Cleared location on \(sim.name).")
        }
    }

    static let configuration = CommandConfiguration(
        commandName: "location",
        abstract: "Set or clear the simulator's simulated GPS location.",
        subcommands: [Set.self, Clear.self]
    )
}
