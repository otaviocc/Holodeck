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

import Darwin
import Foundation

public final class TerminalMode {

    private var original = termios()
    private var isRaw = false

    public init() {}

    public func enterRaw() {
        guard !isRaw else { return }
        var current = termios()
        tcgetattr(STDIN_FILENO, &current)
        original = current

        var raw = current
        raw.c_lflag &= ~UInt(ECHO | ICANON | ISIG | IEXTEN)
        raw.c_iflag &= ~UInt(IXON | ICRNL | BRKINT | INPCK | ISTRIP)
        raw.c_oflag &= ~UInt(OPOST)
        raw.c_cflag |= UInt(CS8)
        withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
            ptr.withMemoryRebound(to: cc_t.self, capacity: Int(NCCS)) { ccArray in
                ccArray[Int(VMIN)] = 0
                ccArray[Int(VTIME)] = 1
            }
        }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)
        isRaw = true
    }

    public func restore() {
        guard isRaw else { return }
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &original)
        isRaw = false
    }

    deinit { restore() }
}

public enum TerminalSize {

    public static func current() -> (rows: Int, cols: Int) {
        var winSize = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &winSize) == 0, winSize.ws_row > 0, winSize.ws_col > 0 {
            return (Int(winSize.ws_row), Int(winSize.ws_col))
        }
        return (24, 80)
    }
}
