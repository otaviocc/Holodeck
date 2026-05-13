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

struct DefaultMediaPathTests {

    private let referenceDate = Date(timeIntervalSince1970: 0)

    @Test("It should build an mp4 path for recordings with a yyyyMMdd-HHmmss stamp")
    func recordPath() {
        // Given
        let directory = URL(fileURLWithPath: "/tmp/captures")

        // When
        let path = DefaultMediaPath.record(in: directory, date: referenceDate)

        // Then
        #expect(path.deletingLastPathComponent().path == "/tmp/captures")
        #expect(path.lastPathComponent.hasPrefix("sim_record_"))
        #expect(path.pathExtension == "mp4")
    }

    @Test("It should build a screenshot path with the requested type extension")
    func screenshotPath() {
        // Given
        let directory = URL(fileURLWithPath: "/tmp/captures")

        // When
        let path = DefaultMediaPath.screenshot(in: directory, type: .jpeg, date: referenceDate)

        // Then
        #expect(path.lastPathComponent.hasPrefix("sim_screenshot_"))
        #expect(path.pathExtension == "jpeg")
    }

    @Test("It should create the parent directory for a path")
    func ensureDirectoryExistsCreatesParent() throws {
        // Given
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("holodeck-mediapath-\(UUID().uuidString)")
            .appendingPathComponent("nested")
            .appendingPathComponent("file.mp4")
        defer { try? FileManager.default.removeItem(at: tmp.deletingLastPathComponent().deletingLastPathComponent()) }

        // When
        try DefaultMediaPath.ensureDirectoryExists(for: tmp)

        // Then
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: tmp.deletingLastPathComponent().path, isDirectory: &isDir)
        #expect(exists)
        #expect(isDir.boolValue)
    }
}
