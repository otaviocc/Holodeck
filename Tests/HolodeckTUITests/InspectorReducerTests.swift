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

struct InspectorReducerTests {

    private func sim(name: String = "iPhone 16") throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: name,
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
            state: .booted,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    @Test("It should open the inspector when i is pressed with a selected simulator")
    func iOpensInspector() throws {
        // Given
        let device = try sim()
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("i")))

        // Then
        guard case let .inspector(udid) = out.state.modal else {
            Issue.record("Expected inspector modal")
            return
        }
        #expect(udid == device.id)
    }

    @Test("It should dismiss the inspector on any key")
    func anyKeyDismisses() throws {
        // Given
        let device = try sim()
        let state = AppState(simulators: [device], modal: .inspector(device.id))

        // When
        let out = Reducer.reduce(state, .key(.char("i")))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should auto-close the inspector on refresh when the device disappears")
    func refreshAutoClosesWhenSimGone() throws {
        // Given
        let device = try sim()
        let other = try sim(name: "iPhone 15")
        let state = AppState(simulators: [device, other], modal: .inspector(device.id))

        // When (refresh returns only the other sim)
        let out = Reducer.reduce(state, .refreshed([other]))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should keep the inspector open on refresh when the device still exists")
    func refreshKeepsInspectorWhenSimPresent() throws {
        // Given
        let device = try sim()
        let state = AppState(simulators: [device], modal: .inspector(device.id))

        // When
        let out = Reducer.reduce(state, .refreshed([device]))

        // Then
        guard case let .inspector(udid) = out.state.modal else {
            Issue.record("Expected inspector to remain open")
            return
        }
        #expect(udid == device.id)
    }
}
