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
@testable import HolodeckTUI

struct InputParserTests {

    private let parser = InputParser()

    @Test("It should decode CSI arrow sequences as directional keys")
    func arrowKeys() {
        #expect(parser.parse([0x1B, 0x5B, 0x41]) == [.up])
        #expect(parser.parse([0x1B, 0x5B, 0x42]) == [.down])
        #expect(parser.parse([0x1B, 0x5B, 0x43]) == [.right])
        #expect(parser.parse([0x1B, 0x5B, 0x44]) == [.left])
    }

    @Test("It should map printable characters and control bytes to keys")
    func printableAndControl() {
        #expect(parser.parse(Array("jkq".utf8)) == [.char("j"), .char("k"), .char("q")])
        #expect(parser.parse([0x0D]) == [.enter])
        #expect(parser.parse([0x0A]) == [.enter])
        #expect(parser.parse([0x09]) == [.tab])
        #expect(parser.parse([0x7F]) == [.backspace])
    }

    @Test("It should emit a lone escape byte as the escape key")
    func loneEscape() {
        #expect(parser.parse([0x1B]) == [.escape])
    }

    @Test("It should parse mixed CSI and printable byte sequences")
    func mixedSequence() {
        let bytes: [UInt8] = [0x1B, 0x5B, 0x42, 0x6A, 0x0D]
        #expect(parser.parse(bytes) == [.down, .char("j"), .enter])
    }
}
