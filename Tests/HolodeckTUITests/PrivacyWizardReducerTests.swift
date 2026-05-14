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

struct PrivacyWizardReducerTests {

    private func sim(state: SimulatorState) throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: "iPhone 16",
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
            state: state,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    private let sampleApps: [InstalledApp] = [
        InstalledApp(bundleID: "com.example.App1", name: "App One", isUserApp: true),
        InstalledApp(bundleID: "com.example.App2", name: "App Two", isUserApp: true),
        InstalledApp(bundleID: "com.apple.SystemThing", name: "System Thing", isUserApp: false)
    ]

    @Test("It should open the privacy wizard when P is pressed on a booted simulator")
    func opensOnBooted() throws {
        // Given
        let device = try sim(state: .booted)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("P")))

        // Then
        guard case let .privacyWizard(wizard) = out.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(wizard.simulatorID == device.id)
        #expect(wizard.step == .loadingApps)
        #expect(out.effects == [.loadInstalledApps(device.id)])
    }

    @Test("It should refuse to open the wizard when the selected simulator is shut down")
    func refusesOnShutdown() throws {
        // Given
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("P")))

        // Then
        #expect(out.state.modal == nil)
        #expect(out.effects.isEmpty)
    }

    @Test("It should advance to pickApp once apps load")
    func advancesOnAppsLoaded() throws {
        // Given
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            modal: .privacyWizard(PrivacyWizard(simulatorID: device.id))
        )

        // When
        let out = Reducer.reduce(state, .appsLoaded(sampleApps))

        // Then
        guard case let .privacyWizard(wizard) = out.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(wizard.step == .pickApp)
        #expect(wizard.allApps == sampleApps)
    }

    @Test("It should default the picker to user apps only")
    func defaultFilterIsUserOnly() {
        // Given
        let wizard = PrivacyWizard(simulatorID: UUID(), allApps: sampleApps)

        // Then
        #expect(wizard.apps.count == 2)
        // swiftformat:disable:next preferKeyPath
        #expect(wizard.apps.allSatisfy { $0.isUserApp })
    }

    @Test("It should toggle system apps with s and reset the index")
    func toggleSystemApps() throws {
        // Given
        let device = try sim(state: .booted)
        var wizard = PrivacyWizard(simulatorID: device.id, step: .pickApp, allApps: sampleApps)
        wizard.appIndex = 1
        let state = AppState(simulators: [device], modal: .privacyWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.char("s")))

        // Then
        guard case let .privacyWizard(after) = out.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(after.showSystem == true)
        #expect(after.appIndex == 0)
        #expect(after.apps.count == sampleApps.count)
    }

    @Test("It should clamp navigation on pickApp")
    func clampsNavigation() throws {
        // Given
        let device = try sim(state: .booted)
        let wizard = PrivacyWizard(simulatorID: device.id, step: .pickApp, allApps: sampleApps)
        let state = AppState(simulators: [device], modal: .privacyWizard(wizard))

        // When (already at top)
        let upOut = Reducer.reduce(state, .key(.up))

        // Then
        guard case let .privacyWizard(afterUp) = upOut.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(afterUp.appIndex == 0)

        // When (advance past end)
        var deepWizard = wizard
        deepWizard.appIndex = wizard.apps.count - 1
        let bottomState = AppState(simulators: [device], modal: .privacyWizard(deepWizard))
        let downOut = Reducer.reduce(bottomState, .key(.down))

        // Then
        guard case let .privacyWizard(afterDown) = downOut.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(afterDown.appIndex == wizard.apps.count - 1)
    }

    @Test("It should walk back from pickPermission via b")
    func backStepsThroughStages() throws {
        // Given
        let device = try sim(state: .booted)
        var wizard = PrivacyWizard(simulatorID: device.id, step: .pickPermission, allApps: sampleApps)
        wizard.error = "boom"
        let state = AppState(simulators: [device], modal: .privacyWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.char("b")))

        // Then
        guard case let .privacyWizard(after) = out.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(after.step == .pickAction)
        #expect(after.error == nil)
    }

    @Test("It should emit applyPrivacy when permission picker confirms")
    func confirmEmitsApplyPrivacy() throws {
        // Given
        let device = try sim(state: .booted)
        var wizard = PrivacyWizard(simulatorID: device.id, step: .pickPermission, allApps: sampleApps)
        wizard.appIndex = 0
        wizard.actionIndex = 0
        wizard.permissionIndex = 0
        let state = AppState(simulators: [device], modal: .privacyWizard(wizard))

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then
        let expectedApp = wizard.apps[0]
        let expectedAction = PrivacyAction.allCases[0]
        let expectedPermission = PrivacyPermission.allCases[0]
        #expect(out.effects == [
            .applyPrivacy(
                udid: device.id,
                action: expectedAction,
                permission: expectedPermission,
                bundleID: expectedApp.bundleID
            )
        ])
        guard case let .privacyWizard(after) = out.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(after.step == .submitting)
    }

    @Test("It should close the modal and set a status message on success")
    func successClearsModal() throws {
        // Given
        let device = try sim(state: .booted)
        let wizard = PrivacyWizard(simulatorID: device.id, step: .submitting, allApps: sampleApps)
        let state = AppState(simulators: [device], modal: .privacyWizard(wizard))

        // When
        let out = Reducer.reduce(state, .privacyApplied(bundleID: "com.example.App1"))

        // Then
        #expect(out.state.modal == nil)
        #expect(out.state.statusMessage == "Privacy updated for com.example.App1")
    }

    @Test("It should keep the modal open and store the error on failure")
    func failureKeepsModalAndStoresError() throws {
        // Given
        let device = try sim(state: .booted)
        let wizard = PrivacyWizard(simulatorID: device.id, step: .submitting, allApps: sampleApps)
        let state = AppState(simulators: [device], modal: .privacyWizard(wizard))

        // When
        let out = Reducer.reduce(state, .privacyApplyFailed("denied"))

        // Then
        guard case let .privacyWizard(after) = out.state.modal else {
            Issue.record("Expected privacyWizard modal")
            return
        }
        #expect(after.step == .pickPermission)
        #expect(after.error == "denied")
    }
}
