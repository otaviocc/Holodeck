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

struct PrivacyCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "privacy",
        abstract: "Grant, revoke, or reset a privacy permission for a bundle ID."
    )

    @Argument(help: "Simulator name or UDID.")
    var query: String

    @Argument(help: "Action: grant, revoke, reset.")
    var action: PrivacyAction

    @Argument(
        help: "Permission: all, calendar, contacts, contacts-limited, location, location-always, photos, photos-add, media-library, microphone, motion, reminders, siri."
    )
    var permission: PrivacyPermission

    @Argument(help: "Bundle identifier (required for grant/revoke; optional for reset).")
    var bundleID: String?

    func validate() throws {
        if action != .reset, bundleID == nil {
            throw ValidationError("\(action.rawValue) requires a bundle identifier.")
        }
    }

    func run() async throws {
        let service = SimulatorService()
        let sim = try await service.resolveInState(
            query, .booted, purpose: "the simulator must be booted"
        )
        try await PrivacyService().apply(
            udid: sim.id,
            action: action,
            permission: permission,
            bundleID: bundleID
        )
        let target = bundleID.map { " for \($0)" } ?? ""
        print("\(action.rawValue.capitalized) \(permission.rawValue)\(target) on \(sim.name).")
    }
}
