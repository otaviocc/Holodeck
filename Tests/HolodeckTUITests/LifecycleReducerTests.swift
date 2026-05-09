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
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])
        let out = Reducer.reduce(state, .key(.char("e")))
        #expect(out.state.modal == .confirmErase(device.id))
    }

    @Test("It should ignore e when the selected simulator is booted")
    func eDoesNothingWhenBooted() throws {
        let device = try sim(state: .booted)
        let state = AppState(simulators: [device])
        let out = Reducer.reduce(state, .key(.char("e")))
        #expect(out.state.modal == nil)
    }

    @Test("It should emit eraseSimulator when y confirms the erase modal")
    func yInConfirmEraseEmitsEffect() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device], modal: .confirmErase(device.id))
        let out = Reducer.reduce(state, .key(.char("y")))
        #expect(out.effects == [.eraseSimulator(device.id)])
        #expect(out.state.modal == nil)
        #expect(out.state.pendingOperations.contains(device.id))
    }

    @Test("It should cancel the delete modal when n is pressed")
    func nCancelsConfirmDelete() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device], modal: .confirmDelete(device.id))
        let out = Reducer.reduce(state, .key(.char("n")))
        #expect(out.state.modal == nil)
        #expect(out.effects == [])
    }

    @Test("It should open the delete confirmation when d is pressed")
    func dOpensConfirmDelete() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])
        let out = Reducer.reduce(state, .key(.char("d")))
        #expect(out.state.modal == .confirmDelete(device.id))
    }

    @Test("It should open the create wizard and request available targets when n is pressed")
    func nOpensWizardAndLoadsTargets() {
        let out = Reducer.reduce(AppState(), .key(.char("n")))
        #expect(out.effects == [.loadTargets])
        guard case .createWizard = out.state.modal else {
            Issue.record("expected createWizard modal")
            return
        }
    }

    @Test("It should populate the wizard with loaded targets")
    func targetsLoadedPopulatesWizard() throws {
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let state = AppState(modal: .createWizard(CreateWizard()))
        let out = Reducer.reduce(state, .targetsLoaded(AvailableTargets(deviceTypes: [dtype], runtimes: [runtime])))
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
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: [dtype], runtimes: [runtime])
        let state = AppState(modal: .createWizard(wizard))
        let afterFirst = Reducer.reduce(state, .key(.enter))
        guard case let .createWizard(stepTwo) = afterFirst.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(stepTwo.step == .pickRuntime)
        let afterSecond = Reducer.reduce(afterFirst.state, .key(.enter))
        guard case let .createWizard(stepThree) = afterSecond.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(stepThree.step == .confirm)
    }

    @Test("It should emit createSimulator when the wizard is confirmed")
    func wizardConfirmEmitsCreateEffect() throws {
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let wizard = CreateWizard(step: .confirm, deviceTypes: [dtype], runtimes: [runtime])
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .key(.char("y")))
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
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: [dtype])
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .key(.escape))
        #expect(out.state.modal == nil)
    }

    @Test("It should close the wizard and refresh after a simulator is created")
    func simulatorCreatedClosesModalAndRefreshes() {
        let wizard = CreateWizard(step: .submitting)
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .simulatorCreated(UUID(), "Test"))
        #expect(out.state.modal == nil)
        #expect(out.effects == [.refresh])
        #expect(out.state.statusMessage?.contains("Test") ?? false)
    }

    @Test("It should return to the confirm step with an error if create fails")
    func simulatorCreateFailedReturnsToConfirmWithError() {
        let wizard = CreateWizard(step: .submitting)
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .simulatorCreateFailed("boom"))
        guard case let .createWizard(updated) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(updated.step == .confirm)
        #expect(updated.error == "boom")
    }
}
