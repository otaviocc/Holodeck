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

struct SimulatorListViewBannersTests {

    private func booted(name: String = "iPhone 16") throws -> Simulator {
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

    @Test("It should show the appearance modal banner when modal is .appearance")
    func appearanceModalBanner() throws {
        // Given
        let state = try AppState(simulators: [booted()], rows: 12, cols: 80, modal: .appearance)

        // When
        let plain = SimulatorListView.stripANSI(SimulatorListView.render(state))

        // Then
        #expect(plain.contains("Appearance:"))
        #expect(plain.contains("l = light"))
        #expect(plain.contains("d = dark"))
    }

    @Test("It should show the recording banner with the device name and path")
    func recordingBanner() throws {
        // Given
        let sim = try booted()
        let state = AppState(
            simulators: [sim],
            rows: 12,
            cols: 120,
            recordingDeviceID: sim.id,
            recordingPath: URL(fileURLWithPath: "/tmp/clip.mp4")
        )

        // When
        let plain = SimulatorListView.stripANSI(SimulatorListView.render(state))

        // Then
        #expect(plain.contains("REC"))
        #expect(plain.contains(sim.name))
        #expect(plain.contains("clip.mp4"))
    }

    @Test("It should show the confirmErase banner with the simulator name")
    func confirmEraseBanner() throws {
        // Given
        let sim = try booted(name: "TargetSim")
        let state = AppState(simulators: [sim], rows: 12, cols: 80, modal: .confirmErase(sim.id))

        // When
        let plain = SimulatorListView.stripANSI(SimulatorListView.render(state))

        // Then
        #expect(plain.contains("Erase TargetSim"))
        #expect(plain.contains("y = confirm"))
    }

    @Test("It should show the confirmDelete banner with the simulator name")
    func confirmDeleteBanner() throws {
        // Given
        let sim = try booted(name: "Doomed")
        let state = AppState(simulators: [sim], rows: 12, cols: 80, modal: .confirmDelete(sim.id))

        // When
        let plain = SimulatorListView.stripANSI(SimulatorListView.render(state))

        // Then
        #expect(plain.contains("Delete Doomed"))
    }

    @Test("It should render each wizard step with its own prompt")
    func wizardStepBanners() throws {
        // Given
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        func render(_ step: CreateWizard.Step) -> String {
            let wizard = CreateWizard(step: step, deviceTypes: [dtype], runtimes: [runtime])
            let state = AppState(rows: 12, cols: 120, modal: .createWizard(wizard))
            return SimulatorListView.stripANSI(SimulatorListView.render(state))
        }

        // Then
        #expect(render(.loading).contains("loading"))
        #expect(render(.pickDeviceType).contains("device type"))
        #expect(render(.pickRuntime).contains("runtime"))
        #expect(render(.confirm).contains("confirm"))
        #expect(render(.submitting).contains("Creating"))
    }

    @Test("It should surface the last error in the status bar in place of selection info")
    func statusBarShowsLastError() throws {
        // Given
        let sim = try booted()
        var state = AppState(simulators: [sim], rows: 12, cols: 80)
        state.lastError = "boom"

        // When
        let plain = SimulatorListView.stripANSI(SimulatorListView.render(state))

        // Then
        #expect(plain.contains("boom"))
    }

    @Test("It should mark a row as pending when an operation is in flight")
    func pendingRowMarker() throws {
        // Given
        let sim = try booted()
        let state = AppState(simulators: [sim], pendingOperations: [sim.id], rows: 12, cols: 120)

        // When
        let plain = SimulatorListView.stripANSI(SimulatorListView.render(state))

        // Then
        #expect(plain.contains("[pending]"))
    }
}
