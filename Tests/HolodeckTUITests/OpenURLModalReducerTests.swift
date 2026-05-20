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

struct OpenURLModalReducerTests {

    private func sim(state: SimulatorState = .booted) throws -> Simulator {
        try Simulator(
            id: UUID(),
            name: "iPhone 16",
            runtime: #require(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16"),
            state: state,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
    }

    @Test("It should open the URL modal on o when a booted simulator is selected")
    func oOpensModalOnBooted() throws {
        // Given
        let device = try sim(state: .booted)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("o")))

        // Then
        guard case let .openURL(prompt) = out.state.modal else {
            Issue.record("Expected openURL modal")
            return
        }
        #expect(prompt.simulatorID == device.id)
        #expect(prompt.url.isEmpty)
        #expect(prompt.historyIndex == -1)
    }

    @Test("It should refuse to open the URL modal when the simulator is shut down")
    func oRefusesOnShutdown() throws {
        // Given
        let device = try sim(state: .shutdown)
        let state = AppState(simulators: [device])

        // When
        let out = Reducer.reduce(state, .key(.char("o")))

        // Then
        #expect(out.state.modal == nil)
    }

    @Test("It should append printable characters and reset history index")
    func typingAppendsAndResetsHistory() {
        // Given
        var prompt = OpenURLPrompt(simulatorID: UUID(), url: "")
        prompt.historyIndex = 2
        let state = AppState(modal: .openURL(prompt), urlHistory: ["a", "b", "c"])

        // When
        let after = Reducer.reduce(state, .key(.char("h"))).state

        // Then
        guard case let .openURL(updated) = after.modal else {
            Issue.record("Expected openURL modal")
            return
        }
        #expect(updated.url == "h")
        #expect(updated.historyIndex == -1)
    }

    @Test("It should trim the last character on Backspace")
    func backspaceTrimsURL() {
        // Given
        let prompt = OpenURLPrompt(simulatorID: UUID(), url: "https://")
        let state = AppState(modal: .openURL(prompt))

        // When
        let after = Reducer.reduce(state, .key(.backspace)).state

        // Then
        guard case let .openURL(updated) = after.modal else {
            Issue.record("Expected openURL modal")
            return
        }
        #expect(updated.url == "https:/")
    }

    @Test("It should recall the most recent history entry on Up")
    func upRecallsHistory() {
        // Given
        let prompt = OpenURLPrompt(simulatorID: UUID(), url: "")
        let state = AppState(modal: .openURL(prompt), urlHistory: ["one", "two", "three"])

        // When
        let after = Reducer.reduce(state, .key(.up)).state

        // Then
        guard case let .openURL(updated) = after.modal else {
            Issue.record("Expected openURL modal")
            return
        }
        #expect(updated.historyIndex == 0)
        #expect(updated.url == "one")
    }

    @Test("It should walk back to the current edit on Down")
    func downReturnsToCurrentEdit() {
        // Given
        let prompt = OpenURLPrompt(simulatorID: UUID(), url: "one", historyIndex: 0)
        let state = AppState(modal: .openURL(prompt), urlHistory: ["one", "two"])

        // When
        let after = Reducer.reduce(state, .key(.down)).state

        // Then
        guard case let .openURL(updated) = after.modal else {
            Issue.record("Expected openURL modal")
            return
        }
        #expect(updated.historyIndex == -1)
        #expect(updated.url.isEmpty)
    }

    @Test("It should ignore Enter on an empty URL")
    func enterIgnoresEmpty() {
        // Given
        let prompt = OpenURLPrompt(simulatorID: UUID(), url: "")
        let state = AppState(modal: .openURL(prompt))

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then
        #expect(out.effects.isEmpty)
        guard case let .openURL(updated) = out.state.modal else {
            Issue.record("Expected modal to stay open")
            return
        }
        #expect(updated.isSubmitting == false)
    }

    @Test("It should emit openURL and set isSubmitting on Enter with a non-empty URL")
    func enterEmitsOpenURL() {
        // Given
        let id = UUID()
        let prompt = OpenURLPrompt(simulatorID: id, url: "https://apple.com")
        let state = AppState(modal: .openURL(prompt))

        // When
        let out = Reducer.reduce(state, .key(.enter))

        // Then
        #expect(out.effects == [.openURL(udid: id, url: "https://apple.com")])
        guard case let .openURL(updated) = out.state.modal else {
            Issue.record("Expected modal to stay open while submitting")
            return
        }
        #expect(updated.isSubmitting == true)
    }

    @Test("It should close the modal and update urlHistory on urlOpened")
    func urlOpenedClosesAndPersists() {
        // Given
        let prompt = OpenURLPrompt(simulatorID: UUID(), url: "https://apple.com", isSubmitting: true)
        let state = AppState(modal: .openURL(prompt))

        // When
        let out = Reducer.reduce(state, .urlOpened(url: "https://apple.com", history: ["https://apple.com"]))

        // Then
        #expect(out.state.modal == nil)
        #expect(out.state.urlHistory == ["https://apple.com"])
        #expect(out.state.statusMessage == "Opened https://apple.com")
    }

    @Test("It should keep the modal open and store the error on urlOpenFailed")
    func urlOpenFailedKeepsModal() {
        // Given
        let prompt = OpenURLPrompt(simulatorID: UUID(), url: "myapp://", isSubmitting: true)
        let state = AppState(modal: .openURL(prompt))

        // When
        let out = Reducer.reduce(state, .urlOpenFailed("no handler"))

        // Then
        guard case let .openURL(updated) = out.state.modal else {
            Issue.record("Expected modal to stay open")
            return
        }
        #expect(updated.isSubmitting == false)
        #expect(updated.error == "no handler")
    }

    @Test("It should populate urlHistory from urlHistoryLoaded without setting a status")
    func loadedPopulatesHistorySilently() {
        // Given
        let state = AppState()

        // When
        let out = Reducer.reduce(state, .urlHistoryLoaded(["https://a", "https://b"]))

        // Then
        #expect(out.state.urlHistory == ["https://a", "https://b"])
        #expect(out.state.statusMessage == nil)
    }
}
