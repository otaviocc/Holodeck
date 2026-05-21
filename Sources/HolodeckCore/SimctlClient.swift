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

public struct SimctlClient: Sendable {

    // MARK: - Properties

    public var listDevices: @Sendable (_ includeUnavailable: Bool) async throws -> [Simulator]
    public var boot: @Sendable (_ udid: UUID) async throws -> Void
    public var shutdown: @Sendable (_ udid: UUID) async throws -> Void
    public var screenshot: @Sendable (_ udid: UUID, _ path: URL, _ type: ScreenshotType) async throws -> Void
    public var setAppearance: @Sendable (_ udid: UUID, _ appearance: Appearance) async throws -> Void
    public var setStatusBar: @Sendable (_ udid: UUID, _ overrides: StatusBarOverrides) async throws -> Void
    public var clearStatusBar: @Sendable (_ udid: UUID) async throws -> Void
    public var setLocale: @Sendable (_ udid: UUID, _ bcp47: String) async throws -> Void
    public var listAvailableTargets: @Sendable () async throws -> AvailableTargets
    public var listApps: @Sendable (_ udid: UUID) async throws -> [InstalledApp]
    public var create: @Sendable (
        _ name: String,
        _ deviceTypeIdentifier: String,
        _ runtimeIdentifier: String
    ) async throws -> UUID
    public var erase: @Sendable (_ udid: UUID) async throws -> Void
    public var delete: @Sendable (_ udid: UUID) async throws -> Void
    public var deleteUnavailable: @Sendable () async throws -> Void
    public var setLocation: @Sendable (_ udid: UUID, _ latitude: Double, _ longitude: Double) async throws -> Void
    public var clearLocation: @Sendable (_ udid: UUID) async throws -> Void
    public var privacy: @Sendable (
        _ udid: UUID,
        _ action: PrivacyAction,
        _ permission: PrivacyPermission,
        _ bundleID: String?
    ) async throws -> Void
    public var resetKeychain: @Sendable (_ udid: UUID) async throws -> Void
    public var openURL: @Sendable (_ udid: UUID, _ url: String) async throws -> Void
    public var focusSimulatorApp: @Sendable (_ udid: UUID) async throws -> Void

    // MARK: - Lifecycle

    package init(runner: any ProcessRunning = ProcessRunner()) {
        self = .live(runner: runner)
    }

    package init(
        listDevices: @Sendable @escaping (Bool) async throws -> [Simulator],
        boot: @Sendable @escaping (UUID) async throws -> Void,
        shutdown: @Sendable @escaping (UUID) async throws -> Void,
        screenshot: @Sendable @escaping (UUID, URL, ScreenshotType) async throws -> Void,
        setAppearance: @Sendable @escaping (UUID, Appearance) async throws -> Void,
        setStatusBar: @Sendable @escaping (UUID, StatusBarOverrides) async throws -> Void,
        clearStatusBar: @Sendable @escaping (UUID) async throws -> Void,
        setLocale: @Sendable @escaping (UUID, String) async throws -> Void,
        listAvailableTargets: @Sendable @escaping () async throws -> AvailableTargets,
        listApps: @Sendable @escaping (UUID) async throws -> [InstalledApp],
        create: @Sendable @escaping (String, String, String) async throws -> UUID,
        erase: @Sendable @escaping (UUID) async throws -> Void,
        delete: @Sendable @escaping (UUID) async throws -> Void,
        deleteUnavailable: @Sendable @escaping () async throws -> Void,
        setLocation: @Sendable @escaping (UUID, Double, Double) async throws -> Void,
        clearLocation: @Sendable @escaping (UUID) async throws -> Void,
        privacy: @Sendable @escaping (UUID, PrivacyAction, PrivacyPermission, String?) async throws -> Void,
        resetKeychain: @Sendable @escaping (UUID) async throws -> Void,
        openURL: @Sendable @escaping (UUID, String) async throws -> Void,
        focusSimulatorApp: @Sendable @escaping (UUID) async throws -> Void
    ) {
        self.listDevices = listDevices
        self.boot = boot
        self.shutdown = shutdown
        self.screenshot = screenshot
        self.setAppearance = setAppearance
        self.setStatusBar = setStatusBar
        self.clearStatusBar = clearStatusBar
        self.setLocale = setLocale
        self.listAvailableTargets = listAvailableTargets
        self.listApps = listApps
        self.create = create
        self.erase = erase
        self.delete = delete
        self.deleteUnavailable = deleteUnavailable
        self.setLocation = setLocation
        self.clearLocation = clearLocation
        self.privacy = privacy
        self.resetKeychain = resetKeychain
        self.openURL = openURL
        self.focusSimulatorApp = focusSimulatorApp
    }

    // MARK: - Public

    public static func recordVideoCommand(
        udid: UUID,
        output: URL,
        codec: VideoCodec
    ) -> (launchPath: String, arguments: [String]) {
        let args = [
            "simctl", "io", udid.uuidString, "recordVideo",
            "--codec", codec.rawValue,
            output.path
        ]
        return ("/usr/bin/xcrun", args)
    }
}
