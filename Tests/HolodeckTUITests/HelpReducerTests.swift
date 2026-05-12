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

struct HelpReducerTests {

    @Test("It should open the help modal when ? is pressed")
    func questionMarkOpensHelp() {
        // When
        let out = Reducer.reduce(AppState(), .key(.char("?")))

        // Then
        #expect(out.state.modal == .help)
    }

    @Test("It should close the help modal on any key")
    func anyKeyClosesHelp() {
        // Given
        let state = AppState(modal: .help)

        // When
        let out = Reducer.reduce(state, .key(.char("j")))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should close the help modal on Escape")
    func escapeClosesHelp() {
        // Given
        let state = AppState(modal: .help)

        // When
        let out = Reducer.reduce(state, .key(.escape))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should render the keybindings list when help is open")
    func helpRendersKeybindingsList() {
        // Given
        let state = AppState(rows: 30, cols: 80, modal: .help)

        // When
        let frame = SimulatorListView.render(state)
        let plain = SimulatorListView.stripANSI(frame)

        // Then
        #expect(plain.contains("Keybindings"))
        #expect(plain.contains("boot or shutdown"))
        #expect(plain.contains("screenshot"))
    }
}
