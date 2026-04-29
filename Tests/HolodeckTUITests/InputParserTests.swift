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

import XCTest
@testable import HolodeckTUI

final class InputParserTests: XCTestCase {

    private let parser = InputParser()

    func testArrowKeys() {
        XCTAssertEqual(parser.parse([0x1B, 0x5B, 0x41]), [.up])
        XCTAssertEqual(parser.parse([0x1B, 0x5B, 0x42]), [.down])
        XCTAssertEqual(parser.parse([0x1B, 0x5B, 0x43]), [.right])
        XCTAssertEqual(parser.parse([0x1B, 0x5B, 0x44]), [.left])
    }

    func testPrintableAndControl() {
        XCTAssertEqual(parser.parse(Array("jkq".utf8)), [.char("j"), .char("k"), .char("q")])
        XCTAssertEqual(parser.parse([0x0D]), [.enter])
        XCTAssertEqual(parser.parse([0x0A]), [.enter])
        XCTAssertEqual(parser.parse([0x09]), [.tab])
        XCTAssertEqual(parser.parse([0x7F]), [.backspace])
    }

    func testLoneEscape() {
        XCTAssertEqual(parser.parse([0x1B]), [.escape])
    }

    func testMixedSequence() {
        let bytes: [UInt8] = [0x1B, 0x5B, 0x42, 0x6A, 0x0D]
        XCTAssertEqual(parser.parse(bytes), [.down, .char("j"), .enter])
    }
}
