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
import HolodeckCore
import Testing
@testable import HolodeckTUI

struct FilterReducerTests {

    private func sim(name: String, state: SimulatorState = .shutdown) throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: name,
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
            state: state,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    @Test("It should enter filter focus with empty query when / is pressed")
    func slashEntersFilterFocus() throws {
        // Given
        let state = try AppState(simulators: [sim(name: "Alpha")], selectedIndex: 0)

        // When
        let out = Reducer.reduce(state, .key(.char("/")))

        // Then
        #expect(out.state.isFilterFocused == true)
        #expect(out.state.filterQuery.isEmpty)
        #expect(out.state.selectedIndex == 0)
    }

    @Test("It should append printable characters to the filter query while focused")
    func typingAppendsToQuery() throws {
        // Given
        let sims = try [sim(name: "Alpha"), sim(name: "Beta"), sim(name: "Gamma")]
        var state = AppState(simulators: sims, isFilterFocused: true)

        // When
        state = Reducer.reduce(state, .key(.char("a"))).state
        state = Reducer.reduce(state, .key(.char("l"))).state

        // Then
        #expect(state.filterQuery == "al")
        #expect(state.visibleSimulators.count == 1)
        #expect(state.visibleSimulators.first?.name == "Alpha")
    }

    @Test("It should remove the last character on Backspace")
    func backspaceTrimsQuery() throws {
        // Given
        var state = try AppState(
            simulators: [sim(name: "Phone"), sim(name: "Watch")],
            filterQuery: "pho",
            isFilterFocused: true
        )

        // When
        state = Reducer.reduce(state, .key(.backspace)).state

        // Then
        #expect(state.filterQuery == "ph")
        #expect(state.visibleSimulators.map(\.name) == ["Phone"])
    }

    @Test("It should clear the filter and exit focus on Escape")
    func escapeClearsFilter() throws {
        // Given
        var state = try AppState(
            simulators: [sim(name: "Alpha"), sim(name: "Beta")],
            filterQuery: "alpha",
            isFilterFocused: true
        )

        // When
        state = Reducer.reduce(state, .key(.escape)).state

        // Then
        #expect(state.isFilterFocused == false)
        #expect(state.filterQuery.isEmpty)
        #expect(state.visibleSimulators.count == 2)
    }

    @Test("It should keep the query but exit focus on Enter")
    func enterCommitsFilter() throws {
        // Given
        var state = try AppState(
            simulators: [sim(name: "Alpha"), sim(name: "Beta")],
            filterQuery: "alp",
            isFilterFocused: true
        )

        // When
        state = Reducer.reduce(state, .key(.enter)).state

        // Then
        #expect(state.isFilterFocused == false)
        #expect(state.filterQuery == "alp")
        #expect(state.visibleSimulators.count == 1)
    }

    @Test("It should ignore arrow keys while filter input is focused")
    func arrowKeysIgnoredWhileFocused() throws {
        // Given
        let sims = try [sim(name: "Alpha"), sim(name: "Beta"), sim(name: "Gamma")]
        var state = AppState(simulators: sims, selectedIndex: 0, isFilterFocused: true)

        // When
        state = Reducer.reduce(state, .key(.down)).state

        // Then
        #expect(state.selectedIndex == 0)
        #expect(state.filterQuery.isEmpty)
    }

    @Test("It should clamp selectedIndex to the filtered list on refresh")
    func refreshClampsToFilteredCount() throws {
        // Given
        let sims = try [sim(name: "Alpha"), sim(name: "Beta")]
        var state = AppState(
            simulators: sims,
            selectedIndex: 1,
            filterQuery: "alp"
        )

        // When
        state = Reducer.reduce(state, .refreshed(sims)).state

        // Then
        #expect(state.selectedIndex == 0)
        #expect(state.visibleSimulators.count == 1)
    }
}
