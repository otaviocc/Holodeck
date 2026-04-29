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

import HolodeckCore
import XCTest
@testable import HolodeckTUI

final class MediaReducerTests: XCTestCase {

    private func bootedSim(name: String = "iPhone 16") -> Simulator {
        Simulator(
            id: UUID(),
            name: name,
            runtime: Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")!,
            deviceType: DeviceType(identifier: "x"),
            state: .booted,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    private func shutdownSim() -> Simulator {
        Simulator(
            id: UUID(),
            name: "Off",
            runtime: Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")!,
            deviceType: DeviceType(identifier: "x"),
            state: .shutdown,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    func testRStartsRecordingWhenBooted() {
        let sim = bootedSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("r")))
        XCTAssertEqual(out.effects, [.startRecording(sim.id)])
    }

    func testRDoesNotRecordWhenShutdown() {
        let sim = shutdownSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("r")))
        XCTAssertEqual(out.effects, [])
        XCTAssertNotNil(out.state.statusMessage)
    }

    func testRStopsRecordingWhenAlreadyRecording() {
        let sim = bootedSim()
        let state = AppState(
            simulators: [sim],
            recordingDeviceID: sim.id,
            recordingPath: URL(fileURLWithPath: "/tmp/x.mp4")
        )
        let out = Reducer.reduce(state, .key(.char("r")))
        XCTAssertEqual(out.effects, [.stopRecording])
    }

    func testQDuringRecordingStopsInsteadOfQuitting() {
        let sim = bootedSim()
        let state = AppState(
            simulators: [sim],
            recordingDeviceID: sim.id,
            recordingPath: URL(fileURLWithPath: "/tmp/x.mp4")
        )
        let out = Reducer.reduce(state, .key(.char("q")))
        XCTAssertEqual(out.effects, [.stopRecording])
        XCTAssertFalse(out.state.isQuitting)
    }

    func testPCapturesScreenshotWhenBooted() {
        let sim = bootedSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("p")))
        XCTAssertEqual(out.effects, [.captureScreenshot(sim.id)])
    }

    func testRecordingStartedSetsState() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/r.mp4")
        let out = Reducer.reduce(AppState(), .recordingStarted(id, url))
        XCTAssertEqual(out.state.recordingDeviceID, id)
        XCTAssertEqual(out.state.recordingPath, url)
        XCTAssertTrue(out.state.isRecording)
    }

    func testRecordingStoppedClearsAndRefreshes() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/r.mp4")
        let state = AppState(recordingDeviceID: id, recordingPath: url)
        let out = Reducer.reduce(state, .recordingStopped(url))
        XCTAssertNil(out.state.recordingDeviceID)
        XCTAssertNil(out.state.recordingPath)
        XCTAssertEqual(out.effects, [.refresh])
        XCTAssertTrue(out.state.statusMessage?.contains("Saved") ?? false)
    }

    func testPollTickRefreshesWhenIdle() {
        let out = Reducer.reduce(AppState(), .pollTick)
        XCTAssertEqual(out.effects, [.refresh])
    }

    func testPollTickSuppressedWhileRecording() {
        let state = AppState(recordingDeviceID: UUID(), recordingPath: URL(fileURLWithPath: "/tmp/r.mp4"))
        let out = Reducer.reduce(state, .pollTick)
        XCTAssertEqual(out.effects, [])
    }
}
