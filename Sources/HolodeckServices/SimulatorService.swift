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

public struct SimulatorService: Sendable {

    // MARK: - Properties

    private let client: SimctlClient

    // MARK: - Lifecycle

    public init(client: SimctlClient = SimctlClient()) {
        self.client = client
    }

    // MARK: - Public

    public func list(includeUnavailable: Bool = false) async throws -> [Simulator] {
        try await client.listDevices(includeUnavailable: includeUnavailable)
    }

    public func boot(_ udid: UUID) async throws {
        try await client.boot(udid)
    }

    public func shutdown(_ udid: UUID) async throws {
        try await client.shutdown(udid)
    }

    public func availableTargets() async throws -> AvailableTargets {
        try await client.listAvailableTargets()
    }

    public func create(name: String, deviceType: DeviceType, runtime: Runtime) async throws -> UUID {
        try await client.create(
            name: name,
            deviceTypeIdentifier: deviceType.identifier,
            runtimeIdentifier: runtime.identifier
        )
    }

    public func erase(_ udid: UUID) async throws {
        try await client.erase(udid)
    }

    public func delete(_ udid: UUID) async throws {
        try await client.delete(udid)
    }

    public func deleteUnavailable() async throws {
        try await client.deleteUnavailable()
    }

    public func focus(_ udid: UUID) async throws {
        try await client.focusSimulatorApp(udid: udid)
    }

    public func resolve(query: String) async throws -> Simulator {
        let all = try await list()
        if let uuid = UUID(uuidString: query),
           let match = all.first(where: { $0.id == uuid })
        {
            return match
        }
        let needle = query.lowercased()
        var exact: [Simulator] = []
        var partial: [Simulator] = []
        for sim in all {
            let name = sim.name.lowercased()
            if name == needle {
                exact.append(sim)
            } else if name.contains(needle) {
                partial.append(sim)
            }
        }
        if exact.count == 1 { return exact[0] }
        if exact.count > 1 {
            throw SimctlError.ambiguousMatch(query: query, candidates: exact)
        }
        if partial.count == 1 { return partial[0] }
        if partial.isEmpty { throw SimctlError.simulatorNotFound(query: query) }
        throw SimctlError.ambiguousMatch(query: query, candidates: partial)
    }
}
