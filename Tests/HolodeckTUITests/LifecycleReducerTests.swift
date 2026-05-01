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

final class LifecycleReducerTests: XCTestCase {

    private func sim(state: SimulatorState, name: String = "iPhone 16") throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: name,
            runtime: XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
            state: state,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    func testEOpensConfirmEraseWhenShutdown() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])
        let out = Reducer.reduce(state, .key(.char("e")))
        XCTAssertEqual(out.state.modal, .confirmErase(device.id))
    }

    func testEDoesNothingWhenBooted() throws {
        let device = try sim(state: .booted)
        let state = AppState(simulators: [device])
        let out = Reducer.reduce(state, .key(.char("e")))
        XCTAssertNil(out.state.modal)
    }

    func testYInConfirmEraseEmitsEffect() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device], modal: .confirmErase(device.id))
        let out = Reducer.reduce(state, .key(.char("y")))
        XCTAssertEqual(out.effects, [.eraseSimulator(device.id)])
        XCTAssertNil(out.state.modal)
        XCTAssertTrue(out.state.pendingOperations.contains(device.id))
    }

    func testNCancelsConfirmDelete() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device], modal: .confirmDelete(device.id))
        let out = Reducer.reduce(state, .key(.char("n")))
        XCTAssertNil(out.state.modal)
        XCTAssertEqual(out.effects, [])
    }

    func testDOpensConfirmDelete() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])
        let out = Reducer.reduce(state, .key(.char("d")))
        XCTAssertEqual(out.state.modal, .confirmDelete(device.id))
    }

    func testNOpensWizardAndLoadsTargets() {
        let out = Reducer.reduce(AppState(), .key(.char("n")))
        XCTAssertEqual(out.effects, [.loadTargets])
        guard case .createWizard = out.state.modal else {
            return XCTFail("expected createWizard modal")
        }
    }

    func testTargetsLoadedPopulatesWizard() throws {
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let state = AppState(modal: .createWizard(CreateWizard()))
        let out = Reducer.reduce(state, .targetsLoaded(AvailableTargets(deviceTypes: [dtype], runtimes: [runtime])))
        guard case let .createWizard(wizard) = out.state.modal else {
            return XCTFail("expected wizard modal")
        }
        XCTAssertEqual(wizard.step, .pickDeviceType)
        XCTAssertEqual(wizard.deviceTypes.count, 1)
        XCTAssertEqual(wizard.runtimes.count, 1)
    }

    func testWizardEnterAdvancesSteps() throws {
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: [dtype], runtimes: [runtime])
        let state = AppState(modal: .createWizard(wizard))
        let afterFirst = Reducer.reduce(state, .key(.enter))
        guard case let .createWizard(stepTwo) = afterFirst.state.modal else {
            return XCTFail("expected wizard")
        }
        XCTAssertEqual(stepTwo.step, .pickRuntime)
        let afterSecond = Reducer.reduce(afterFirst.state, .key(.enter))
        guard case let .createWizard(stepThree) = afterSecond.state.modal else {
            return XCTFail("expected wizard")
        }
        XCTAssertEqual(stepThree.step, .confirm)
    }

    func testWizardConfirmEmitsCreateEffect() throws {
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))
        let wizard = CreateWizard(step: .confirm, deviceTypes: [dtype], runtimes: [runtime])
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .key(.char("y")))
        XCTAssertEqual(out.effects.count, 1)
        guard case let .createSimulator(name, deviceType, pickedRuntime) = out.effects.first else {
            return XCTFail("expected createSimulator effect")
        }
        XCTAssertTrue(name.contains("iPhone"))
        XCTAssertEqual(deviceType.identifier, dtype.identifier)
        XCTAssertEqual(pickedRuntime.identifier, runtime.identifier)
    }

    func testWizardEscapeCancels() {
        let dtype = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: [dtype])
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .key(.escape))
        XCTAssertNil(out.state.modal)
    }

    func testSimulatorCreatedClosesModalAndRefreshes() {
        let wizard = CreateWizard(step: .submitting)
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .simulatorCreated(UUID(), "Test"))
        XCTAssertNil(out.state.modal)
        XCTAssertEqual(out.effects, [.refresh])
        XCTAssertTrue(out.state.statusMessage?.contains("Test") ?? false)
    }

    func testSimulatorCreateFailedReturnsToConfirmWithError() {
        let wizard = CreateWizard(step: .submitting)
        let state = AppState(modal: .createWizard(wizard))
        let out = Reducer.reduce(state, .simulatorCreateFailed("boom"))
        guard case let .createWizard(updated) = out.state.modal else {
            return XCTFail("expected wizard")
        }
        XCTAssertEqual(updated.step, .confirm)
        XCTAssertEqual(updated.error, "boom")
    }
}
