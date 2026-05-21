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

public extension SimctlClient {

    static func mock(
        listDevices: @Sendable @escaping (Bool) async throws -> [Simulator] = { _ in [] },
        boot: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        shutdown: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        screenshot: @Sendable @escaping (UUID, URL, ScreenshotType) async throws -> Void = { _, _, _ in },
        setAppearance: @Sendable @escaping (UUID, Appearance) async throws -> Void = { _, _ in },
        setStatusBar: @Sendable @escaping (UUID, StatusBarOverrides) async throws -> Void = { _, _ in },
        clearStatusBar: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        setLocale: @Sendable @escaping (UUID, String) async throws -> Void = { _, _ in },
        listAvailableTargets: @Sendable @escaping () async throws -> AvailableTargets
            = { AvailableTargets(deviceTypes: [], runtimes: []) },
        listApps: @Sendable @escaping (UUID) async throws -> [InstalledApp] = { _ in [] },
        create: @Sendable @escaping (String, String, String) async throws -> UUID = { _, _, _ in UUID() },
        erase: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        delete: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        deleteUnavailable: @Sendable @escaping () async throws -> Void = {},
        setLocation: @Sendable @escaping (UUID, Double, Double) async throws -> Void = { _, _, _ in },
        clearLocation: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        privacy: @Sendable @escaping (UUID, PrivacyAction, PrivacyPermission, String?) async throws -> Void
            = { _, _, _, _ in },
        resetKeychain: @Sendable @escaping (UUID) async throws -> Void = { _ in },
        openURL: @Sendable @escaping (UUID, String) async throws -> Void = { _, _ in },
        focusSimulatorApp: @Sendable @escaping (UUID) async throws -> Void = { _ in }
    ) -> Self {
        Self(
            listDevices: listDevices,
            boot: boot,
            shutdown: shutdown,
            screenshot: screenshot,
            setAppearance: setAppearance,
            setStatusBar: setStatusBar,
            clearStatusBar: clearStatusBar,
            setLocale: setLocale,
            listAvailableTargets: listAvailableTargets,
            listApps: listApps,
            create: create,
            erase: erase,
            delete: delete,
            deleteUnavailable: deleteUnavailable,
            setLocation: setLocation,
            clearLocation: clearLocation,
            privacy: privacy,
            resetKeychain: resetKeychain,
            openURL: openURL,
            focusSimulatorApp: focusSimulatorApp
        )
    }
}
