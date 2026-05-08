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

struct LocaleCommand: AsyncParsableCommand {

    // MARK: - Properties

    static let configuration = CommandConfiguration(
        commandName: "locale",
        abstract: "Set the simulator locale and language (BCP-47 tag). Requires reboot to take effect."
    )

    @Argument(help: "Simulator name or UDID.")
    var query: String

    @Argument(help: "BCP-47 tag, e.g. en, en-US, pt-BR.")
    var tag: String

    // MARK: - Public

    func run() async throws {
        let service = SimulatorService()
        let sim = try await service.resolveInState(
            query, .booted, purpose: "locale can only be set on booted simulators"
        )
        try await LocaleService().set(udid: sim.id, bcp47: tag)
        print("Set \(sim.name) locale to \(tag). Reboot the simulator for changes to take effect.")
    }
}
