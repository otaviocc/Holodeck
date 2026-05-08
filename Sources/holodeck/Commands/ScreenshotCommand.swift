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

import ArgumentParser
import Foundation
import HolodeckCore
import HolodeckServices

struct ScreenshotCommand: AsyncParsableCommand {

    // MARK: - Properties

    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Capture a screenshot from a booted simulator."
    )

    @Argument(help: "Simulator name or UDID.")
    var query: String

    @Option(name: .shortAndLong, help: "Output file path (default: ~/Screenshots/sim_screenshot_<ts>.<ext>).")
    var output: String?

    @Option(help: "Image type: png, jpeg, tiff, bmp. Defaults to value from ~/.config/holodeck/config.json.")
    var type: ScreenshotType?

    // MARK: - Public

    func run() async throws {
        let config = ConfigLoader.loadOrDefault()
        let imageType = type ?? config.screenshotType
        let service = SimulatorService()
        let sim = try await service.resolveInState(
            query, .booted, purpose: "only booted simulators can be captured"
        )
        let screenshots = ScreenshotService()
        let outURL = output.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
            ?? DefaultMediaPath.screenshot(in: config.resolvedScreenshotsDirectory, type: imageType)
        let path = try await screenshots.capture(udid: sim.id, output: outURL, type: imageType)
        print(path.path)
    }
}
