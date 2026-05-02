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

final class ConfigTests: XCTestCase {

    func testDefaults() {
        let config = Config.default
        XCTAssertNil(config.defaultPlatform)
        XCTAssertEqual(config.screenshotsDirectory, "~/Screenshots")
        XCTAssertEqual(config.videoCodec, .h264)
        XCTAssertEqual(config.screenshotType, .png)
        XCTAssertEqual(config.pollIntervalSeconds, 2.0)
    }

    func testDecodeFullConfig() throws {
        let json = Data("""
        {
          "defaultPlatform": "watchOS",
          "screenshotsDirectory": "~/Captures",
          "videoCodec": "hevc",
          "screenshotType": "jpeg",
          "pollIntervalSeconds": 5
        }
        """.utf8)
        let config = try ConfigLoader.decode(json)
        XCTAssertEqual(config.defaultPlatform, .watchOS)
        XCTAssertEqual(config.screenshotsDirectory, "~/Captures")
        XCTAssertEqual(config.videoCodec, .hevc)
        XCTAssertEqual(config.screenshotType, .jpeg)
        XCTAssertEqual(config.pollIntervalSeconds, 5)
    }

    func testDecodeRejectsMalformed() {
        let json = Data("not json".utf8)
        XCTAssertThrowsError(try ConfigLoader.decode(json))
    }

    func testDecodeRejectsUnknownEnumValue() {
        let json = Data("""
        { "videoCodec": "av1", "screenshotsDirectory": "~/x", "screenshotType": "png", "pollIntervalSeconds": 2 }
        """.utf8)
        XCTAssertThrowsError(try ConfigLoader.decode(json))
    }

    func testLoadMissingFileReturnsDefault() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("holodeck-missing-\(UUID().uuidString).json")
        let config = try ConfigLoader.load(from: tmp)
        XCTAssertEqual(config, .default)
    }

    func testLoadFromFile() throws {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("holodeck-test-\(UUID().uuidString).json")
        let payload = Data("""
        { "screenshotsDirectory": "~/Foo", "videoCodec": "hevc", "screenshotType": "png", "pollIntervalSeconds": 1 }
        """.utf8)
        try payload.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let config = try ConfigLoader.load(from: tmp)
        XCTAssertEqual(config.videoCodec, .hevc)
        XCTAssertEqual(config.screenshotsDirectory, "~/Foo")
    }

    func testResolvedScreenshotsDirectoryExpandsTilde() {
        let config = Config(screenshotsDirectory: "~/Pictures")
        XCTAssertFalse(config.resolvedScreenshotsDirectory.path.hasPrefix("~"))
        XCTAssertTrue(config.resolvedScreenshotsDirectory.path.hasSuffix("/Pictures"))
    }
}
