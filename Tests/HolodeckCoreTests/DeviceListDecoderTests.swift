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
        let url = try #require(Bundle.module.url(forResource: "simctl-list-fixture", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let simulators = try DeviceListDecoder.decode(data)
        #expect(!simulators.isEmpty)
        #expect(simulators.allSatisfy { $0.isAvailable })
        #expect(simulators.contains { $0.runtime.platform == .iOS })
    }

    @Test("It should parse platform names from runtime identifiers")
    func platformParsing() {
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2") == .iOS)
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-2") == .watchOS)
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.tvOS-18-1") == .tvOS)
        #expect(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.xrOS-2-1") == .visionOS)
        #expect(Platform(runtimeIdentifier: "garbage") == nil)
    }

    @Test("It should parse semantic version strings")
    func semanticVersionParsing() {
        #expect(SemanticVersion(string: "18.2") == SemanticVersion(major: 18, minor: 2))
        #expect(SemanticVersion(string: "18.2.1") == SemanticVersion(major: 18, minor: 2, patch: 1))
        #expect(SemanticVersion(string: "17") == SemanticVersion(major: 17))
        #expect(SemanticVersion(string: "abc") == nil)
        #expect(SemanticVersion(major: 17, minor: 5) < SemanticVersion(major: 18, minor: 0))
    }

    @Test("It should parse runtime identifiers into platform and version")
    func runtimeParsing() throws {
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        #expect(runtime.platform == .iOS)
        #expect(runtime.version == SemanticVersion(major: 18, minor: 2))
        #expect(runtime.displayName == "iOS 18.2")
    }

    @Test("It should humanize device type identifiers")
    func deviceTypeHumanization() {
        let deviceType = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro")
        #expect(deviceType.name == "iPhone 16 Pro")
    }

    @Test("It should skip simulators whose runtime cannot be parsed")
    func unknownRuntimeIsSkipped() throws {
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
        let result = try DeviceListDecoder.decode(json)
        #expect(result.count == 1)
        #expect(result.first?.name == "Test")
    }
}
