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
}

public struct CreateWizard: Equatable, Sendable {

    public enum Step: Equatable, Sendable {

        case loading
        case pickDeviceType
        case pickRuntime
        case confirm
        case submitting
    }

    public var step: Step
    public var deviceTypes: [DeviceType]
    public var runtimes: [Runtime]
    public var deviceTypeIndex: Int
    public var runtimeIndex: Int
    public var error: String?

    public init(
        step: Step = .loading,
        deviceTypes: [DeviceType] = [],
        runtimes: [Runtime] = [],
        deviceTypeIndex: Int = 0,
        runtimeIndex: Int = 0,
        error: String? = nil
    ) {
        self.step = step
        self.deviceTypes = deviceTypes
        self.runtimes = runtimes
        self.deviceTypeIndex = deviceTypeIndex
        self.runtimeIndex = runtimeIndex
        self.error = error
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

    public var simulators: [Simulator]
    public var selectedIndex: Int
    public var statusMessage: String?
    public var lastError: String?
    public var pendingOperations: Set<UUID>
    public var isQuitting: Bool
    public var rows: Int
    public var cols: Int
    public var recordingDeviceID: UUID?
    public var recordingPath: URL?
    public var modal: Modal?

    public var isRecording: Bool {
        recordingDeviceID != nil
    }

    public init(
        simulators: [Simulator] = [],
        selectedIndex: Int = 0,
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

    public var sortedSimulators: [Simulator] {
        simulators.sorted { lhs, rhs in
            if lhs.runtime != rhs.runtime { return lhs.runtime > rhs.runtime }
            return lhs.name < rhs.name
        }
    }

    public var selectedSimulator: Simulator? {
        let sorted = sortedSimulators
        guard !sorted.isEmpty, selectedIndex >= 0, selectedIndex < sorted.count else { return nil }
        return sorted[selectedIndex]
    }
}
