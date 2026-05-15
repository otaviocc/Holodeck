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

public enum Modal: Equatable, Sendable {

    case appearance
    case confirmErase(UUID)
    case confirmDelete(UUID)
    case createWizard(CreateWizard)
    case privacyWizard(PrivacyWizard)
    case help
}

public struct PrivacyWizard: Equatable, Sendable {

    // MARK: - Nested types

    public enum Step: Equatable, Sendable {

        case loadingApps
        case pickApp
        case pickAction
        case pickPermission
        case submitting
    }

    // MARK: - Properties

    public var simulatorID: UUID
    public var step: Step
    public var allApps: [InstalledApp]
    public var appIndex: Int
    public var appScrollOffset: Int
    public var actionIndex: Int
    public var permissionIndex: Int
    public var showSystem: Bool
    public var error: String?

    // MARK: - Lifecycle

    public init(
        simulatorID: UUID,
        step: Step = .loadingApps,
        allApps: [InstalledApp] = [],
        appIndex: Int = 0,
        appScrollOffset: Int = 0,
        actionIndex: Int = 0,
        permissionIndex: Int = 0,
        showSystem: Bool = false,
        error: String? = nil
    ) {
        self.simulatorID = simulatorID
        self.step = step
        self.allApps = allApps
        self.appIndex = appIndex
        self.appScrollOffset = appScrollOffset
        self.actionIndex = actionIndex
        self.permissionIndex = permissionIndex
        self.showSystem = showSystem
        self.error = error
    }

    // MARK: - Public

    /// Only the app list scrolls. PrivacyAction/PrivacyPermission lists fit
    /// any viewport and the view auto-centers their focus at render time.
    public static func appViewport(rows: Int) -> Int {
        max(3, rows - 5)
    }

    public var apps: [InstalledApp] {
        showSystem ? allApps : allApps.filter(\.isUserApp)
    }

    public var selectedApp: InstalledApp? {
        let list = apps
        guard !list.isEmpty, appIndex >= 0, appIndex < list.count else { return nil }
        return list[appIndex]
    }

    public var selectedAction: PrivacyAction? {
        let all = PrivacyAction.allCases
        guard !all.isEmpty, actionIndex >= 0, actionIndex < all.count else { return nil }
        return all[actionIndex]
    }

    public var selectedPermission: PrivacyPermission? {
        let all = PrivacyPermission.allCases
        guard !all.isEmpty, permissionIndex >= 0, permissionIndex < all.count else { return nil }
        return all[permissionIndex]
    }
}

public struct CreateWizard: Equatable, Sendable {

    // MARK: - Nested types

    public enum Step: Equatable, Sendable {

        case loading
        case pickDeviceType
        case pickRuntime
        case confirm
        case submitting
    }

    // MARK: - Properties

    public var step: Step
    public var deviceTypes: [DeviceType]
    public var runtimes: [Runtime]
    public var deviceTypeIndex: Int
    public var deviceTypeScrollOffset: Int
    public var runtimeIndex: Int
    public var runtimeScrollOffset: Int
    public var error: String?

    // MARK: - Lifecycle

    public init(
        step: Step = .loading,
        deviceTypes: [DeviceType] = [],
        runtimes: [Runtime] = [],
        deviceTypeIndex: Int = 0,
        deviceTypeScrollOffset: Int = 0,
        runtimeIndex: Int = 0,
        runtimeScrollOffset: Int = 0,
        error: String? = nil
    ) {
        self.step = step
        self.deviceTypes = deviceTypes
        self.runtimes = runtimes
        self.deviceTypeIndex = deviceTypeIndex
        self.deviceTypeScrollOffset = deviceTypeScrollOffset
        self.runtimeIndex = runtimeIndex
        self.runtimeScrollOffset = runtimeScrollOffset
        self.error = error
    }

    // MARK: - Public

    public static func viewport(rows: Int) -> Int {
        max(3, rows - 5)
    }

    public var selectedDeviceType: DeviceType? {
        guard !deviceTypes.isEmpty, deviceTypeIndex < deviceTypes.count else { return nil }
        return deviceTypes[deviceTypeIndex]
    }

    public var selectedRuntime: Runtime? {
        guard !runtimes.isEmpty, runtimeIndex < runtimes.count else { return nil }
        return runtimes[runtimeIndex]
    }

    public var defaultName: String {
        guard let deviceType = selectedDeviceType, let runtime = selectedRuntime else {
            return "Simulator"
        }
        return "\(deviceType.name) (\(runtime.displayName))"
    }
}

public struct AppState: Equatable, Sendable {

    // MARK: - Properties

    public var simulators: [Simulator]
    public var selectedIndex: Int
    public var mainScrollOffset: Int
    public var statusMessage: String?
    public var lastError: String?
    public var pendingOperations: Set<UUID>
    public var isQuitting: Bool
    public var rows: Int
    public var cols: Int
    public var recordingDeviceID: UUID?
    public var recordingPath: URL?
    public var modal: Modal?

    // MARK: - Lifecycle

    public init(
        simulators: [Simulator] = [],
        selectedIndex: Int = 0,
        mainScrollOffset: Int = 0,
        statusMessage: String? = nil,
        lastError: String? = nil,
        pendingOperations: Set<UUID> = [],
        isQuitting: Bool = false,
        rows: Int = 24,
        cols: Int = 80,
        recordingDeviceID: UUID? = nil,
        recordingPath: URL? = nil,
        modal: Modal? = nil
    ) {
        self.simulators = simulators
        self.selectedIndex = selectedIndex
        self.mainScrollOffset = mainScrollOffset
        self.statusMessage = statusMessage
        self.lastError = lastError
        self.pendingOperations = pendingOperations
        self.isQuitting = isQuitting
        self.rows = rows
        self.cols = cols
        self.recordingDeviceID = recordingDeviceID
        self.recordingPath = recordingPath
        self.modal = modal
    }

    // MARK: - Public

    public var isRecording: Bool {
        recordingDeviceID != nil
    }

    public var selectedSimulator: Simulator? {
        guard !simulators.isEmpty, selectedIndex >= 0, selectedIndex < simulators.count else { return nil }
        return simulators[selectedIndex]
    }

    /// Conservative count of simulator rows that fit. The view walks the list
    /// from mainScrollOffset and stops when bodyHeight is exhausted; the 2-line
    /// headroom leaves room for runtime-group headers without exact counting.
    public var mainListViewport: Int {
        let banner = (isRecording ? 1 : 0) + (modal != nil ? 1 : 0)
        return max(1, rows - 4 - banner - 2)
    }

    /// Scroll-on-edge offset for a windowed list. Returns the new top-visible
    /// index given the current offset, the focused index, and the viewport.
    public static func scroll(offset: Int, index: Int, viewport: Int) -> Int {
        if index < offset { return index }
        if index >= offset + viewport { return index - viewport + 1 }
        return offset
    }

    public static func sort(_ simulators: [Simulator]) -> [Simulator] {
        simulators.sorted { lhs, rhs in
            if lhs.runtime != rhs.runtime { return lhs.runtime > rhs.runtime }
            return lhs.name < rhs.name
        }
    }
}
