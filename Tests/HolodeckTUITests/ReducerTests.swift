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

struct ReducerTests {

    private func makeSim(name: String, state: SimulatorState, version: Int = 18) -> Simulator {
        Simulator(
            id: UUID(),
            name: name,
            runtime: Runtime(
                platform: .iOS,
                version: SemanticVersion(major: version, minor: 2),
                identifier: "com.apple.CoreSimulator.SimRuntime.iOS-\(version)-2"
            ),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
            state: state,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    @Test("It should clamp navigation to the simulator list bounds")
    func navigationClampsToBounds() {
        // Given
        var state = AppState(simulators: [
            makeSim(name: "A", state: .shutdown),
            makeSim(name: "B", state: .shutdown)
        ])

        // When
        state = Reducer.reduce(state, .key(.up)).state
        let afterUp = state.selectedIndex
        state = Reducer.reduce(state, .key(.down)).state
        let afterDown = state.selectedIndex
        state = Reducer.reduce(state, .key(.down)).state
        let afterClamp = state.selectedIndex

        // Then
        #expect(afterUp == 0)
        #expect(afterDown == 1)
        #expect(afterClamp == 1)
    }

    @Test("It should scroll the simulator window down when the highlight crosses the edge")
    func mainListScrollsDownAtEdge() {
        // Given
        let sims = (0..<30).map { makeSim(name: "Sim\($0)", state: .shutdown) }
        let rows = 13
        let viewport = AppState.mainListViewport(rows: rows, isRecording: false, hasModal: false)
        var state = AppState(
            simulators: AppState.sort(sims),
            selectedIndex: viewport - 1,
            mainScrollOffset: 0,
            rows: rows
        )

        // When
        state = Reducer.reduce(state, .key(.down)).state

        // Then
        #expect(state.selectedIndex == viewport)
        #expect(state.mainScrollOffset == 1)
    }

    @Test("It should scroll the simulator window up when the highlight crosses the top edge")
    func mainListScrollsUpAtEdge() {
        // Given
        let sims = (0..<30).map { makeSim(name: "Sim\($0)", state: .shutdown) }
        var state = AppState(
            simulators: AppState.sort(sims),
            selectedIndex: 5,
            mainScrollOffset: 5,
            rows: 13
        )

        // When
        state = Reducer.reduce(state, .key(.up)).state

        // Then
        #expect(state.selectedIndex == 4)
        #expect(state.mainScrollOffset == 4)
    }

    @Test("It should clamp the scroll offset when the simulator list shrinks")
    func mainListScrollClampsOnRefresh() {
        // Given
        let many = (0..<30).map { makeSim(name: "Sim\($0)", state: .shutdown) }
        var state = AppState(
            simulators: AppState.sort(many),
            selectedIndex: 0,
            mainScrollOffset: 20,
            rows: 13
        )
        let few = (0..<5).map { makeSim(name: "Tiny\($0)", state: .shutdown) }

        // When
        state = Reducer.reduce(state, .refreshed(few)).state

        // Then
        #expect(state.mainScrollOffset == 0)
    }

    @Test("It should clamp the scroll offset on resize")
    func mainListScrollClampsOnResize() {
        // Given
        let sims = (0..<30).map { makeSim(name: "Sim\($0)", state: .shutdown) }
        var state = AppState(
            simulators: AppState.sort(sims),
            selectedIndex: 0,
            mainScrollOffset: 25,
            rows: 13
        )

        // When (resize so viewport is huge → scroll offset should snap back)
        state = Reducer.reduce(state, .resized(rows: 40, cols: 80)).state

        // Then
        let viewport = AppState.mainListViewport(rows: 40, isRecording: false, hasModal: false)
        #expect(state.mainScrollOffset <= max(0, sims.count - viewport))
    }

    @Test("It should set the quitting flag when q is pressed")
    func quitSetsFlag() {
        // Given
        var state = AppState()

        // When
        state = Reducer.reduce(state, .key(.char("q"))).state

        // Then
        #expect(state.isQuitting)
    }

    @Test("It should emit a boot effect when Enter hits a shutdown simulator")
    func enterOnShutdownEmitsBoot() {
        // Given
        let sim = makeSim(name: "A", state: .shutdown)
        let state = AppState(simulators: [sim])

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then
        #expect(out.effects == [.boot(sim.id)])
        #expect(out.state.pendingOperations.contains(sim.id))
    }

    @Test("It should emit a shutdown effect when Enter hits a booted simulator")
    func enterOnBootedEmitsShutdown() {
        // Given
        let sim = makeSim(name: "A", state: .booted)
        let state = AppState(simulators: [sim])

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then
        #expect(out.effects == [.shutdown(sim.id)])
    }

    @Test("It should ignore Enter while an operation is pending")
    func enterIgnoredWhilePending() {
        // Given
        let sim = makeSim(name: "A", state: .shutdown)
        let state = AppState(simulators: [sim], pendingOperations: [sim.id])

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then
        #expect(out.effects == [])
    }

    @Test("It should trigger a refresh after an operation completes")
    func operationCompletedTriggersRefresh() {
        // Given
        let id = UUID()
        let state = AppState(pendingOperations: [id])

        // When
        let out = Reducer.reduce(state, .operationCompleted(id))

        // Then
        #expect(!out.state.pendingOperations.contains(id))
        #expect(out.effects == [.refresh])
    }

    @Test("It should clamp the selection when the refreshed list shrinks")
    func refreshedClampsSelection() {
        // Given
        var state = AppState(simulators: [
            makeSim(name: "A", state: .shutdown),
            makeSim(name: "B", state: .shutdown),
            makeSim(name: "C", state: .shutdown)
        ], selectedIndex: 2)

        // When
        state = Reducer.reduce(state, .refreshed([makeSim(name: "Z", state: .shutdown)])).state

        // Then
        #expect(state.selectedIndex == 0)
    }
}
