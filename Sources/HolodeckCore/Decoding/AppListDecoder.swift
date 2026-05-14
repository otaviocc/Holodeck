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

public enum AppListDecoder {

    // MARK: - Nested types

    private struct RawApp: Decodable {

        let cfBundleIdentifier: String?
        let cfBundleDisplayName: String?
        let cfBundleName: String?
        let cfBundleShortVersionString: String?
        let cfBundleVersion: String?
        let applicationType: String?

        enum CodingKeys: String, CodingKey {

            case cfBundleIdentifier = "CFBundleIdentifier"
            case cfBundleDisplayName = "CFBundleDisplayName"
            case cfBundleName = "CFBundleName"
            case cfBundleShortVersionString = "CFBundleShortVersionString"
            case cfBundleVersion = "CFBundleVersion"
            case applicationType = "ApplicationType"
        }
    }

    // MARK: - Properties

    private static let decoder = PropertyListDecoder()

    // MARK: - Public

    public static func decode(_ data: Data) throws -> [InstalledApp] {
        let raw = try decoder.decode([String: RawApp].self, from: data)
        let apps: [InstalledApp] = raw.values.compactMap { entry in
            guard let bundleID = entry.cfBundleIdentifier else { return nil }
            let name = entry.cfBundleDisplayName ?? entry.cfBundleName ?? bundleID
            let version = entry.cfBundleShortVersionString ?? entry.cfBundleVersion
            let isUserApp = entry.applicationType == "User"
            return InstalledApp(bundleID: bundleID, name: name, version: version, isUserApp: isUserApp)
        }
        return apps.sorted { lhs, rhs in
            switch lhs.name.localizedCaseInsensitiveCompare(rhs.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: lhs.bundleID < rhs.bundleID
            }
        }
    }
}
