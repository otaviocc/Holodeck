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

import Darwin
import Foundation
import HolodeckCore
import HolodeckServices

public final class HolodeckApp {

    private let service: SimulatorService
    private let recording: RecordingService
    private let screenshots: ScreenshotService
    private let appearance: AppearanceService
    private let terminal = TerminalMode()
    private let parser = InputParser()
    private var state = AppState()
    private var signalSources: [DispatchSourceSignal] = []

    public init(
        service: SimulatorService = SimulatorService(),
        recording: RecordingService = RecordingService(),
        screenshots: ScreenshotService = ScreenshotService(),
        appearance: AppearanceService = AppearanceService()
    ) {
        self.service = service
        self.recording = recording
        self.screenshots = screenshots
        self.appearance = appearance
    }

    public func run() async {
        installSignalCleanup()
        let size = TerminalSize.current()
        state.rows = size.rows
        state.cols = size.cols

        enterScreen()
        defer { exitScreen() }

        terminal.enterRaw()
        defer { terminal.restore() }

        let (eventStream, eventContinuation) = AsyncStream<AppEvent>.makeStream(bufferingPolicy: .unbounded)

        let inputTask = AppSpawn.inputTask(parser: parser, continuation: eventContinuation)
        let pollTask = AppSpawn.pollTask(continuation: eventContinuation)
        let resizeTask = installResizeHandler(continuation: eventContinuation)

        await AppSpawn.kickoffRefresh(service: service, continuation: eventContinuation)

        render()

        for await event in eventStream {
            let output = Reducer.reduce(state, event)
            state = output.state
            for effect in output.effects {
                dispatch(effect, continuation: eventContinuation)
            }
            render()
            if state.isQuitting { break }
        }

        if await recording.isRecording {
            _ = await recording.stop()
        }

        inputTask.cancel()
        pollTask.cancel()
        resizeTask.cancel()
        eventContinuation.finish()
    }

    private func dispatch(
        _ effect: ReducerOutput.SideEffect,
        continuation: AsyncStream<AppEvent>.Continuation
    ) {
        switch effect {
        case let .boot(id):
            AppSpawn.boot(service: service, id: id, continuation: continuation)
        case let .shutdown(id):
            AppSpawn.shutdown(service: service, id: id, continuation: continuation)
        case .refresh:
            AppSpawn.refresh(service: service, continuation: continuation)
        case let .startRecording(id):
            AppSpawn.startRecording(recording: recording, id: id, continuation: continuation)
        case .stopRecording:
            AppSpawn.stopRecording(recording: recording, continuation: continuation)
        case let .captureScreenshot(id):
            AppSpawn.screenshot(screenshots: screenshots, id: id, continuation: continuation)
        case let .setAppearance(id, value):
            AppSpawn.appearance(service: appearance, id: id, appearance: value, continuation: continuation)
        }
    }

    private func installResizeHandler(continuation: AsyncStream<AppEvent>.Continuation) -> Task<Void, Never> {
        signal(SIGWINCH, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGWINCH, queue: .global())
        source.setEventHandler {
            let size = TerminalSize.current()
            continuation.yield(.resized(rows: size.rows, cols: size.cols))
        }
        source.resume()
        return Task {
            await withTaskCancellationHandler {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            } onCancel: {
                source.cancel()
            }
        }
    }

    private func installSignalCleanup() {
        signal(SIGINT, SIG_IGN)
        signal(SIGTERM, SIG_IGN)
        let int = DispatchSource.makeSignalSource(signal: SIGINT, queue: .global())
        int.setEventHandler { [weak self] in
            self?.exitScreen()
            self?.terminal.restore()
            Darwin.exit(130)
        }
        int.resume()
        let term = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .global())
        term.setEventHandler { [weak self] in
            self?.exitScreen()
            self?.terminal.restore()
            Darwin.exit(143)
        }
        term.resume()
        signalSources.append(int)
        signalSources.append(term)
    }

    private func enterScreen() {
        write(ANSI.enterAltScreen)
        write(ANSI.hideCursor)
        write(ANSI.clearScreen)
        write(ANSI.home)
    }

    private func exitScreen() {
        write(ANSI.showCursor)
        write(ANSI.exitAltScreen)
    }

    private func render() {
        let body = SimulatorListView.render(state)
        write(ANSI.home + ANSI.clearScreen + body)
    }

    private func write(_ text: String) {
        text.withCString { ptr in
            _ = Darwin.write(STDOUT_FILENO, ptr, strlen(ptr))
        }
    }
}
