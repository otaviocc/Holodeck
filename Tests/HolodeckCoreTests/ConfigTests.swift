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

struct ConfigTests {

    @Test("It should provide sensible defaults")
    func defaults() {
        // Given
        let config = Config.default

        // Then
        #expect(config.defaultPlatform == nil)
        #expect(config.screenshotsDirectory == "~/Desktop")
        #expect(config.videoCodec == .h264)
        #expect(config.screenshotType == .png)
        #expect(config.pollIntervalSeconds == 2.0)
    }

    @Test("It should decode a fully populated config")
    func decodeFull() throws {
        // Given
        let json = Data("""
        {
          "defaultPlatform": "watchOS",
          "screenshotsDirectory": "~/Captures",
          "videoCodec": "hevc",
          "screenshotType": "jpeg",
          "pollIntervalSeconds": 5
        }
        """.utf8)

        // When
        let config = try ConfigLoader.decode(json)

        // Then
        #expect(config.defaultPlatform == .watchOS)
        #expect(config.screenshotsDirectory == "~/Captures")
        #expect(config.videoCodec == .hevc)
        #expect(config.screenshotType == .jpeg)
        #expect(config.pollIntervalSeconds == 5)
    }

    @Test("It should reject malformed JSON")
    func rejectMalformed() {
        // Given
        let json = Data("not json".utf8)

        // Then
        #expect(throws: (any Error).self) {
            try ConfigLoader.decode(json)
        }
    }

    @Test("It should reject unknown enum values")
    func rejectUnknownEnum() {
        // Given
        let json = Data("""
        { "videoCodec": "av1", "screenshotsDirectory": "~/x", "screenshotType": "png", "pollIntervalSeconds": 2 }
        """.utf8)

        // Then
        #expect(throws: (any Error).self) {
            try ConfigLoader.decode(json)
        }
    }

    @Test("It should return defaults when the config file is missing")
    func missingFile() throws {
        // Given
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("holodeck-missing-\(UUID().uuidString).json")

        // When
        let config = try ConfigLoader.load(from: tmp)

        // Then
        #expect(config == .default)
    }

    @Test("It should load a config file from disk")
    func loadFromFile() throws {
        // Given
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("holodeck-test-\(UUID().uuidString).json")
        let payload = Data("""
        { "screenshotsDirectory": "~/Foo", "videoCodec": "hevc", "screenshotType": "png", "pollIntervalSeconds": 1 }
        """.utf8)
        try payload.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }

        // When
        let config = try ConfigLoader.load(from: tmp)

        // Then
        #expect(config.videoCodec == .hevc)
        #expect(config.screenshotsDirectory == "~/Foo")
    }

    @Test("It should expand the tilde in screenshotsDirectory")
    func expandTilde() {
        // Given
        let config = Config(screenshotsDirectory: "~/Pictures")

        // Then
        #expect(!config.resolvedScreenshotsDirectory.path.hasPrefix("~"))
        #expect(config.resolvedScreenshotsDirectory.path.hasSuffix("/Pictures"))
    }
}
