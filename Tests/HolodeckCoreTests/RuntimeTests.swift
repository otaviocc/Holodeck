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

import Testing
@testable import HolodeckCore

struct RuntimeTests {

    @Test("It should reject identifiers without the SimRuntime prefix")
    func rejectsUnknownPrefix() {
        // Then
        #expect(Runtime(identifier: "com.example.SomethingElse.iOS-18-2") == nil)
    }

    @Test("It should reject identifiers whose version part is unparseable")
    func rejectsBadVersion() {
        // Then
        #expect(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-abc") == nil)
    }

    @Test("It should order runtimes by platform name then version")
    func ordering() throws {
        // Given
        let iOS18 = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let iOS17 = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-17-5"))
        let watch = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.watchOS-11-2"))

        // Then
        #expect(iOS17 < iOS18)
        #expect(iOS18 < watch)
    }
}
