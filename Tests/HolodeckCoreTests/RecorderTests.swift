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

import XCTest
@testable import HolodeckCore

final class RecorderTests: XCTestCase {

    func testStartAndStopInterruptsLongRunningProcess() async throws {
        let recorder = Recorder()
        try await recorder.start(launchPath: "/bin/sleep", arguments: ["30"])
        var running = await recorder.isRunning
        XCTAssertTrue(running)
        let started = Date()
        await recorder.stop()
        let elapsed = Date().timeIntervalSince(started)
        running = await recorder.isRunning
        XCTAssertFalse(running)
        XCTAssertLessThan(elapsed, 5.0, "stop() should interrupt promptly, took \(elapsed)s")
    }

    func testStopWithoutStartIsNoop() async {
        let recorder = Recorder()
        await recorder.stop()
        let running = await recorder.isRunning
        XCTAssertFalse(running)
    }
}
