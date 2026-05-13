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

struct ReducerEdgeCaseTests {

    @Test("It should resize the canvas on .resized events")
    func resizedUpdatesDimensions() {
        // Given
        let state = AppState(rows: 10, cols: 40)

        // When
        let out = Reducer.reduce(state, .resized(rows: 50, cols: 120))

        // Then
        #expect(out.state.rows == 50)
        #expect(out.state.cols == 120)
    }

    @Test("It should surface the message on .refreshFailed without quitting")
    func refreshFailedSetsError() {
        // When
        let out = Reducer.reduce(AppState(), .refreshFailed("offline"))

        // Then
        #expect(out.state.lastError == "offline")
        #expect(!out.state.isQuitting)
    }

    @Test("It should clear recording state on .recordingFailed and surface the error")
    func recordingFailedClearsState() {
        // Given
        let state = AppState(
            recordingDeviceID: UUID(),
            recordingPath: URL(fileURLWithPath: "/tmp/r.mp4")
        )

        // When
        let out = Reducer.reduce(state, .recordingFailed("nope"))

        // Then
        #expect(out.state.recordingDeviceID == nil)
        #expect(out.state.recordingPath == nil)
        #expect(out.state.lastError == "nope")
    }

    @Test("It should surface a screenshot path in the status bar on .screenshotSaved")
    func screenshotSavedSetsStatus() {
        // Given
        let url = URL(fileURLWithPath: "/tmp/shot.png")

        // When
        let out = Reducer.reduce(AppState(), .screenshotSaved(url))

        // Then
        #expect(out.state.statusMessage?.contains("shot.png") ?? false)
    }

    @Test("It should record the error on .screenshotFailed")
    func screenshotFailedSetsError() {
        // When
        let out = Reducer.reduce(AppState(), .screenshotFailed("not booted"))

        // Then
        #expect(out.state.lastError == "not booted")
    }

    @Test("It should refresh after an operation fails so the next state is consistent")
    func operationFailedTriggersRefresh() {
        // Given
        let id = UUID()
        let state = AppState(pendingOperations: [id])

        // When
        let out = Reducer.reduce(state, .operationFailed(id, "boom"))

        // Then
        #expect(!out.state.pendingOperations.contains(id))
        #expect(out.state.lastError == "boom")
        #expect(out.effects == [.refresh])
    }

    @Test("It should drop the wizard and surface the error on .targetsFailed")
    func targetsFailedClearsWizard() {
        // Given
        let state = AppState(modal: .createWizard(CreateWizard()))

        // When
        let out = Reducer.reduce(state, .targetsFailed("unavailable"))

        // Then
        #expect(out.state.modal == nil)
        #expect(out.state.lastError == "unavailable")
    }

    @Test("It should set a refreshing status on R")
    func capitalRRequestsRefresh() {
        // When
        let out = Reducer.reduce(AppState(), .key(.char("R")))

        // Then
        #expect(out.effects == [.refresh])
        #expect(out.state.statusMessage == "Refreshing…")
    }

    @Test("It should ignore unrelated keys")
    func unrelatedKeyIsNoop() {
        // Given
        let state = AppState()

        // When
        let out = Reducer.reduce(state, .key(.char("z")))

        // Then
        #expect(out.state == state)
        #expect(out.effects == [])
    }
}
