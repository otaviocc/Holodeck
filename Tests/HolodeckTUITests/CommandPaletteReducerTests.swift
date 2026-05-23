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

struct CommandPaletteReducerTests {

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

    @Test("It should open the command palette on : from the main list")
    func colonOpensPalette() throws {
        let device = try sim()
        let state = AppState(simulators: [device])

        let after = Reducer.reduce(state, .key(.char(":"))).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected commandPalette modal")
            return
        }
        #expect(palette.query.isEmpty)
    }

    @Test("It should append printable characters to the query")
    func typingAppendsToQuery() throws {
        let device = try sim()
        let state = AppState(simulators: [device], modal: .commandPalette(CommandPalette()))

        var after = Reducer.reduce(state, .key(.char("a"))).state
        after = Reducer.reduce(after, .key(.char("p"))).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected palette to stay open")
            return
        }
        #expect(palette.query == "ap")
    }

    @Test("It should drop the last character on Backspace")
    func backspaceTrimsQuery() throws {
        let device = try sim()
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "scre"))
        )

        let after = Reducer.reduce(state, .key(.backspace)).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected palette to stay open")
            return
        }
        #expect(palette.query == "scr")
    }

    @Test("It should close the palette on Escape")
    func escapeClosesPalette() throws {
        let device = try sim()
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "appe"))
        )

        let after = Reducer.reduce(state, .key(.escape)).state

        #expect(after.modal == nil)
    }

    @Test("It should autocomplete the query to the top match on Tab")
    func tabAcceptsTopMatch() throws {
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "scre"))
        )

        let after = Reducer.reduce(state, .key(.tab)).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected palette to stay open")
            return
        }
        #expect(palette.query == "screenshot")
    }

    @Test("It should run screenshot on Enter against a booted simulator")
    func enterRunsScreenshot() throws {
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "screenshot"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects == [.captureScreenshot(device.id)])
        #expect(out.state.modal == nil)
    }

    @Test("It should run boot on Enter against a shutdown simulator")
    func enterRunsBoot() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "boot"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects == [.boot(device.id)])
        #expect(out.state.modal == nil)
    }

    @Test("It should hide boot from matches when the sim is already booted")
    func bootHiddenWhenBooted() throws {
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "boot"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects.isEmpty)
        #expect(out.state.modal == nil)
        #expect(out.state.lastError?.contains("No matching command") == true)
    }

    @Test("It should open the appearance modal on Enter for `appearance`")
    func enterOpensAppearanceModal() throws {
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "appearance"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects.isEmpty)
        #expect(out.state.modal == .appearance)
    }

    @Test("It should surface lastError on Enter when no applicable command matches")
    func enterWithNoMatchReportsError() throws {
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "zzz"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects.isEmpty)
        #expect(out.state.modal == nil)
        #expect(out.state.lastError == "No matching command: zzz")
    }

    @Test("It should hide record from matches while a recording is active")
    func recordHiddenWhileRecording() throws {
        let device = try sim(state: .booted)
        let state = AppState(
            simulators: [device],
            recordingDeviceID: device.id,
            modal: .commandPalette(CommandPalette(query: "record"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects.isEmpty)
        #expect(out.state.lastError?.contains("No matching command") == true)
    }

    @Test("It should close the palette on Enter with an empty query without running anything")
    func enterEmptyQueryClosesQuietly() throws {
        let device = try sim()
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette())
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects.isEmpty)
        #expect(out.state.modal == nil)
        #expect(out.state.lastError == nil)
    }

    @Test("It should capture the selected simulator id when opening via :")
    func colonCapturesSelectedSimulator() throws {
        let device = try sim()
        let state = AppState(simulators: [device])

        let after = Reducer.reduce(state, .key(.char(":"))).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected commandPalette modal")
            return
        }
        #expect(palette.simulatorID == device.id)
    }

    @Test("It should dismiss the palette on refresh when the captured simulator is gone")
    func refreshDismissesPaletteWhenSimVanishes() throws {
        let device = try sim()
        let palette = CommandPalette(simulatorID: device.id, query: "scre")
        let state = AppState(simulators: [device], modal: .commandPalette(palette))

        let after = Reducer.reduce(state, .refreshed([])).state

        #expect(after.modal == nil)
    }

    @Test("It should keep the palette across refresh when the captured simulator remains")
    func refreshKeepsPaletteWhenSimRemains() throws {
        let device = try sim()
        let palette = CommandPalette(simulatorID: device.id, query: "scre")
        let state = AppState(simulators: [device], modal: .commandPalette(palette))

        let after = Reducer.reduce(state, .refreshed([device])).state

        guard case let .commandPalette(after) = after.modal else {
            Issue.record("Expected palette to remain open")
            return
        }
        #expect(after.query == "scre")
    }

    @Test("It should surface a status message when boot runs against a pending simulator")
    func bootReportsPendingOperation() throws {
        let device = try sim(state: .shutdown)
        let state = AppState(
            simulators: [device],
            pendingOperations: [device.id],
            modal: .commandPalette(CommandPalette(query: "boot"))
        )

        let out = Reducer.reduce(state, .key(.enter))

        #expect(out.effects.isEmpty)
        #expect(out.state.modal == nil)
        #expect(out.state.statusMessage?.contains("pending operation") == true)
    }

    @Test("It should preserve the user's typed casing when Tab autocompletes")
    func tabPreservesUserCasing() throws {
        let device = try sim()
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "SCRE"))
        )

        let after = Reducer.reduce(state, .key(.tab)).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected palette to stay open")
            return
        }
        #expect(palette.query == "SCREenshot")
    }

    @Test("It should ignore Tab when no command matches the query")
    func tabNoMatchKeepsQuery() throws {
        let device = try sim()
        let state = AppState(
            simulators: [device],
            modal: .commandPalette(CommandPalette(query: "zzz"))
        )

        let after = Reducer.reduce(state, .key(.tab)).state

        guard case let .commandPalette(palette) = after.modal else {
            Issue.record("Expected palette to stay open")
            return
        }
        #expect(palette.query == "zzz")
    }
}
