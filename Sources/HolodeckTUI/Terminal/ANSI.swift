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

public enum ANSI {

    public static let esc = "\u{1B}"
    public static let csi = "\u{1B}["

    public static let enterAltScreen = "\(csi)?1049h"
    public static let exitAltScreen = "\(csi)?1049l"
    public static let hideCursor = "\(csi)?25l"
    public static let showCursor = "\(csi)?25h"
    public static let clearScreen = "\(csi)2J"
    public static let home = "\(csi)H"
    public static let reset = "\(csi)0m"
    public static let inverse = "\(csi)7m"
    public static let bold = "\(csi)1m"
    public static let dim = "\(csi)2m"

    public static func fg(_ code: Int) -> String {
        "\(csi)\(code)m"
    }

    public static let green = fg(32)
    public static let yellow = fg(33)
    public static let red = fg(31)
    public static let cyan = fg(36)
    public static let gray = fg(90)

    public static func stripEscapes(from text: String) -> String {
        guard text.contains("\u{1B}") else { return text }
        var out = ""
        var inEscape = false
        for char in text {
            if inEscape {
                if char.isLetter { inEscape = false }
                continue
            }
            if char == "\u{1B}" {
                inEscape = true
                continue
            }
            out.append(char)
        }
        return out
    }
}
