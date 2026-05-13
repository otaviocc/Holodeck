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

struct SemanticVersionTests {

    @Test("It should order versions across major, minor, and patch")
    func ordering() {
        // Then
        #expect(SemanticVersion(major: 17, minor: 0) < SemanticVersion(major: 18, minor: 0))
        #expect(SemanticVersion(major: 18, minor: 1) < SemanticVersion(major: 18, minor: 2))
        #expect(SemanticVersion(major: 18, minor: 2) < SemanticVersion(major: 18, minor: 2, patch: 1))
        #expect(!(SemanticVersion(major: 18) < SemanticVersion(major: 18)))
    }

    @Test("It should print without a trailing zero patch")
    func description() {
        // Then
        #expect(SemanticVersion(major: 18, minor: 2).description == "18.2")
        #expect(SemanticVersion(major: 18, minor: 2, patch: 1).description == "18.2.1")
    }
}
