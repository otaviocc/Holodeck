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

final class HelpReducerTests: XCTestCase {

    func testQuestionMarkOpensHelp() {
        let out = Reducer.reduce(AppState(), .key(.char("?")))
        XCTAssertEqual(out.state.modal, .help)
    }

    func testAnyKeyClosesHelp() {
        let state = AppState(modal: .help)
        let out = Reducer.reduce(state, .key(.char("j")))
        XCTAssertNil(out.state.modal)
    }

    func testEscapeClosesHelp() {
        let state = AppState(modal: .help)
        let out = Reducer.reduce(state, .key(.escape))
        XCTAssertNil(out.state.modal)
    }

    func testHelpRendersKeybindingsList() {
        let state = AppState(rows: 30, cols: 80, modal: .help)
        let frame = SimulatorListView.render(state)
        let plain = SimulatorListView.stripANSI(frame)
        XCTAssertTrue(plain.contains("Keybindings"))
        XCTAssertTrue(plain.contains("boot or shutdown"))
        XCTAssertTrue(plain.contains("screenshot"))
    }
}
