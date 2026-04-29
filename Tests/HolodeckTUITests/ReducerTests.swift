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

import HolodeckCore
import XCTest
@testable import HolodeckTUI

final class ReducerTests: XCTestCase {

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

    func testNavigationClampsToBounds() {
        var state = AppState(simulators: [
            makeSim(name: "A", state: .shutdown),
            makeSim(name: "B", state: .shutdown)
        ])
        state = Reducer.reduce(state, .key(.up)).state
        XCTAssertEqual(state.selectedIndex, 0)
        state = Reducer.reduce(state, .key(.down)).state
        XCTAssertEqual(state.selectedIndex, 1)
        state = Reducer.reduce(state, .key(.down)).state
        XCTAssertEqual(state.selectedIndex, 1)
    }

    func testQuitSetsFlag() {
        var state = AppState()
        state = Reducer.reduce(state, .key(.char("q"))).state
        XCTAssertTrue(state.isQuitting)
    }

    func testEnterOnShutdownEmitsBoot() {
        let sim = makeSim(name: "A", state: .shutdown)
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.enter))
        XCTAssertEqual(out.effects, [.boot(sim.id)])
        XCTAssertTrue(out.state.pendingOperations.contains(sim.id))
    }

    func testEnterOnBootedEmitsShutdown() {
        let sim = makeSim(name: "A", state: .booted)
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.enter))
        XCTAssertEqual(out.effects, [.shutdown(sim.id)])
    }

    func testEnterIgnoredWhilePending() {
        let sim = makeSim(name: "A", state: .shutdown)
        let state = AppState(simulators: [sim], pendingOperations: [sim.id])
        let out = Reducer.reduce(state, .key(.enter))
        XCTAssertEqual(out.effects, [])
    }

    func testOperationCompletedTriggersRefresh() {
        let id = UUID()
        let state = AppState(pendingOperations: [id])
        let out = Reducer.reduce(state, .operationCompleted(id))
        XCTAssertFalse(out.state.pendingOperations.contains(id))
        XCTAssertEqual(out.effects, [.refresh])
    }

    func testRefreshedClampsSelection() {
        var state = AppState(simulators: [
            makeSim(name: "A", state: .shutdown),
            makeSim(name: "B", state: .shutdown),
            makeSim(name: "C", state: .shutdown)
        ], selectedIndex: 2)
        state = Reducer.reduce(state, .refreshed([makeSim(name: "Z", state: .shutdown)])).state
        XCTAssertEqual(state.selectedIndex, 0)
    }
}
