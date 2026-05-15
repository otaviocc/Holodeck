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
import Testing
@testable import HolodeckCore

struct DeviceListDecoderTests {

    @Test("It should decode the captured simctl list fixture")
    func decodesFixture() throws {
        // Given
        let url = try #require(Bundle.module.url(forResource: "simctl-list-fixture", withExtension: "json"))
        let data = try Data(contentsOf: url)

        // When
        let simulators = try DeviceListDecoder.decode(data)

        // Then
        #expect(!simulators.isEmpty)
        // swiftformat:disable:next preferKeyPath
        #expect(simulators.allSatisfy { $0.isAvailable })
        #expect(simulators.contains { $0.runtime.platform == .iOS })
    }

    @Test("It should parse platform names from runtime identifiers")
    func platformParsing() {
        // Then
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2") == .iOS)
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-2") == .watchOS)
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.tvOS-18-1") == .tvOS)
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.xrOS-2-1") == .visionOS)
        #expect(Platform(runtimeIdentifier: "garbage") == nil)
    }

    @Test("It should parse semantic version strings")
    func semanticVersionParsing() {
        // Then
        #expect(SemanticVersion(string: "18.2") == SemanticVersion(major: 18, minor: 2))
        #expect(SemanticVersion(string: "18.2.1") == SemanticVersion(major: 18, minor: 2, patch: 1))
        #expect(SemanticVersion(string: "17") == SemanticVersion(major: 17))
        #expect(SemanticVersion(string: "abc") == nil)
        #expect(SemanticVersion(major: 17, minor: 5) < SemanticVersion(major: 18, minor: 0))
    }

    @Test("It should parse runtime identifiers into platform and version")
    func runtimeParsing() throws {
        // When
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))

        // Then
        #expect(runtime.platform == .iOS)
        #expect(runtime.version == SemanticVersion(major: 18, minor: 2))
        #expect(runtime.displayName == "iOS 18.2")
    }

    @Test("It should humanize device type identifiers")
    func deviceTypeHumanization() {
        // When
        let deviceType = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro")

        // Then
        #expect(deviceType.name == "iPhone 16 Pro")
    }

    @Test("It should skip simulators whose runtime cannot be parsed")
    func unknownRuntimeIsSkipped() throws {
        // Given
        let json = Data("""
        { "devices": {
            "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
                { "udid": "00000000-0000-0000-0000-000000000001",
                  "name": "Test",
                  "state": "Shutdown",
                  "isAvailable": true,
                  "deviceTypeIdentifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16",
                  "dataPath": "/tmp/data",
                  "logPath": "/tmp/log" }
            ],
            "garbage-runtime-id": [
                { "udid": "00000000-0000-0000-0000-000000000002",
                  "name": "Skipped",
                  "state": "Shutdown",
                  "isAvailable": true,
                  "deviceTypeIdentifier": "x",
                  "dataPath": "/tmp/d2",
                  "logPath": "/tmp/l2" }
            ]
        }}
        """.utf8)

        // When
        let result = try DeviceListDecoder.decode(json)

        // Then
        #expect(result.count == 1)
        #expect(result.first?.name == "Test")
    }

    @Test("It should prefer the JSON version string over the identifier-parsed version")
    func availableTargetsUsesJSONVersion() throws {
        // Given two runtimes sharing the same identifier — Apple does this for
        // point releases (e.g. iOS-26-4 hosts both 26.4 and 26.4.1).
        let json = Data("""
        { "devicetypes": [],
          "runtimes": [
            { "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-4",
              "name": "iOS 26.4", "version": "26.4", "isAvailable": true },
            { "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-26-4",
              "name": "iOS 26.4", "version": "26.4.1", "isAvailable": true }
          ]
        }
        """.utf8)

        // When
        let targets = try DeviceListDecoder.decodeAvailableTargets(json)

        // Then
        #expect(targets.runtimes.count == 2)
        let versions = targets.runtimes.map(\.version.description).sorted()
        #expect(versions == ["26.4", "26.4.1"])
        let displays = Set(targets.runtimes.map(\.displayName))
        #expect(displays == ["iOS 26.4", "iOS 26.4.1"])
    }

    @Test("It should drop Apple TV device types from the available targets")
    func availableTargetsExcludesAppleTV() throws {
        // Given
        let json = Data("""
        { "devicetypes": [
            { "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro",
              "name": "iPhone 17 Pro" },
            { "identifier": "com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K-3rd-generation-4K",
              "name": "Apple TV 4K (3rd generation)" },
            { "identifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-10-46mm",
              "name": "Apple Watch Series 10 (46mm)" }
          ],
          "runtimes": []
        }
        """.utf8)

        // When
        let targets = try DeviceListDecoder.decodeAvailableTargets(json)

        // Then
        let names = targets.deviceTypes.map(\.name)
        #expect(names == ["iPhone 17 Pro", "Apple Watch Series 10 (46mm)"])
    }
}
