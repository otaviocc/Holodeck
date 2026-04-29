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

public enum Platform: String, Sendable, CaseIterable, Codable {

    case iOS
    case watchOS
    case tvOS
    case visionOS

    public init?(runtimeIdentifier: String) {
        let prefix = "com.apple.CoreSimulator.SimRuntime."
        guard runtimeIdentifier.hasPrefix(prefix) else { return nil }
        let suffix = runtimeIdentifier.dropFirst(prefix.count)
        guard let dash = suffix.firstIndex(of: "-") else { return nil }
        let name = String(suffix[..<dash])
        switch name.lowercased() {
        case "ios": self = .iOS
        case "watchos": self = .watchOS
        case "tvos": self = .tvOS
        case "xros", "visionos": self = .visionOS
        default: return nil
        }
    }
}
