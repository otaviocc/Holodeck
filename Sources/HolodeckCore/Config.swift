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

public struct Config: Sendable, Equatable, Codable {

    public var defaultPlatform: Platform?
    public var screenshotsDirectory: String
    public var videoCodec: VideoCodec
    public var screenshotType: ScreenshotType
    public var pollIntervalSeconds: Double

    public init(
        defaultPlatform: Platform? = nil,
        screenshotsDirectory: String = "~/Screenshots",
        videoCodec: VideoCodec = .h264,
        screenshotType: ScreenshotType = .png,
        pollIntervalSeconds: Double = 2.0
    ) {
        self.defaultPlatform = defaultPlatform
        self.screenshotsDirectory = screenshotsDirectory
        self.videoCodec = videoCodec
        self.screenshotType = screenshotType
        self.pollIntervalSeconds = pollIntervalSeconds
    }

    public var resolvedScreenshotsDirectory: URL {
        URL(fileURLWithPath: (screenshotsDirectory as NSString).expandingTildeInPath)
    }

    public static let `default` = Config()
}

extension VideoCodec: Codable {}

extension ScreenshotType: Codable {}

public enum ConfigLoader {

    public static var defaultPath: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        return base.appendingPathComponent("holodeck").appendingPathComponent("config.json")
    }

    public static func load(from url: URL = defaultPath) throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .default
        }
        let data = try Data(contentsOf: url)
        return try decode(data)
    }

    public static func decode(_ data: Data) throws -> Config {
        let decoder = JSONDecoder()
        return try decoder.decode(Config.self, from: data)
    }
}
