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
import Testing
@testable import HolodeckServices

struct ServicesForwardingTests {

    private let udid = UUID()

    private func client(_ runner: RecordingRunner) -> SimctlClient {
        SimctlClient(runner: runner)
    }

    @Test("It should forward AppearanceService.set to simctl ui appearance")
    func appearanceForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = AppearanceService(client: client(runner))

        // When
        try await service.set(udid: udid, appearance: .light)

        // Then
        #expect(runner.lastInvocation?.contains("appearance") ?? false)
        #expect(runner.lastInvocation?.contains("light") ?? false)
    }

    @Test("It should forward LocaleService.set to two simctl spawn defaults write calls")
    func localeForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = LocaleService(client: client(runner))

        // When
        try await service.set(udid: udid, bcp47: "en-US")

        // Then
        #expect(runner.invocations.count == 2)
        #expect(runner.invocations.contains { $0.contains("AppleLanguages") })
        #expect(runner.invocations.contains { $0.contains("AppleLocale") })
    }

    @Test("It should forward StatusBarService.override to simctl status_bar override")
    func statusBarOverrideForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = StatusBarService(client: client(runner))
        let overrides = StatusBarOverrides(time: "9:41")

        // When
        try await service.override(udid: udid, overrides: overrides)

        // Then
        #expect(runner.lastInvocation?.contains("override") ?? false)
        #expect(runner.lastInvocation?.contains("--time") ?? false)
    }

    @Test("It should forward StatusBarService.clear to simctl status_bar clear")
    func statusBarClearForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = StatusBarService(client: client(runner))

        // When
        try await service.clear(udid: udid)

        // Then
        #expect(runner.lastInvocation?.contains("clear") ?? false)
    }

    @Test("It should forward ScreenshotService.capture to simctl io screenshot")
    func screenshotForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = ScreenshotService(client: client(runner))
        let output = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("holodeck-test-\(UUID().uuidString)")
            .appendingPathComponent("shot.png")
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }

        // When
        let result = try await service.capture(udid: udid, output: output, type: .png)

        // Then
        #expect(result == output)
        #expect(runner.lastInvocation?.contains("screenshot") ?? false)
    }

    @Test("It should forward SimulatorService.boot to simctl boot")
    func simulatorBootForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = SimulatorService(client: client(runner))

        // When
        try await service.boot(udid)

        // Then
        let invocation = try #require(runner.lastInvocation)
        #expect(invocation.contains("boot"))
        #expect(invocation.contains(udid.uuidString))
    }

    @Test("It should forward SimulatorService.shutdown to simctl shutdown")
    func simulatorShutdownForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = SimulatorService(client: client(runner))

        // When
        try await service.shutdown(udid)

        // Then
        #expect(runner.lastInvocation?.contains("shutdown") ?? false)
    }

    @Test("It should forward SimulatorService.erase to simctl erase")
    func simulatorEraseForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = SimulatorService(client: client(runner))

        // When
        try await service.erase(udid)

        // Then
        #expect(runner.lastInvocation?.contains("erase") ?? false)
    }

    @Test("It should forward SimulatorService.delete to simctl delete")
    func simulatorDeleteForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = SimulatorService(client: client(runner))

        // When
        try await service.delete(udid)

        // Then
        #expect(runner.lastInvocation?.contains("delete") ?? false)
    }

    @Test("It should forward SimulatorService.deleteUnavailable to simctl delete unavailable")
    func simulatorDeleteUnavailableForwards() async throws {
        // Given
        let runner = RecordingRunner()
        let service = SimulatorService(client: client(runner))

        // When
        try await service.deleteUnavailable()

        // Then
        let invocation = try #require(runner.lastInvocation)
        #expect(invocation.contains("delete"))
        #expect(invocation.contains("unavailable"))
    }

    @Test("It should forward SimulatorService.availableTargets to simctl list devicetypes runtimes")
    func availableTargetsForwards() async throws {
        // Given
        let stdout = Data(#"{"devicetypes":[],"runtimes":[]}"#.utf8)
        let runner = RecordingRunner(responses: [ProcessResult(stdout: stdout, stderr: Data(), exitCode: 0)])
        let service = SimulatorService(client: client(runner))

        // When
        _ = try await service.availableTargets()

        // Then
        let invocation = try #require(runner.lastInvocation)
        #expect(invocation.contains("devicetypes"))
        #expect(invocation.contains("runtimes"))
    }

    @Test("It should forward SimulatorService.create with the new UDID returned by simctl")
    func simulatorCreateForwards() async throws {
        // Given
        let newUDID = UUID()
        let runner = RecordingRunner(responses: [
            ProcessResult(stdout: Data("\(newUDID.uuidString)\n".utf8), stderr: Data(), exitCode: 0)
        ])
        let service = SimulatorService(client: client(runner))
        let deviceType = DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16")
        let runtime = try #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2"))

        // When
        let result = try await service.create(name: "Test", deviceType: deviceType, runtime: runtime)

        // Then
        #expect(result == newUDID)
        let invocation = try #require(runner.lastInvocation)
        #expect(invocation.contains("create"))
        #expect(invocation.contains("Test"))
    }
}

final class RecordingRunner: ProcessRunning, @unchecked Sendable {

    var responses: [ProcessResult]
    private(set) var invocations: [[String]] = []
    private let lock = NSRecursiveLock()

    init(responses: [ProcessResult] = [ProcessResult(stdout: Data(), stderr: Data(), exitCode: 0)]) {
        self.responses = responses
    }

    var lastInvocation: [String]? {
        lock.withLock { invocations.last }
    }

    func run(_ launchPath: String, _ arguments: [String]) async throws -> ProcessResult {
        lock.withLock {
            invocations.append(arguments)
            return responses.isEmpty
                ? ProcessResult(stdout: Data(), stderr: Data(), exitCode: 0)
                : responses.removeFirst()
        }
    }
}
