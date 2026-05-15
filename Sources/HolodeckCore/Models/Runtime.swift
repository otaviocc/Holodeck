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

    // MARK: - Properties

    public let platform: Platform
    public let version: SemanticVersion
    public let identifier: String

    // MARK: - Lifecycle

    public init(platform: Platform, version: SemanticVersion, identifier: String) {
        self.platform = platform
        self.version = version
        self.identifier = identifier
    }

    public init?(identifier: String) {
        guard identifier.hasPrefix(SimctlIdentifiers.runtimePrefix) else { return nil }
        let suffix = identifier.dropFirst(SimctlIdentifiers.runtimePrefix.count)
        guard let dash = suffix.firstIndex(of: "-") else { return nil }
        let platformName = String(suffix[..<dash])
        let versionPart = suffix[suffix.index(after: dash)...]
            .replacingOccurrences(of: "-", with: ".")
        guard let platform = Platform(simctlName: platformName),
              let version = SemanticVersion(string: versionPart) else { return nil }
        self.platform = platform
        self.version = version
        self.identifier = identifier
    }

    /// Apple sometimes ships point releases under the same identifier
    /// (e.g. iOS-26-4 hosts both 26.4 and 26.4.1). Prefer the explicit
    /// version string from `simctl list --json runtimes` when available.
    public init?(identifier: String, versionString: String?) {
        guard let parsed = Runtime(identifier: identifier) else { return nil }
        let resolvedVersion = versionString.flatMap(SemanticVersion.init(string:)) ?? parsed.version
        platform = parsed.platform
        version = resolvedVersion
        self.identifier = identifier
    }

    // MARK: - Public

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
