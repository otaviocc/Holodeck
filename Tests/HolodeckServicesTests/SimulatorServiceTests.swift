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
import Testing
@testable import HolodeckServices

struct SimulatorServiceTests {

    private let iPhone16Pro = UUID(uuidString: "11111111-0000-0000-0000-000000000001")!
    private let iPhone16 = UUID(uuidString: "11111111-0000-0000-0000-000000000002")!
    private let iPhone15 = UUID(uuidString: "11111111-0000-0000-0000-000000000003")!

    private func deviceListJSON() -> String {
        """
        {
          "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
              {
                "udid": "\(iPhone16Pro.uuidString)",
                "name": "iPhone 16 Pro",
                "state": "Shutdown",
                "isAvailable": true,
                "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
                "dataPath": "/tmp/a",
                "logPath": "/tmp/al"
              },
              {
                "udid": "\(iPhone16.uuidString)",
                "name": "iPhone 16",
                "state": "Shutdown",
                "isAvailable": true,
                "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
                "dataPath": "/tmp/b",
                "logPath": "/tmp/bl"
              },
              {
                "udid": "\(iPhone15.uuidString)",
                "name": "iPhone 15",
                "state": "Shutdown",
                "isAvailable": true,
                "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-15",
                "dataPath": "/tmp/c",
                "logPath": "/tmp/cl"
              }
            ]
          }
        }
        """
    }

    private func service() -> SimulatorService {
        let runner = RecordingRunner(responses: [
            ProcessResult(stdout: Data(deviceListJSON().utf8), stderr: Data(), exitCode: 0)
        ])
        return SimulatorService(client: SimctlClient(runner: runner))
    }

    @Test("It should resolve by exact UDID match")
    func resolveByUDID() async throws {
        // Given
        let svc = service()

        // When
        let sim = try await svc.resolve(query: iPhone16.uuidString)

        // Then
        #expect(sim.id == iPhone16)
    }

    @Test("It should resolve by exact name (case-insensitive)")
    func resolveByExactName() async throws {
        // Given
        let svc = service()

        // When
        let sim = try await svc.resolve(query: "iphone 16")

        // Then
        #expect(sim.id == iPhone16)
    }

    @Test("It should resolve by unique substring when no exact match exists")
    func resolveByUniqueSubstring() async throws {
        // Given
        let svc = service()

        // When
        let sim = try await svc.resolve(query: "16 Pro")

        // Then
        #expect(sim.id == iPhone16Pro)
    }

    @Test("It should throw ambiguousMatch when several names contain the query and none match exactly")
    func resolveAmbiguous() async throws {
        // Given
        let svc = service()

        // Then
        await #expect(throws: SimctlError.self) {
            _ = try await svc.resolve(query: "iPhone")
        }
    }

    @Test("It should throw simulatorNotFound when nothing matches")
    func resolveNotFound() async throws {
        // Given
        let svc = service()

        // Then
        await #expect(throws: SimctlError.self) {
            _ = try await svc.resolve(query: "Apple TV")
        }
    }
}
