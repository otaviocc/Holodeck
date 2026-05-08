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

struct DeleteCommand: AsyncParsableCommand {

    // MARK: - Properties

    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete a simulator, or all simulators whose runtime is no longer available."
    )

    @Argument(help: "Simulator name or UDID. Omit when using --unavailable.")
    var query: String?

    @Flag(name: .long, help: "Delete all simulators whose runtime is unavailable.")
    var unavailable = false

    @Flag(name: .shortAndLong, help: "Skip the confirmation prompt.")
    var yes = false

    // MARK: - Public

    func run() async throws {
        let service = SimulatorService()
        if unavailable {
            guard ConfirmPrompt.confirm("Delete all simulators with unavailable runtimes?", skip: yes) else {
                print("Aborted.")
                return
            }
            try await service.deleteUnavailable()
            print("Deleted unavailable simulators.")
            return
        }
        guard let query else {
            throw ValidationError("Provide a simulator name/UDID or --unavailable.")
        }
        let sim = try await service.resolve(query: query)
        guard ConfirmPrompt.confirm("Delete \(sim.name) (\(sim.id.uuidString))?", skip: yes) else {
            print("Aborted.")
            return
        }
        try await service.delete(sim.id)
        print("Deleted \(sim.name).")
    }
}
