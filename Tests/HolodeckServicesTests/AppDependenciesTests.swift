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
import HolodeckServices
import HolodeckTestSupport
import Testing

struct AppDependenciesTests {

    @Test("It should propagate a custom simctl client into every facade service")
    func liveWiresCustomClientIntoFacades() async throws {
        // Given
        let calls = CallLog()
        let simctl = SimctlClient.mock(
            boot: { _ in await calls.add("boot") },
            shutdown: { _ in await calls.add("shutdown") },
            setAppearance: { _, _ in await calls.add("setAppearance") },
            setStatusBar: { _, _ in await calls.add("setStatusBar") },
            setLocale: { _, _ in await calls.add("setLocale") },
            setLocation: { _, _, _ in await calls.add("setLocation") },
            privacy: { _, _, _, _ in await calls.add("privacy") },
            resetKeychain: { _ in await calls.add("resetKeychain") }
        )
        let dependencies = AppDependencies.live(simulatorClient: simctl)
        let udid = UUID()

        // When
        try await dependencies.simulatorService.boot(udid)
        try await dependencies.simulatorService.shutdown(udid)
        try await dependencies.appearanceService.set(udid: udid, appearance: .dark)
        try await dependencies.statusBarService.override(udid: udid, overrides: StatusBarOverrides(time: "9:41"))
        try await dependencies.localeService.set(udid: udid, bcp47: "en-US")
        try await dependencies.locationService.set(udid: udid, latitude: 1, longitude: 2)
        try await dependencies.privacyService.apply(udid: udid, action: .grant, permission: .all, bundleID: nil)
        try await dependencies.keychainService.reset(udid: udid)

        // Then
        let log = await calls.values
        #expect(log == [
            "boot",
            "shutdown",
            "setAppearance",
            "setStatusBar",
            "setLocale",
            "setLocation",
            "privacy",
            "resetKeychain"
        ])
    }

    @Test("It should use the provided config without touching disk")
    func liveAcceptsCustomConfig() {
        withTemporaryDirectory { dir in
            // Given an empty directory (no config.json)

            // When
            let dependencies = AppDependencies.live(configResolver: .mock(base: dir))

            // Then
            #expect(dependencies.configuration == .default)
        }
    }

    @Test("It should expose the same simctl instance through `simulatorClient` and the facades")
    func liveExposesInjectedSimctlIdentically() async throws {
        // Given
        struct Marker: Error {}
        // swiftlint:disable:next trailing_closure
        let simctl = SimctlClient.mock(listDevices: { _ in throw Marker() })

        // When
        let dependencies = AppDependencies.live(simulatorClient: simctl)

        // Then
        await #expect(throws: Marker.self) { _ = try await dependencies.simulatorClient.listDevices(false) }
        await #expect(throws: Marker.self) { _ = try await dependencies.simulatorService.list() }
    }
}

// MARK: - Private

private actor CallLog {

    // MARK: - Properties

    private(set) var values: [String] = []

    // MARK: - Public

    func add(_ name: String) {
        values.append(name)
    }
}
