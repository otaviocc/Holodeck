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

struct AppearanceReducerTests {

    private func bootedSim() throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: "iPhone 16",
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
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
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "x"),
            state: .shutdown,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    @Test("It should open the appearance modal when a is pressed on a booted simulator")
    func aOpensAppearanceModalWhenBooted() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("a")))
        #expect(out.state.modal == .appearance)
        #expect(out.effects == [])
    }

    @Test("It should not open the appearance modal on a shut-down simulator")
    func aDoesNotOpenModalWhenShutdown() throws {
        let sim = try shutdownSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("a")))
        #expect(out.state.modal == nil)
        #expect(out.state.statusMessage != nil)
    }

    @Test("It should emit setAppearance(.light) when l is pressed in the appearance modal")
    func lInModalEmitsSetAppearanceLight() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim], modal: .appearance)
        let out = Reducer.reduce(state, .key(.char("l")))
        #expect(out.state.modal == nil)
        #expect(out.effects == [.setAppearance(sim.id, .light)])
    }

    @Test("It should emit setAppearance(.dark) when d is pressed in the appearance modal")
    func dInModalEmitsSetAppearanceDark() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim], modal: .appearance)
        let out = Reducer.reduce(state, .key(.char("d")))
        #expect(out.state.modal == nil)
        #expect(out.effects == [.setAppearance(sim.id, .dark)])
    }

    @Test("It should cancel the appearance modal on Escape without emitting effects")
    func escapeInModalCancels() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim], modal: .appearance)
        let out = Reducer.reduce(state, .key(.escape))
        #expect(out.state.modal == nil)
        #expect(out.effects == [])
        #expect(!out.state.isQuitting)
    }

    @Test("It should ignore navigation keys while the appearance modal is open")
    func navigationKeysSuppressedInsideModal() throws {
        let sim1 = try bootedSim()
        let sim2 = try bootedSim()
        let state = AppState(simulators: [sim1, sim2], selectedIndex: 0, modal: .appearance)
        let out = Reducer.reduce(state, .key(.down))
        #expect(out.state.selectedIndex == 0)
    }

    @Test("It should refresh and surface a status message when appearance changes")
    func appearanceChangedRefreshes() {
        let id = UUID()
        let out = Reducer.reduce(AppState(), .appearanceChanged(id, .dark))
        #expect(out.effects == [.refresh])
        #expect(out.state.statusMessage?.contains("dark") ?? false)
    }

    @Test("It should record an error when the appearance change fails")
    func appearanceFailedSetsError() {
        let out = Reducer.reduce(AppState(), .appearanceFailed("boom"))
        #expect(out.state.lastError == "boom")
    }
}
