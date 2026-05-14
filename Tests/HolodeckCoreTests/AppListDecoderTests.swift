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

struct AppListDecoderTests {

    private static let fixture = #"""
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>com.example.UserApp</key>
        <dict>
            <key>ApplicationType</key>
            <string>User</string>
            <key>CFBundleIdentifier</key>
            <string>com.example.UserApp</string>
            <key>CFBundleDisplayName</key>
            <string>My User App</string>
            <key>CFBundleName</key>
            <string>UserAppBinary</string>
            <key>CFBundleShortVersionString</key>
            <string>1.2.3</string>
            <key>CFBundleVersion</key>
            <string>456</string>
        </dict>
        <key>com.apple.Maps</key>
        <dict>
            <key>ApplicationType</key>
            <string>System</string>
            <key>CFBundleIdentifier</key>
            <string>com.apple.Maps</string>
            <key>CFBundleName</key>
            <string>Maps</string>
            <key>CFBundleVersion</key>
            <string>1.0</string>
        </dict>
        <key>com.example.NoDisplayName</key>
        <dict>
            <key>ApplicationType</key>
            <string>User</string>
            <key>CFBundleIdentifier</key>
            <string>com.example.NoDisplayName</string>
            <key>CFBundleName</key>
            <string>Fallback Name</string>
        </dict>
    </dict>
    </plist>
    """#

    @Test("It should decode the plist into InstalledApps")
    func decodesPlist() throws {
        // Given
        let data = try #require(Self.fixture.data(using: .utf8))

        // When
        let apps = try AppListDecoder.decode(data)

        // Then
        #expect(apps.count == 3)
    }

    @Test("It should prefer CFBundleDisplayName over CFBundleName")
    func prefersDisplayName() throws {
        // Given
        let data = try #require(Self.fixture.data(using: .utf8))

        // When
        let user = try AppListDecoder.decode(data).first { $0.bundleID == "com.example.UserApp" }

        // Then
        let app = try #require(user)
        #expect(app.name == "My User App")
    }

    @Test("It should fall back to CFBundleName when display name is missing")
    func fallsBackToBundleName() throws {
        // Given
        let data = try #require(Self.fixture.data(using: .utf8))

        // When
        let entry = try AppListDecoder.decode(data).first { $0.bundleID == "com.example.NoDisplayName" }

        // Then
        let app = try #require(entry)
        #expect(app.name == "Fallback Name")
    }

    @Test("It should flag system apps")
    func flagsSystemApps() throws {
        // Given
        let data = try #require(Self.fixture.data(using: .utf8))

        // When
        let apps = try AppListDecoder.decode(data)

        // Then
        let user = try #require(apps.first { $0.bundleID == "com.example.UserApp" })
        let system = try #require(apps.first { $0.bundleID == "com.apple.Maps" })
        #expect(user.isUserApp == true)
        #expect(system.isUserApp == false)
    }

    @Test("It should prefer CFBundleShortVersionString over CFBundleVersion")
    func prefersShortVersion() throws {
        // Given
        let data = try #require(Self.fixture.data(using: .utf8))

        // When
        let app = try AppListDecoder.decode(data).first { $0.bundleID == "com.example.UserApp" }

        // Then
        #expect(app?.version == "1.2.3")
    }

    @Test("It should sort results by name case-insensitively")
    func sortsByName() throws {
        // Given
        let data = try #require(Self.fixture.data(using: .utf8))

        // When
        let names = try AppListDecoder.decode(data).map(\.name)

        // Then
        // Fallback Name, Maps, My User App
        #expect(names == ["Fallback Name", "Maps", "My User App"])
    }
}
