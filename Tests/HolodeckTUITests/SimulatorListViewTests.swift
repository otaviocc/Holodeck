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

final class SimulatorListViewTests: XCTestCase {

    func testRenderContainsSimulatorNamesAndState() throws {
        let sim = try Simulator(
            id: XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
            name: "iPhone 16 Pro",
            runtime: XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro"),
            state: .booted,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
        let state = AppState(simulators: [sim], rows: 10, cols: 80)
        let frame = SimulatorListView.render(state)
        let plain = SimulatorListView.stripANSI(frame)
        XCTAssertTrue(plain.contains("iPhone 16 Pro"))
        XCTAssertTrue(plain.contains("Booted"))
        XCTAssertTrue(plain.contains("iOS 18.2"))
        XCTAssertTrue(plain.contains("holodeck"))
    }

    func testRenderShowsEmptyMessageWhenNoSimulators() {
        let state = AppState(rows: 10, cols: 80)
        let frame = SimulatorListView.render(state)
        let plain = SimulatorListView.stripANSI(frame)
        XCTAssertTrue(plain.contains("(no simulators)"))
    }

    func testRenderHighlightsSelectedRow() throws {
        let sim = try Simulator(
            id: UUID(),
            name: "Alpha",
            runtime: XCTUnwrap(Runtime(identifier: "com.apple.CoreSimulator.SimRuntime.iOS-18-2")),
            deviceType: DeviceType(identifier: "x"),
            state: .shutdown,
            isAvailable: true,
            dataPath: nil,
            logPath: nil
        )
        let state = AppState(simulators: [sim], selectedIndex: 0, rows: 10, cols: 80)
        let frame = SimulatorListView.render(state)
        XCTAssertTrue(frame.contains("› Alpha"))
    }
}
