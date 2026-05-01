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

struct EraseCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "erase",
        abstract: "Erase a simulator's content. The simulator must be shut down."
    )

    @Argument(help: "Simulator name or UDID. Omit when using --all.")
    var query: String?

    @Flag(name: .long, help: "Erase all shut-down simulators.")
    var all = false

    @Flag(name: .shortAndLong, help: "Skip the confirmation prompt.")
    var yes = false

    func run() async throws {
        let service = SimulatorService()
        if all {
            let sims = try await service.list().filter { $0.state == .shutdown }
            guard !sims.isEmpty else {
                print("No shut-down simulators to erase.")
                return
            }
            guard ConfirmPrompt.confirm("Erase \(sims.count) shut-down simulator(s)?", skip: yes) else {
                print("Aborted.")
                return
            }
            for sim in sims {
                try await service.erase(sim.id)
                print("Erased \(sim.name).")
            }
        } else {
            guard let query else {
                throw ValidationError("Provide a simulator name/UDID or --all.")
            }
            let sim = try await service.resolve(query: query)
            guard sim.state == .shutdown else {
                throw ValidationError("\(sim.name) is \(sim.state.rawValue); shut it down first.")
            }
            guard ConfirmPrompt.confirm("Erase \(sim.name)?", skip: yes) else {
                print("Aborted.")
                return
            }
            try await service.erase(sim.id)
            print("Erased \(sim.name).")
        }
    }
}
