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

import XCTest
@testable import HolodeckCore

final class DeviceListDecoderTests: XCTestCase {

    func testDecodesFixture() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "simctl-list-fixture", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let simulators = try DeviceListDecoder.decode(data)
        XCTAssertFalse(simulators.isEmpty)
        XCTAssertTrue(simulators.allSatisfy(\.isAvailable))
        XCTAssertTrue(simulators.contains { $0.runtime.platform == .iOS })
    }

    func testPlatformParsing() {
        XCTAssertEqual(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"), .iOS)
        XCTAssertEqual(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-2"), .watchOS)
        XCTAssertEqual(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.tvOS-18-1"), .tvOS)
        XCTAssertEqual(Platform(runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.xrOS-2-1"), .visionOS)
        XCTAssertNil(Platform(runtimeIdentifier: "garbage"))
    }

    func testSemanticVersionParsing() {
        XCTAssertEqual(SemanticVersion(string: "18.2"), SemanticVersion(major: 18, minor: 2))
        XCTAssertEqual(SemanticVersion(string: "18.2.1"), SemanticVersion(major: 18, minor: 2, patch: 1))
        XCTAssertEqual(SemanticVersion(string: "17"), SemanticVersion(major: 17))
        XCTAssertNil(SemanticVersion(string: "abc"))
        XCTAssertLessThan(SemanticVersion(major: 17, minor: 5), SemanticVersion(major: 18, minor: 0))
    }

    func testRuntimeParsing() throws {
        let runtime = try XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        XCTAssertEqual(runtime.platform, .iOS)
        XCTAssertEqual(runtime.version, SemanticVersion(major: 18, minor: 2))
        XCTAssertEqual(runtime.displayName, "iOS 18.2")
    }

    func testDeviceTypeHumanization() {
        let dt = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro")
        XCTAssertEqual(dt.name, "iPhone 16 Pro")
    }

    func testUnknownRuntimeIsSkipped() throws {
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
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.name, "Test")
    }
}
