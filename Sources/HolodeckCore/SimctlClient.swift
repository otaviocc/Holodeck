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

public extension SimctlClient {

    // swiftlint:disable function_body_length
    static func live(runner: any ProcessRunning = ProcessRunner()) -> Self {
        @Sendable
        func runProcess(_ launchPath: String, label: String, _ arguments: [String]) async throws -> ProcessResult {
            let result: ProcessResult
            do {
                result = try await runner.run(launchPath, arguments)
            } catch {
                throw SimctlError.commandFailed(
                    command: "\(label) \(arguments.joined(separator: " "))",
                    exitCode: -1,
                    stderr: String(describing: error)
                )
            }
            guard result.exitCode == 0 else {
                throw SimctlError.commandFailed(
                    command: "\(label) \(arguments.joined(separator: " "))",
                    exitCode: result.exitCode,
                    stderr: String(data: result.stderr, encoding: .utf8) ?? ""
                )
            }
            return result
        }

        @Sendable
        func runSimctl(_ subcommand: [String]) async throws -> ProcessResult {
            try await runProcess("/usr/bin/xcrun", label: "xcrun", ["simctl"] + subcommand)
        }

        return Self(
            listDevices: { includeUnavailable in
                var args = ["list", "--json", "devices"]
                if !includeUnavailable { args.append("available") }
                let result = try await runSimctl(args)
                do {
                    return try DeviceListDecoder.decode(result.stdout)
                } catch {
                    throw SimctlError.decodingFailed(underlying: error)
                }
            },
            boot: { udid in
                _ = try await runSimctl(["boot", udid.uuidString])
            },
            shutdown: { udid in
                _ = try await runSimctl(["shutdown", udid.uuidString])
            },
            screenshot: { udid, path, type in
                _ = try await runSimctl([
                    "io", udid.uuidString, "screenshot",
                    "--type", type.rawValue,
                    path.path
                ])
            },
            setAppearance: { udid, appearance in
                _ = try await runSimctl(["ui", udid.uuidString, "appearance", appearance.rawValue])
            },
            setStatusBar: { udid, overrides in
                guard !overrides.isEmpty else {
                    throw SimctlError.unsupportedOperation(reason: "no status bar overrides provided")
                }
                _ = try await runSimctl(["status_bar", udid.uuidString, "override"] + overrides.simctlArguments)
            },
            clearStatusBar: { udid in
                _ = try await runSimctl(["status_bar", udid.uuidString, "clear"])
            },
            setLocale: { udid, bcp47 in
                let appleLocale = bcp47.replacingOccurrences(of: "-", with: "_")
                async let languages: ProcessResult = runSimctl([
                    "spawn", udid.uuidString,
                    "defaults", "write", "-g", "AppleLanguages", "-array", bcp47
                ])
                async let locale: ProcessResult = runSimctl([
                    "spawn", udid.uuidString,
                    "defaults", "write", "-g", "AppleLocale", "-string", appleLocale
                ])
                _ = try await (languages, locale)
            },
            listAvailableTargets: {
                let result = try await runSimctl(["list", "--json", "devicetypes", "runtimes"])
                do {
                    return try DeviceListDecoder.decodeAvailableTargets(result.stdout)
                } catch {
                    throw SimctlError.decodingFailed(underlying: error)
                }
            },
            listApps: { udid in
                let result = try await runSimctl(["listapps", udid.uuidString])
                do {
                    return try AppListDecoder.decode(result.stdout)
                } catch {
                    throw SimctlError.decodingFailed(underlying: error)
                }
            },
            create: { name, deviceTypeIdentifier, runtimeIdentifier in
                let result = try await runSimctl(["create", name, deviceTypeIdentifier, runtimeIdentifier])
                let stdout = String(data: result.stdout, encoding: .utf8) ?? ""
                let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let udid = UUID(uuidString: trimmed) else {
                    throw SimctlError.unsupportedOperation(reason: "create returned unexpected output: \(trimmed)")
                }
                return udid
            },
            erase: { udid in
                _ = try await runSimctl(["erase", udid.uuidString])
            },
            delete: { udid in
                _ = try await runSimctl(["delete", udid.uuidString])
            },
            deleteUnavailable: {
                _ = try await runSimctl(["delete", "unavailable"])
            },
            setLocation: { udid, latitude, longitude in
                _ = try await runSimctl(["location", udid.uuidString, "set", "\(latitude),\(longitude)"])
            },
            clearLocation: { udid in
                _ = try await runSimctl(["location", udid.uuidString, "clear"])
            },
            privacy: { udid, action, permission, bundleID in
                var args = ["privacy", udid.uuidString, action.rawValue, permission.rawValue]
                if let bundleID { args.append(bundleID) }
                _ = try await runSimctl(args)
            },
            resetKeychain: { udid in
                _ = try await runSimctl(["keychain", udid.uuidString, "reset"])
            },
            openURL: { udid, url in
                _ = try await runSimctl(["openurl", udid.uuidString, url])
            },
            focusSimulatorApp: { udid in
                _ = try await runProcess(
                    "/usr/bin/open",
                    label: "open",
                    ["-a", "Simulator", "--args", "-CurrentDeviceUDID", udid.uuidString]
                )
            }
        )
    }
    // swiftlint:enable function_body_length
}
