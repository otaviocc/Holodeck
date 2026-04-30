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

final class AppearanceReducerTests: XCTestCase {

    private func bootedSim() throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: "iPhone 16",
            runtime: XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "x"),
            state: .booted,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    private func shutdownSim() throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: "Off",
            runtime: XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "x"),
            state: .shutdown,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    func testAOpensAppearanceModalWhenBooted() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("a")))
        XCTAssertEqual(out.state.modal, .appearance)
        XCTAssertEqual(out.effects, [])
    }

    func testADoesNotOpenModalWhenShutdown() throws {
        let sim = try shutdownSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("a")))
        XCTAssertNil(out.state.modal)
        XCTAssertNotNil(out.state.statusMessage)
    }

    func testLInModalEmitsSetAppearanceLight() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim], modal: .appearance)
        let out = Reducer.reduce(state, .key(.char("l")))
        XCTAssertNil(out.state.modal)
        XCTAssertEqual(out.effects, [.setAppearance(sim.id, .light)])
    }

    func testDInModalEmitsSetAppearanceDark() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim], modal: .appearance)
        let out = Reducer.reduce(state, .key(.char("d")))
        XCTAssertNil(out.state.modal)
        XCTAssertEqual(out.effects, [.setAppearance(sim.id, .dark)])
    }

    func testEscapeInModalCancels() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim], modal: .appearance)
        let out = Reducer.reduce(state, .key(.escape))
        XCTAssertNil(out.state.modal)
        XCTAssertEqual(out.effects, [])
        XCTAssertFalse(out.state.isQuitting)
    }

    func testNavigationKeysSuppressedInsideModal() throws {
        let sim1 = try bootedSim()
        let sim2 = try bootedSim()
        let state = AppState(simulators: [sim1, sim2], selectedIndex: 0, modal: .appearance)
        let out = Reducer.reduce(state, .key(.down))
        XCTAssertEqual(out.state.selectedIndex, 0)
    }

    func testAppearanceChangedRefreshes() {
        let id = UUID()
        let out = Reducer.reduce(AppState(), .appearanceChanged(id, .dark))
        XCTAssertEqual(out.effects, [.refresh])
        XCTAssertTrue(out.state.statusMessage?.contains("dark") ?? false)
    }

    func testAppearanceFailedSetsError() {
        let out = Reducer.reduce(AppState(), .appearanceFailed("boom"))
        XCTAssertEqual(out.state.lastError, "boom")
    }
}
