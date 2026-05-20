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

public struct URLHistoryStore: Sendable {

    // MARK: - Properties

    public static let capacity = 20

    public let path: URL

    // MARK: - Lifecycle

    public init(path: URL = URLHistoryStore.defaultPath) {
        self.path = path
    }

    // MARK: - Public

    public static var defaultPath: URL {
        let base = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        } ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config")
        return base.appendingPathComponent("holodeck").appendingPathComponent("url-history.json")
    }

    public func load() -> [String] {
        guard let data = try? Data(contentsOf: path),
              let list = try? Self.decoder.decode([String].self, from: data)
        else {
            return []
        }
        return list
    }

    @discardableResult
    public func record(_ url: String) throws -> [String] {
        var list = load()
        list.removeAll { $0 == url }
        list.insert(url, at: 0)
        if list.count > Self.capacity {
            list = Array(list.prefix(Self.capacity))
        }
        try save(list)
        return list
    }

    // MARK: - Private

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder = JSONDecoder()

    private func save(_ list: [String]) throws {
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try Self.encoder.encode(list)
        try data.write(to: path, options: .atomic)
    }
}
