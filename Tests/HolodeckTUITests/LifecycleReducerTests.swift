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

struct LifecycleReducerTests {

    private func sim(state: SimulatorState, name: String = "iPhone 16") throws -> Simulator {
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

    @Test("It should open the erase confirmation when e is pressed on a shut-down simulator")
    func eOpensConfirmEraseWhenShutdown() throws {
        // Given
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("e")))

        // Then
        #expect(out.state.modal == .confirmErase(device.id))
    }

    @Test("It should ignore e when the selected simulator is booted")
    func eDoesNothingWhenBooted() throws {
        // Given
        let device = try sim(state: .booted)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("e")))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should emit eraseSimulator when y confirms the erase modal")
    func yInConfirmEraseEmitsEffect() throws {
        // Given
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device], modal: .confirmErase(device.id))

        // When
        let out = Reducer.reduce(state, .key(.char("y")))

        // Then
        #expect(out.effects == [.eraseSimulator(device.id)])
        #expect(out.state.modal == nil)
        #expect(out.state.pendingOperations.contains(device.id))
    }

    @Test("It should cancel the delete modal when n is pressed")
    func nCancelsConfirmDelete() throws {
        // Given
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device], modal: .confirmDelete(device.id))

        // When
        let out = Reducer.reduce(state, .key(.char("n")))

        // Then
        #expect(out.state.modal == nil)
        #expect(out.effects == [])
    }

    @Test("It should open the delete confirmation when d is pressed")
    func dOpensConfirmDelete() throws {
        // Given
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("d")))

        // Then
        #expect(out.state.modal == .confirmDelete(device.id))
    }

    @Test("It should open the create wizard and request available targets when n is pressed")
    func nOpensWizardAndLoadsTargets() {
        // When
        let out = Reducer.reduce(AppState(), .key(.char("n")))

        // Then
        #expect(out.effects == [.loadTargets])
        guard case .createWizard = out.state.modal else {
            Issue.record("expected createWizard modal")
            return
        }
    }

    @Test("It should populate the wizard with loaded targets")
    func targetsLoadedPopulatesWizard() throws {
        // Given
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let state = AppState(modal: .createWizard(CreateWizard()))

        // When
        let out = Reducer.reduce(state, .targetsLoaded(AvailableTargets(deviceTypes: [dtype], runtimes: [runtime])))

        // Then
        guard case let .createWizard(wizard) = out.state.modal else {
            Issue.record("expected wizard modal")
            return
        }
        #expect(wizard.step == .pickDeviceType)
        #expect(wizard.deviceTypes.count == 1)
        #expect(wizard.runtimes.count == 1)
    }

    @Test("It should advance the wizard one step at a time on Enter")
    func wizardEnterAdvancesSteps() throws {
        // Given
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: [dtype], runtimes: [runtime])
        let state = AppState(modal: .createWizard(wizard))

        // When
        let afterFirst = Reducer.reduce(state, .key(.enter))
        let afterSecond = Reducer.reduce(afterFirst.state, .key(.enter))

        // Then
        guard case let .createWizard(stepTwo) = afterFirst.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(stepTwo.step == .pickRuntime)
        guard case let .createWizard(stepThree) = afterSecond.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(stepThree.step == .confirm)
    }

    @Test("It should emit createSimulator when the wizard is confirmed")
    func wizardConfirmEmitsCreateEffect() throws {
        // Given
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let wizard = CreateWizard(step: .confirm, deviceTypes: [dtype], runtimes: [runtime])
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.char("y")))

        // Then
        #expect(out.effects.count == 1)
        guard case let .createSimulator(name, deviceType, pickedRuntime) = out.effects.first else {
            Issue.record("expected createSimulator effect")
            return
        }
        #expect(name.contains("iPhone"))
        #expect(deviceType.identifier == dtype.identifier)
        #expect(pickedRuntime.identifier == runtime.identifier)
    }

    @Test("It should cancel the wizard on Escape")
    func wizardEscapeCancels() {
        // Given
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: [dtype])
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.escape))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should close the wizard and refresh after a simulator is created")
    func simulatorCreatedClosesModalAndRefreshes() {
        // Given
        let wizard = CreateWizard(step: .submitting)
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .simulatorCreated(UUID(), "Test"))

        // Then
        #expect(out.state.modal == nil)
        #expect(out.effects == [.refresh])
        #expect(out.state.statusMessage?.contains("Test") ?? false)
    }

    @Test("It should return to the confirm step with an error if create fails")
    func simulatorCreateFailedReturnsToConfirmWithError() {
        // Given
        let wizard = CreateWizard(step: .submitting)
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .simulatorCreateFailed("boom"))

        // Then
        guard case let .createWizard(updated) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(updated.step == .confirm)
        #expect(updated.error == "boom")
    }

    @Test("It should scroll the device-type column down when the highlight crosses the edge")
    func createWizardDeviceTypeScrollsAtEdge() {
        // Given
        let dtypes = (0..<30).map {
            DeviceType(identifier: "com.example.Device\($0)", name: "Device \($0)")
        }
        let viewport = CreateWizard.viewport(rows: 13)
        var wizard = CreateWizard(step: .pickDeviceType, deviceTypes: dtypes)
        wizard.deviceTypeIndex = viewport - 1
        let state = AppState(rows: 13, modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.down))

        // Then
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.deviceTypeIndex == viewport)
        #expect(after.deviceTypeScrollOffset == 1)
    }

    @Test("It should scroll the runtime column down when the highlight crosses the edge")
    func createWizardRuntimeScrollsAtEdge() throws {
        // Given
        let runtimes = try (0..<25).map { index throws -> Runtime in
            try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-\(index)-0"))
        }
        let viewport = CreateWizard.viewport(rows: 13)
        var wizard = CreateWizard(step: .pickRuntime, runtimes: runtimes)
        wizard.runtimeIndex = viewport - 1
        let state = AppState(rows: 13, modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.down))

        // Then
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.runtimeIndex == viewport)
        #expect(after.runtimeScrollOffset == 1)
    }
}
