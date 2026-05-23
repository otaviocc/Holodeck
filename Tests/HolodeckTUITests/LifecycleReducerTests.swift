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

// swiftlint:disable file_length type_body_length
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
        #expect(out.state.pendingOperations[device.id] == .erase)
    }

    @Test("It should refuse to overwrite an in-flight pending op when y confirms erase")
    func yInConfirmEraseRefusesOverwrite() throws {
        // Given — a boot is already in flight for the same sim
        let device = try sim(state: .shutdown)
        let state = AppState(
            simulators: [device],
            pendingOperations: [device.id: .boot],
            modal: .confirmErase(device.id)
        )

        // When
        let out = Reducer.reduce(state, .key(.char("y")))

        // Then — the existing .boot intent must not be clobbered to .erase,
        // and no .eraseSimulator effect is emitted.
        #expect(out.effects.isEmpty)
        #expect(out.state.pendingOperations[device.id] == .boot)
        #expect(out.state.modal == nil)
        #expect(out.state.statusMessage?.contains("pending operation") == true)
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

    @Test("It should focus the filter on `/` from pickDeviceType")
    func createWizardFilterFocusesOnSlash() {
        // Given
        let dtypes = [
            DeviceType(identifier: "iphone-16", name: "iPhone 16"),
            DeviceType(identifier: "ipad-pro", name: "iPad Pro")
        ]
        let wizard = CreateWizard(step: .pickDeviceType, deviceTypes: dtypes, deviceTypeIndex: 1)
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.char("/")))

        // Then
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.isDeviceTypeFilterFocused == true)
        #expect(after.deviceTypeFilter.isEmpty)
        #expect(after.deviceTypeIndex == 0)
        #expect(after.deviceTypeScrollOffset == 0)
    }

    @Test("It should narrow the visible device types as the user types into the filter")
    func createWizardFilterAppendsAndNarrows() {
        // Given
        let dtypes = [
            DeviceType(identifier: "iphone-16", name: "iPhone 16"),
            DeviceType(identifier: "ipad-pro", name: "iPad Pro"),
            DeviceType(identifier: "appletv-4k", name: "Apple TV 4K")
        ]
        var wizard = CreateWizard(step: .pickDeviceType, deviceTypes: dtypes)
        wizard.isDeviceTypeFilterFocused = true
        let state = AppState(modal: .createWizard(wizard))

        // When — type "pad"
        var current = state
        for character in "pad" {
            current = Reducer.reduce(current, .key(.char(character))).state
        }

        // Then
        guard case let .createWizard(after) = current.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.deviceTypeFilter == "pad")
        #expect(after.visibleDeviceTypes.map(\.name) == ["iPad Pro"])
        #expect(after.deviceTypeIndex == 0)
    }

    @Test("It should drop the last character on backspace while the filter is focused")
    func createWizardFilterBackspace() {
        // Given
        var wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: [],
            deviceTypeFilter: "ipad",
            isDeviceTypeFilterFocused: true
        )
        wizard.isDeviceTypeFilterFocused = true
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.backspace))

        // Then
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.deviceTypeFilter == "ipa")
    }

    @Test("It should clear the filter and defocus on Esc instead of closing the wizard")
    func createWizardFilterEscapeClears() {
        // Given
        let dtypes = [DeviceType(identifier: "iphone-16", name: "iPhone 16")]
        let wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "ipad",
            isDeviceTypeFilterFocused: true
        )
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.escape))

        // Then — wizard stays open, filter is cleared
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard to stay open")
            return
        }
        #expect(after.deviceTypeFilter.isEmpty)
        #expect(after.isDeviceTypeFilterFocused == false)
    }

    @Test("It should defocus the filter on Enter without advancing to pickRuntime")
    func createWizardFilterEnterDefocuses() {
        // Given
        let dtypes = [DeviceType(identifier: "iphone-16", name: "iPhone 16")]
        let wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "iphone",
            isDeviceTypeFilterFocused: true
        )
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then — filter defocused, step unchanged, query preserved
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.isDeviceTypeFilterFocused == false)
        #expect(after.deviceTypeFilter == "iphone")
        #expect(after.step == .pickDeviceType)
    }

    @Test("It should advance to pickRuntime against the visible device type when Enter is pressed after filtering")
    func createWizardFilterPicksFromVisibleList() {
        // Given — three device types, filter narrows to one match
        let dtypes = [
            DeviceType(identifier: "iphone-16", name: "iPhone 16"),
            DeviceType(identifier: "ipad-pro", name: "iPad Pro"),
            DeviceType(identifier: "appletv-4k", name: "Apple TV 4K")
        ]
        let wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "pad",
            isDeviceTypeFilterFocused: false
        )
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then — moved to pickRuntime with iPad Pro selected (proves selectedDeviceType indexes into the filtered list)
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.step == .pickRuntime)
        #expect(after.selectedDeviceType?.name == "iPad Pro")
    }

    @Test("It should refuse to advance from pickDeviceType when the filter matches nothing")
    func createWizardFilterEmptyMatchBlocksAdvance() {
        // Given
        let dtypes = [DeviceType(identifier: "iphone-16", name: "iPhone 16")]
        let wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "zzz",
            isDeviceTypeFilterFocused: false
        )
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then — wizard stays on pickDeviceType (selectedDeviceType is nil)
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.step == .pickDeviceType)
    }

    @Test("It should scroll the device-type column accounting for the filter banner row")
    func createWizardDeviceTypeScrollsWithFilterBanner() {
        // Given — banner steals one row from the viewport. The reducer's
        // scroll math must use the reduced viewport so the selected row
        // never sits just past the visible window.
        let dtypes = (0..<30).map {
            DeviceType(identifier: "com.example.Device\($0)", name: "Device \($0)")
        }
        let viewport = CreateWizard.viewport(rows: 13)
        var wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "Device",
            isDeviceTypeFilterFocused: false
        )
        // One row earlier than the unfilter-banner edge (viewport - 1 - 1).
        wizard.deviceTypeIndex = viewport - 2
        let state = AppState(rows: 13, modal: .createWizard(wizard))

        // When — one more ↓ should already trigger a scroll, because the
        // banner shrinks the visible list by one row.
        let out = Reducer.reduce(state, .key(.down))

        // Then
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.deviceTypeIndex == viewport - 1)
        #expect(after.deviceTypeScrollOffset == 1)
    }

    @Test("It should clear the filter on Esc even when the input is not focused")
    func createWizardEscClearsLiveFilterWhenDefocused() {
        // Given — user typed a query then defocused with Enter; filter survives.
        let dtypes = [DeviceType(identifier: "iphone-16", name: "iPhone 16")]
        let wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "iphone",
            isDeviceTypeFilterFocused: false
        )
        let state = AppState(modal: .createWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.escape))

        // Then — wizard stays open, filter is cleared.
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard to stay open")
            return
        }
        #expect(after.deviceTypeFilter.isEmpty)
        #expect(after.isDeviceTypeFilterFocused == false)
    }

    @Test("It should preserve the existing filter when `/` re-focuses the input")
    func createWizardSlashPreservesExistingFilter() {
        // Given — filter previously typed, defocused via Enter.
        let dtypes = [DeviceType(identifier: "ipad-pro", name: "iPad Pro")]
        let wizard = CreateWizard(
            step: .pickDeviceType,
            deviceTypes: dtypes,
            deviceTypeFilter: "pad",
            isDeviceTypeFilterFocused: false
        )
        let state = AppState(modal: .createWizard(wizard))

        // When — re-press `/` to keep editing.
        let out = Reducer.reduce(state, .key(.char("/")))

        // Then — focus restored, existing query preserved.
        guard case let .createWizard(after) = out.state.modal else {
            Issue.record("expected wizard")
            return
        }
        #expect(after.isDeviceTypeFilterFocused == true)
        #expect(after.deviceTypeFilter == "pad")
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

// swiftlint:enable file_length type_body_length
