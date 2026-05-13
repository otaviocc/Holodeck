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
import Testing
@testable import HolodeckCore

struct SimctlClientTests {

    private let udid = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    @Test("It should request the available devices list by default")
    func listDevicesAvailable() async throws {
        // Given
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(stdout: #"{"devices":{}}"#)])
        let client = SimctlClient(runner: runner)

        // When
        _ = try await client.listDevices()

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.launchPath == "/usr/bin/xcrun")
        #expect(invocation.arguments == ["simctl", "list", "--json", "devices", "available"])
    }

    @Test("It should request the full device list when includeUnavailable is true")
    func listDevicesIncludingUnavailable() async throws {
        // Given
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(stdout: #"{"devices":{}}"#)])
        let client = SimctlClient(runner: runner)

        // When
        _ = try await client.listDevices(includeUnavailable: true)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "list", "--json", "devices"])
    }

    @Test("It should surface a commandFailed error when simctl exits non-zero")
    func listDevicesPropagatesFailure() async throws {
        // Given
        let runner = StubProcessRunner(responses: [StubProcessRunner.failure(stderr: "boom", exitCode: 2)])
        let client = SimctlClient(runner: runner)

        // Then
        await #expect(throws: SimctlError.self) {
            _ = try await client.listDevices()
        }
    }

    @Test("It should wrap decoding failures in decodingFailed")
    func listDevicesPropagatesDecodingFailure() async throws {
        // Given
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(stdout: "not json")])
        let client = SimctlClient(runner: runner)

        // Then
        await #expect(throws: SimctlError.self) {
            _ = try await client.listDevices()
        }
    }

    @Test("It should issue simctl boot with the UDID")
    func bootBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.boot(udid)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "boot", udid.uuidString])
    }

    @Test("It should issue simctl shutdown with the UDID")
    func shutdownBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.shutdown(udid)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "shutdown", udid.uuidString])
    }

    @Test("It should pass --type and the output path to simctl io screenshot")
    func screenshotBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)
        let output = URL(fileURLWithPath: "/tmp/shot.png")

        // When
        try await client.screenshot(udid: udid, to: output, type: .jpeg)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == [
            "simctl", "io", udid.uuidString, "screenshot",
            "--type", "jpeg",
            "/tmp/shot.png"
        ])
    }

    @Test("It should call simctl ui appearance with the new appearance")
    func setAppearanceBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.setAppearance(udid: udid, appearance: .dark)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "ui", udid.uuidString, "appearance", "dark"])
    }

    @Test("It should call simctl status_bar override with the provided fields")
    func setStatusBarBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)
        let overrides = StatusBarOverrides(time: "9:41", batteryState: .charged, batteryLevel: 80)

        // When
        try await client.setStatusBar(udid: udid, overrides: overrides)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == [
            "simctl", "status_bar", udid.uuidString, "override",
            "--time", "9:41",
            "--batteryState", "charged",
            "--batteryLevel", "80"
        ])
    }

    @Test("It should reject empty status bar overrides without invoking simctl")
    func setStatusBarRejectsEmpty() async {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // Then
        await #expect(throws: SimctlError.self) {
            try await client.setStatusBar(udid: udid, overrides: StatusBarOverrides())
        }
        #expect(runner.invocations.isEmpty)
    }

    @Test("It should call simctl status_bar clear")
    func clearStatusBarBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.clearStatusBar(udid: udid)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "status_bar", udid.uuidString, "clear"])
    }

    @Test("It should write both AppleLanguages and AppleLocale when setting locale")
    func setLocaleWritesBothDefaults() async throws {
        // Given
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(), StubProcessRunner.ok()])
        let client = SimctlClient(runner: runner)

        // When
        try await client.setLocale(udid: udid, bcp47: "pt-BR")

        // Then
        let languageArgs = runner.invocations.map(\.arguments).first { $0.contains("AppleLanguages") }
        let localeArgs = runner.invocations.map(\.arguments).first { $0.contains("AppleLocale") }
        #expect(languageArgs == [
            "simctl", "spawn", udid.uuidString,
            "defaults", "write", "-g", "AppleLanguages", "-array", "pt-BR"
        ])
        #expect(localeArgs == [
            "simctl", "spawn", udid.uuidString,
            "defaults", "write", "-g", "AppleLocale", "-string", "pt_BR"
        ])
    }

    @Test("It should request devicetypes and runtimes from simctl list")
    func listAvailableTargetsBuildsArgs() async throws {
        // Given
        let stdout = #"{"devicetypes":[],"runtimes":[]}"#
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(stdout: stdout)])
        let client = SimctlClient(runner: runner)

        // When
        _ = try await client.listAvailableTargets()

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "list", "--json", "devicetypes", "runtimes"])
    }

    @Test("It should parse the new UDID from simctl create stdout")
    func createParsesUDID() async throws {
        // Given
        let newUDID = UUID()
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(stdout: "\(newUDID.uuidString)\n")])
        let client = SimctlClient(runner: runner)

        // When
        let result = try await client.create(
            name: "iPhone 16 Pro",
            deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            runtimeIdentifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
        )

        // Then
        #expect(result == newUDID)
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == [
            "simctl", "create",
            "iPhone 16 Pro",
            "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro",
            "com.apple.CoreSimulator.SimRuntime.iOS-18-2"
        ])
    }

    @Test("It should throw if simctl create returns something other than a UDID")
    func createRejectsBadOutput() async {
        // Given
        let runner = StubProcessRunner(responses: [StubProcessRunner.ok(stdout: "not a udid")])
        let client = SimctlClient(runner: runner)

        // Then
        await #expect(throws: SimctlError.self) {
            _ = try await client.create(name: "x", deviceTypeIdentifier: "y", runtimeIdentifier: "z")
        }
    }

    @Test("It should call simctl erase with the UDID")
    func eraseBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.erase(udid)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "erase", udid.uuidString])
    }

    @Test("It should call simctl delete with the UDID")
    func deleteBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.delete(udid)

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "delete", udid.uuidString])
    }

    @Test("It should call simctl delete unavailable")
    func deleteUnavailableBuildsArgs() async throws {
        // Given
        let runner = StubProcessRunner()
        let client = SimctlClient(runner: runner)

        // When
        try await client.deleteUnavailable()

        // Then
        let invocation = try #require(runner.invocations.first)
        #expect(invocation.arguments == ["simctl", "delete", "unavailable"])
    }

    @Test("It should build the recordVideo command with codec and output path")
    func recordVideoCommandBuildsArgs() {
        // When
        let command = SimctlClient.recordVideoCommand(
            udid: udid,
            output: URL(fileURLWithPath: "/tmp/clip.mp4"),
            codec: .hevc
        )

        // Then
        #expect(command.launchPath == "/usr/bin/xcrun")
        #expect(command.arguments == [
            "simctl", "io", udid.uuidString, "recordVideo",
            "--codec", "hevc",
            "/tmp/clip.mp4"
        ])
    }
}
