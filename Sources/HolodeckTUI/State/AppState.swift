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

/// Intent behind an in-flight simctl operation. Lets the reducer reconcile
/// `pendingOperations` against an arriving `.refreshed` listing — if the sim
/// already reached the target state we can drop the pending entry even when
/// the spawned `simctl` task has not yet returned (a known macOS quirk where
/// `xcrun simctl shutdown` can block for many seconds after the simulator
/// is already shut down).
public enum PendingOperation: Equatable, Sendable {

    case boot
    case shutdown
    case erase
    case delete
}

public enum Modal: Equatable, Sendable {

    case appearance
    case confirmErase(UUID)
    case confirmDelete(UUID)
    case createWizard(CreateWizard)
    case privacyWizard(PrivacyWizard)
    case inspector(UUID)
    case openURL(OpenURLPrompt)
    case commandPalette(CommandPalette)
    case help

    /// Some modals reference a specific simulator by UDID. If that sim disappears
    /// between the modal opening and the next refresh, the reducer drops the modal.
    public var referencedSimulator: UUID? {
        switch self {
        case let .confirmErase(id), let .confirmDelete(id), let .inspector(id):
            id
        case let .openURL(prompt):
            prompt.simulatorID
        case let .commandPalette(palette):
            palette.simulatorID
        case .appearance, .createWizard, .privacyWizard, .help:
            nil
        }
    }
}

public struct CommandPalette: Equatable, Sendable {

    // MARK: - Properties

    /// Simulator selected when the palette was opened. Nil when no sim was
    /// selected (only the `new` command is applicable). Used so a refresh that
    /// drops the underlying sim auto-dismisses the palette before it can run
    /// a command against the wrong target.
    public var simulatorID: UUID?
    public var query: String

    // MARK: - Lifecycle

    public init(simulatorID: UUID? = nil, query: String = "") {
        self.simulatorID = simulatorID
        self.query = query
    }
}

public struct OpenURLPrompt: Equatable, Sendable {

    // MARK: - Properties

    public var simulatorID: UUID
    public var url: String
    public var historyIndex: Int
    public var isSubmitting: Bool
    public var error: String?

    // MARK: - Lifecycle

    public init(
        simulatorID: UUID,
        url: String = "",
        historyIndex: Int = -1,
        isSubmitting: Bool = false,
        error: String? = nil
    ) {
        self.simulatorID = simulatorID
        self.url = url
        self.historyIndex = historyIndex
        self.isSubmitting = isSubmitting
        self.error = error
    }
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
    public var deviceTypeFilter: String
    public var isDeviceTypeFilterFocused: Bool
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
        deviceTypeFilter: String = "",
        isDeviceTypeFilterFocused: Bool = false,
        error: String? = nil
    ) {
        self.step = step
        self.deviceTypes = deviceTypes
        self.runtimes = runtimes
        self.deviceTypeIndex = deviceTypeIndex
        self.deviceTypeScrollOffset = deviceTypeScrollOffset
        self.runtimeIndex = runtimeIndex
        self.runtimeScrollOffset = runtimeScrollOffset
        self.deviceTypeFilter = deviceTypeFilter
        self.isDeviceTypeFilterFocused = isDeviceTypeFilterFocused
        self.error = error
    }

    // MARK: - Public

    public static func viewport(rows: Int) -> Int {
        max(3, rows - 5)
    }

    /// Device-type list viewport accounting for the filter banner (one row).
    /// The reducer's scroll math and the view's row clamp must agree on this
    /// number — otherwise the selected row can sit just off the bottom edge.
    public func deviceTypeViewport(rows: Int) -> Int {
        let banner = (isDeviceTypeFilterFocused || !deviceTypeFilter.isEmpty) ? 1 : 0
        return max(1, CreateWizard.viewport(rows: rows) - banner)
    }

    public var visibleDeviceTypes: [DeviceType] {
        guard !deviceTypeFilter.isEmpty else { return deviceTypes }
        return deviceTypes.filter { $0.name.localizedCaseInsensitiveContains(deviceTypeFilter) }
    }

    public var selectedDeviceType: DeviceType? {
        let list = visibleDeviceTypes
        guard !list.isEmpty, deviceTypeIndex >= 0, deviceTypeIndex < list.count else { return nil }
        return list[deviceTypeIndex]
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
    public var filterQuery: String
    public var isFilterFocused: Bool
    public var statusMessage: String?
    public var lastError: String?
    public var pendingOperations: [UUID: PendingOperation]
    public var isQuitting: Bool
    public var rows: Int
    public var cols: Int
    public var recordingDeviceID: UUID?
    public var recordingPath: URL?
    public var modal: Modal?
    public var urlHistory: [String]

    // MARK: - Lifecycle

    public init(
        simulators: [Simulator] = [],
        selectedIndex: Int = 0,
        mainScrollOffset: Int = 0,
        filterQuery: String = "",
        isFilterFocused: Bool = false,
        statusMessage: String? = nil,
        lastError: String? = nil,
        pendingOperations: [UUID: PendingOperation] = [:],
        isQuitting: Bool = false,
        rows: Int = 24,
        cols: Int = 80,
        recordingDeviceID: UUID? = nil,
        recordingPath: URL? = nil,
        modal: Modal? = nil,
        urlHistory: [String] = []
    ) {
        self.simulators = simulators
        self.selectedIndex = selectedIndex
        self.mainScrollOffset = mainScrollOffset
        self.filterQuery = filterQuery
        self.isFilterFocused = isFilterFocused
        self.statusMessage = statusMessage
        self.lastError = lastError
        self.pendingOperations = pendingOperations
        self.isQuitting = isQuitting
        self.rows = rows
        self.cols = cols
        self.recordingDeviceID = recordingDeviceID
        self.recordingPath = recordingPath
        self.modal = modal
        self.urlHistory = urlHistory
    }

    // MARK: - Public

    public var isRecording: Bool {
        recordingDeviceID != nil
    }

    public var visibleSimulators: [Simulator] {
        guard !filterQuery.isEmpty else { return simulators }
        return simulators.filter { $0.name.localizedCaseInsensitiveContains(filterQuery) }
    }

    public var selectedSimulator: Simulator? {
        // Skip the filter rebuild on the unfiltered path — selectedIndex
        // already indexes directly into `simulators`.
        if filterQuery.isEmpty {
            guard !simulators.isEmpty, selectedIndex >= 0, selectedIndex < simulators.count else { return nil }
            return simulators[selectedIndex]
        }
        let list = visibleSimulators
        guard !list.isEmpty, selectedIndex >= 0, selectedIndex < list.count else { return nil }
        return list[selectedIndex]
    }

    /// Conservative count of simulator rows that fit. The view walks the list
    /// from mainScrollOffset and stops when bodyHeight is exhausted; the 2-line
    /// headroom leaves room for runtime-group headers without exact counting.
    public var mainListViewport: Int {
        let modalBanner = if case .commandPalette = modal {
            0
        } else if modal != nil {
            1
        } else {
            0
        }
        let banner = (isRecording ? 1 : 0) + modalBanner
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
