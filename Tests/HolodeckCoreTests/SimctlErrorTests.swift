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

struct SimctlErrorTests {

    @Test("It should describe xcodeNotFound")
    func describeXcodeNotFound() {
        // Then
        #expect(SimctlError.xcodeNotFound.description == "Xcode not found")
    }

    @Test("It should describe simulatorNotFound with the query")
    func describeNotFound() {
        // Then
        #expect(SimctlError.simulatorNotFound(query: "iPhone 99").description == "not found: iPhone 99")
    }

    @Test("It should describe ambiguousMatch with the query")
    func describeAmbiguous() {
        // Then
        #expect(SimctlError.ambiguousMatch(query: "iPhone", candidates: []).description == "ambiguous: iPhone")
    }

    @Test("It should describe alreadyInState using the raw state name")
    func describeAlreadyInState() {
        // Then
        #expect(SimctlError.alreadyInState(.booted).description == "already Booted")
    }

    @Test("It should describe commandFailed using stderr when present")
    func describeCommandFailedStderr() {
        // Given
        let error = SimctlError.commandFailed(command: "xcrun simctl boot", exitCode: 1, stderr: " oops \n")

        // Then
        #expect(error.description == "oops")
    }

    @Test("It should describe commandFailed with a fallback when stderr is empty")
    func describeCommandFailedEmpty() {
        // Given
        let error = SimctlError.commandFailed(command: "xcrun simctl boot", exitCode: 1, stderr: "")

        // Then
        #expect(error.description == "command failed")
    }

    @Test("It should describe decodingFailed as decode failed")
    func describeDecodingFailed() {
        // Given
        let inner = NSError(domain: "test", code: 1)

        // Then
        #expect(SimctlError.decodingFailed(underlying: inner).description == "decode failed")
    }

    @Test("It should describe unsupportedOperation with the reason")
    func describeUnsupportedOperation() {
        // Then
        #expect(SimctlError.unsupportedOperation(reason: "nope").description == "nope")
    }
}
