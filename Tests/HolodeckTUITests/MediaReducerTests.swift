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
@testable import HolodeckTUI

struct MediaReducerTests {

    private func bootedSim(name: String = "iPhone 16") throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: name,
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "x"),
            state: .booted,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    private func shutdownSim() throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: "Off",
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "x"),
            state: .shutdown,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    @Test("It should start recording when r is pressed and the simulator is booted")
    func rStartsRecordingWhenBooted() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("r")))
        #expect(out.effects == [.startRecording(sim.id)])
    }

    @Test("It should not record a shut-down simulator")
    func rDoesNotRecordWhenShutdown() throws {
        let sim = try shutdownSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("r")))
        #expect(out.effects == [])
        #expect(out.state.statusMessage != nil)
    }

    @Test("It should stop the active recording when r is pressed again")
    func rStopsRecordingWhenAlreadyRecording() throws {
        let sim = try bootedSim()
        let state = AppState(
            simulators: [sim],
            recordingDeviceID: sim.id,
            recordingPath: URL(fileURLWithPath: "/tmp/x.mp4")
        )
        let out = Reducer.reduce(state, .key(.char("r")))
        #expect(out.effects == [.stopRecording])
    }

    @Test("It should stop recording instead of quitting when q is pressed mid-recording")
    func qDuringRecordingStopsInsteadOfQuitting() throws {
        let sim = try bootedSim()
        let state = AppState(
            simulators: [sim],
            recordingDeviceID: sim.id,
            recordingPath: URL(fileURLWithPath: "/tmp/x.mp4")
        )
        let out = Reducer.reduce(state, .key(.char("q")))
        #expect(out.effects == [.stopRecording])
        #expect(!out.state.isQuitting)
    }

    @Test("It should capture a screenshot when p is pressed and the simulator is booted")
    func pCapturesScreenshotWhenBooted() throws {
        let sim = try bootedSim()
        let state = AppState(simulators: [sim])
        let out = Reducer.reduce(state, .key(.char("p")))
        #expect(out.effects == [.captureScreenshot(sim.id)])
    }

    @Test("It should record the recording device id when recordingStarted fires")
    func recordingStartedSetsState() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/r.mp4")
        let out = Reducer.reduce(AppState(), .recordingStarted(id, url))
        #expect(out.state.recordingDeviceID == id)
        #expect(out.state.recordingPath == url)
        #expect(out.state.isRecording)
    }

    @Test("It should clear the recording state and refresh when the recording stops")
    func recordingStoppedClearsAndRefreshes() {
        let id = UUID()
        let url = URL(fileURLWithPath: "/tmp/r.mp4")
        let state = AppState(recordingDeviceID: id, recordingPath: url)
        let out = Reducer.reduce(state, .recordingStopped(url))
        #expect(out.state.recordingDeviceID == nil)
        #expect(out.state.recordingPath == nil)
        #expect(out.effects == [.refresh])
        #expect(out.state.statusMessage?.contains("Saved") ?? false)
    }

    @Test("It should refresh on every poll tick when nothing else is happening")
    func pollTickRefreshesWhenIdle() {
        let out = Reducer.reduce(AppState(), .pollTick)
        #expect(out.effects == [.refresh])
    }

    @Test("It should suppress polling while a recording is active")
    func pollTickSuppressedWhileRecording() {
        let state = AppState(recordingDeviceID: UUID(), recordingPath: URL(fileURLWithPath: "/tmp/r.mp4"))
        let out = Reducer.reduce(state, .pollTick)
        #expect(out.effects == [])
    }
}
