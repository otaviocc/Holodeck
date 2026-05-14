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

public enum AppEvent: Sendable {

    case refreshed([Simulator])
    case refreshFailed(String)
    case key(Key)
    case resized(rows: Int, cols: Int)
    case pollTick
    case operationCompleted(UUID)
    case operationFailed(UUID, String)
    case recordingStarted(UUID, URL)
    case recordingStopped(URL?)
    case recordingFailed(String)
    case screenshotSaved(URL)
    case screenshotFailed(String)
    case appearanceChanged(UUID, Appearance)
    case appearanceFailed(String)
    case targetsLoaded(AvailableTargets)
    case targetsFailed(String)
    case simulatorCreated(UUID, String)
    case simulatorCreateFailed(String)
    case appsLoaded([InstalledApp])
    case appsLoadFailed(String)
    case privacyApplied(bundleID: String)
    case privacyApplyFailed(String)
}

public struct ReducerOutput: Equatable, Sendable {

    // MARK: - Nested types

    public enum SideEffect: Equatable, Sendable {

        case boot(UUID)
        case shutdown(UUID)
        case refresh
        case startRecording(UUID)
        case stopRecording
        case captureScreenshot(UUID)
        case setAppearance(UUID, Appearance)
        case eraseSimulator(UUID)
        case deleteSimulator(UUID)
        case loadTargets
        case createSimulator(name: String, deviceType: DeviceType, runtime: Runtime)
        case focusSimulator(UUID)
        case loadInstalledApps(UUID)
        case applyPrivacy(udid: UUID, action: PrivacyAction, permission: PrivacyPermission, bundleID: String)
    }

    // MARK: - Properties

    public let state: AppState
    public let effects: [SideEffect]

    // MARK: - Lifecycle

    public init(state: AppState, effects: [SideEffect] = []) {
        self.state = state
        self.effects = effects
    }
}

public enum Reducer {

    // MARK: - Public

    // swiftlint:disable function_body_length
    public static func reduce(_ state: AppState, _ event: AppEvent) -> ReducerOutput {
        var next = state
        switch event {
        case let .refreshed(sims):
            next.simulators = AppState.sort(sims)
            let count = next.simulators.count
            if count == 0 {
                next.selectedIndex = 0
            } else if next.selectedIndex >= count {
                next.selectedIndex = count - 1
            }
            next.lastError = nil
            return ReducerOutput(state: next)

        case let .refreshFailed(message):
            next.lastError = message
            return ReducerOutput(state: next)

        case let .resized(rows, cols):
            next.rows = rows
            next.cols = cols
            return ReducerOutput(state: next)

        case .pollTick:
            if next.isRecording { return ReducerOutput(state: next) }
            return ReducerOutput(state: next, effects: [.refresh])

        case let .key(key):
            return handleKey(state: next, key: key)

        case let .operationCompleted(id):
            next.pendingOperations.remove(id)
            next.statusMessage = nil
            return ReducerOutput(state: next, effects: [.refresh])

        case let .operationFailed(id, message):
            next.pendingOperations.remove(id)
            next.statusMessage = nil
            next.lastError = message
            return ReducerOutput(state: next, effects: [.refresh])

        case let .recordingStarted(id, url):
            next.recordingDeviceID = id
            next.recordingPath = url
            next.statusMessage = nil
            return ReducerOutput(state: next)

        case let .recordingStopped(url):
            next.recordingDeviceID = nil
            next.recordingPath = nil
            next.statusMessage = url.map { "Saved \($0.path)" }
            return ReducerOutput(state: next, effects: [.refresh])

        case let .recordingFailed(message):
            next.recordingDeviceID = nil
            next.recordingPath = nil
            next.lastError = message
            return ReducerOutput(state: next)

        case let .screenshotSaved(url):
            next.statusMessage = "Screenshot saved \(url.lastPathComponent)"
            return ReducerOutput(state: next)

        case let .screenshotFailed(message):
            next.lastError = message
            return ReducerOutput(state: next)

        case let .appearanceChanged(_, appearance):
            next.statusMessage = "Appearance set to \(appearance.rawValue)"
            return ReducerOutput(state: next, effects: [.refresh])

        case let .appearanceFailed(message):
            next.lastError = message
            return ReducerOutput(state: next)

        case let .targetsLoaded(targets):
            if case let .createWizard(wizard) = next.modal {
                var updated = wizard
                updated.deviceTypes = targets.deviceTypes.sorted { $0.name < $1.name }
                updated.runtimes = targets.runtimes.sorted(by: >)
                updated.step = updated.deviceTypes.isEmpty ? .loading : .pickDeviceType
                next.modal = .createWizard(updated)
            }
            return ReducerOutput(state: next)

        case let .targetsFailed(message):
            if case .createWizard = next.modal { next.modal = nil }
            next.lastError = message
            return ReducerOutput(state: next)

        case let .simulatorCreated(_, name):
            next.modal = nil
            next.statusMessage = "Created \(name)"
            return ReducerOutput(state: next, effects: [.refresh])

        case let .simulatorCreateFailed(message):
            if case let .createWizard(wizard) = next.modal {
                var updated = wizard
                updated.step = .confirm
                updated.error = message
                next.modal = .createWizard(updated)
            } else {
                next.lastError = message
            }
            return ReducerOutput(state: next)

        case let .appsLoaded(apps):
            if case let .privacyWizard(wizard) = next.modal {
                var updated = wizard
                updated.allApps = apps
                updated.appIndex = 0
                updated.step = .pickApp
                updated.error = nil
                next.modal = .privacyWizard(updated)
            }
            return ReducerOutput(state: next)

        case let .appsLoadFailed(message):
            if case .privacyWizard = next.modal {
                next.modal = nil
            }
            next.lastError = message
            return ReducerOutput(state: next)

        case let .privacyApplied(bundleID):
            next.modal = nil
            next.statusMessage = "Privacy updated for \(bundleID)"
            return ReducerOutput(state: next)

        case let .privacyApplyFailed(message):
            if case let .privacyWizard(wizard) = next.modal {
                var updated = wizard
                updated.step = .pickPermission
                updated.error = message
                next.modal = .privacyWizard(updated)
            } else {
                next.lastError = message
            }
            return ReducerOutput(state: next)
        }
    }

    // swiftlint:enable function_body_length

    // MARK: - Private

    // swiftlint:disable function_body_length
    private static func handleKey(state: AppState, key: Key) -> ReducerOutput {
        if state.modal != nil {
            return handleModalKey(state: state, key: key)
        }
        var next = state
        let count = next.simulators.count
        switch key {
        case .up, .char("k"):
            if count > 0 { next.selectedIndex = max(0, next.selectedIndex - 1) }
            return ReducerOutput(state: next)

        case .down, .char("j"):
            if count > 0 { next.selectedIndex = min(count - 1, next.selectedIndex + 1) }
            return ReducerOutput(state: next)

        case .char("q"), .escape:
            if next.isRecording { return ReducerOutput(state: next, effects: [.stopRecording]) }
            next.isQuitting = true
            return ReducerOutput(state: next)

        case .char("R"):
            next.statusMessage = "Refreshing…"
            return ReducerOutput(state: next, effects: [.refresh])

        case .char("r"):
            if next.recordingDeviceID != nil {
                next.statusMessage = "Stopping recording…"
                return ReducerOutput(state: next, effects: [.stopRecording])
            }
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            guard sim.state == .booted else {
                next.statusMessage = "Cannot record: \(sim.name) is \(sim.state.rawValue)"
                return ReducerOutput(state: next)
            }
            next.statusMessage = "Starting recording…"
            return ReducerOutput(state: next, effects: [.startRecording(sim.id)])

        case .char("p"):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            guard sim.state == .booted else {
                next.statusMessage = "Cannot capture: \(sim.name) is \(sim.state.rawValue)"
                return ReducerOutput(state: next)
            }
            next.statusMessage = "Capturing screenshot…"
            return ReducerOutput(state: next, effects: [.captureScreenshot(sim.id)])

        case .char("a"):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            guard sim.state == .booted else {
                next.statusMessage = "Cannot set appearance: \(sim.name) is \(sim.state.rawValue)"
                return ReducerOutput(state: next)
            }
            next.modal = .appearance
            return ReducerOutput(state: next)

        case .char("e"):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            guard sim.state == .shutdown else {
                next.statusMessage = "Cannot erase: \(sim.name) is \(sim.state.rawValue)"
                return ReducerOutput(state: next)
            }
            next.modal = .confirmErase(sim.id)
            return ReducerOutput(state: next)

        case .char("d"):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            next.modal = .confirmDelete(sim.id)
            return ReducerOutput(state: next)

        case .char("n"):
            next.modal = .createWizard(CreateWizard())
            return ReducerOutput(state: next, effects: [.loadTargets])

        case .char("f"):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            next.statusMessage = "Focusing \(sim.name)…"
            return ReducerOutput(state: next, effects: [.focusSimulator(sim.id)])

        case .char("P"):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            guard sim.state == .booted else {
                next.statusMessage = "Cannot inspect apps: \(sim.name) is \(sim.state.rawValue)"
                return ReducerOutput(state: next)
            }
            next.modal = .privacyWizard(PrivacyWizard(simulatorID: sim.id))
            return ReducerOutput(state: next, effects: [.loadInstalledApps(sim.id)])

        case .char("?"):
            next.modal = .help
            return ReducerOutput(state: next)

        case .enter, .char(" "):
            guard let sim = next.selectedSimulator else { return ReducerOutput(state: next) }
            guard !next.pendingOperations.contains(sim.id) else { return ReducerOutput(state: next) }
            switch sim.state {
            case .booted:
                next.pendingOperations.insert(sim.id)
                next.statusMessage = "Shutting down \(sim.name)…"
                return ReducerOutput(state: next, effects: [.shutdown(sim.id)])
            case .shutdown:
                next.pendingOperations.insert(sim.id)
                next.statusMessage = "Booting \(sim.name)…"
                return ReducerOutput(state: next, effects: [.boot(sim.id)])
            default:
                next.statusMessage = "\(sim.name) is \(sim.state.rawValue)"
                return ReducerOutput(state: next)
            }

        default:
            return ReducerOutput(state: next)
        }
    }

    // swiftlint:enable function_body_length

    private static func handleModalKey(state: AppState, key: Key) -> ReducerOutput {
        ModalReducer.handle(state: state, key: key)
    }
}
