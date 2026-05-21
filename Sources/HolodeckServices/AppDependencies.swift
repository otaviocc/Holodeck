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

/// Composition root for the application. CLI subcommands and the TUI construct
/// `AppDependencies.live()` at the top level and pass the value down; tests
/// build `.mock(...)` with overrides for the surfaces they exercise.
public struct AppDependencies: Sendable {

    // MARK: - Properties

    public var configuration: Config
    public var simulatorClient: SimctlClient
    public var urlHistoryStore: URLHistoryStore
    public var simulatorService: SimulatorService
    public var recordingService: RecordingService
    public var screenshotService: ScreenshotService
    public var appearanceService: AppearanceService
    public var statusBarService: StatusBarService
    public var localeService: LocaleService
    public var privacyService: PrivacyService
    public var keychainService: KeychainService
    public var locationService: LocationService

    // MARK: - Lifecycle

    public init(
        configuration: Config,
        simulatorClient: SimctlClient,
        urlHistoryStore: URLHistoryStore,
        simulatorService: SimulatorService,
        recordingService: RecordingService,
        screenshotService: ScreenshotService,
        appearanceService: AppearanceService,
        statusBarService: StatusBarService,
        localeService: LocaleService,
        privacyService: PrivacyService,
        keychainService: KeychainService,
        locationService: LocationService
    ) {
        self.configuration = configuration
        self.simulatorClient = simulatorClient
        self.urlHistoryStore = urlHistoryStore
        self.simulatorService = simulatorService
        self.recordingService = recordingService
        self.screenshotService = screenshotService
        self.appearanceService = appearanceService
        self.statusBarService = statusBarService
        self.localeService = localeService
        self.privacyService = privacyService
        self.keychainService = keychainService
        self.locationService = locationService
    }
}

public extension AppDependencies {

    static func live(
        configResolver: HolodeckConfigResolver = .live(),
        simulatorClient: SimctlClient = .live(),
        recorder: Recorder = .live()
    ) -> Self {
        make(
            configuration: (try? ConfigLoader(configResolver: configResolver).load()) ?? .default,
            simulatorClient: simulatorClient,
            urlHistoryStore: .live(configResolver: configResolver),
            recordingService: .live(recorder: recorder)
        )
    }
}

package extension AppDependencies {

    static func make(
        configuration: Config,
        simulatorClient: SimctlClient,
        urlHistoryStore: URLHistoryStore,
        recordingService: RecordingService
    ) -> Self {
        Self(
            configuration: configuration,
            simulatorClient: simulatorClient,
            urlHistoryStore: urlHistoryStore,
            simulatorService: SimulatorService(client: simulatorClient),
            recordingService: recordingService,
            screenshotService: ScreenshotService(client: simulatorClient),
            appearanceService: AppearanceService(client: simulatorClient),
            statusBarService: StatusBarService(client: simulatorClient),
            localeService: LocaleService(client: simulatorClient),
            privacyService: PrivacyService(client: simulatorClient),
            keychainService: KeychainService(client: simulatorClient),
            locationService: LocationService(client: simulatorClient)
        )
    }
}
