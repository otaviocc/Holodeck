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

public enum Key: Equatable, Sendable {

    case up
    case down
    case left
    case right
    case enter
    case escape
    case tab
    case backspace
    case char(Character)
    case unknown
}

public struct InputParser: Sendable {

    public init() {}

    public func parse(_ bytes: [UInt8]) -> [Key] {
        var keys: [Key] = []
        var idx = 0
        while idx < bytes.count {
            let byte = bytes[idx]
            if byte == 0x1B {
                if idx + 2 < bytes.count, bytes[idx + 1] == 0x5B {
                    switch bytes[idx + 2] {
                    case 0x41:
                        keys.append(.up)
                        idx += 3
                        continue
                    case 0x42:
                        keys.append(.down)
                        idx += 3
                        continue
                    case 0x43:
                        keys.append(.right)
                        idx += 3
                        continue
                    case 0x44:
                        keys.append(.left)
                        idx += 3
                        continue
                    default:
                        keys.append(.escape)
                        idx += 1
                        continue
                    }
                } else {
                    keys.append(.escape)
                    idx += 1
                    continue
                }
            }
            switch byte {
            case 0x0A, 0x0D: keys.append(.enter)
            case 0x09: keys.append(.tab)
            case 0x7F, 0x08: keys.append(.backspace)
            default:
                if byte >= 0x20, byte < 0x7F {
                    keys.append(.char(Character(UnicodeScalar(byte))))
                } else {
                    keys.append(.unknown)
                }
            }
            idx += 1
        }
        return keys
    }
}
