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

public struct Runtime: Sendable, Equatable, Hashable, Comparable {

    public let platform: Platform
    public let version: SemanticVersion
    public let identifier: String

    public init(platform: Platform, version: SemanticVersion, identifier: String) {
        self.platform = platform
        self.version = version
        self.identifier = identifier
    }

    public init?(identifier: String) {
        guard let platform = Platform(runtimeIdentifier: identifier) else { return nil }
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        let suffix = String(identifier.dropFirst(prefix.count))
        guard let dash = suffix.firstIndex(of: "-") else { return nil }
        let versionPart = suffix[suffix.index(after: dash)...]
            .replacingOccurrences(of: "-", with: ".")
        guard let version = SemanticVersion(string: versionPart) else { return nil }
        self.platform = platform
        self.version = version
        self.identifier = identifier
    }

    public var displayName: String {
        "\(platform.rawValue) \(version)"
    }

    public static func < (lhs: Runtime, rhs: Runtime) -> Bool {
        if lhs.platform.rawValue != rhs.platform.rawValue {
            return lhs.platform.rawValue < rhs.platform.rawValue
        }
        return lhs.version < rhs.version
    }
}
