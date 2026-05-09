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
        var state = AppState(simulators: [
            makeSim(name: "A", state: .shutdown),
            makeSim(name: "B", state: .shutdown)
        ])
        state = Reducer.reduce(state, .key(.up)).state
        #expect(state.selectedIndex == 0)
        state = Reducer.reduce(state, .key(.down)).state
        #expect(state.selectedIndex == 1)
        state = Reducer.reduce(state, .key(.down)).state
        #expect(state.selectedIndex == 1)
    }

    @Test("It should set the quitting flag when q is pressed")
    func quitSetsFlag() {
        var state = AppState()
        state = Reducer.reduce(state, .key(.char("q"))).state
        #expect(state.isQuitting)
    }

    @Test("It should emit a boot effect when Enter hits a shutdown simulator")
    func enterOnShutdownEmitsBoot() {
        let sim = makeSim(name: "A", state: .shutdown)
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.enter))
        #expect(out.effects == [.boot(sim.id)])
        #expect(out.state.pendingOperations.contains(sim.id))
    }

    @Test("It should emit a shutdown effect when Enter hits a booted simulator")
    func enterOnBootedEmitsShutdown() {
        let sim = makeSim(name: "A", state: .booted)
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.enter))
        #expect(out.effects == [.shutdown(sim.id)])
    }

    @Test("It should ignore Enter while an operation is pending")
    func enterIgnoredWhilePending() {
        let sim = makeSim(name: "A", state: .shutdown)
        let state = AppState(simulators: [sim], pendingOperations: [sim.id])
        let out = Reducer.reduce(state, .key(.enter))
        #expect(out.effects == [])
    }

    @Test("It should trigger a refresh after an operation completes")
    func operationCompletedTriggersRefresh() {
        let id = UUID()
        let state = AppState(pendingOperations: [id])
        let out = Reducer.reduce(state, .operationCompleted(id))
        #expect(!out.state.pendingOperations.contains(id))
        #expect(out.effects == [.refresh])
    }

    @Test("It should clamp the selection when the refreshed list shrinks")
    func refreshedClampsSelection() {
        var state = AppState(simulators: [
            makeSim(name: "A", state: .shutdown),
            makeSim(name: "B", state: .shutdown),
            makeSim(name: "C", state: .shutdown)
        ], selectedIndex: 2)
        state = Reducer.reduce(state, .refreshed([makeSim(name: "Z", state: .shutdown)])).state
        #expect(state.selectedIndex == 0)
    }
}
