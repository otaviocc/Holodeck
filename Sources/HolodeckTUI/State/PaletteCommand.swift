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

public enum PaletteCommand: String, CaseIterable, Sendable {

    case appearance
    case boot
    case delete
    case erase
    case focus
    case inspect
    case new
    case open
    case privacy
    case record
    case screenshot
    case shutdown

    // MARK: - Public

    /// Alphabetical ordering used for deterministic ghost-autocomplete matching.
    public static let all: [PaletteCommand] = allCases.sorted { $0.displayName < $1.displayName }

    public var displayName: String {
        rawValue
    }

    public var description: String {
        switch self {
        case .appearance: "Switch the booted simulator between light and dark"
        case .boot: "Boot the selected simulator"
        case .delete: "Delete the selected simulator"
        case .erase: "Erase the selected (shutdown) simulator"
        case .focus: "Bring Simulator.app to the front for the selection"
        case .inspect: "Open the inspector for the selected simulator"
        case .new: "Create a new simulator (wizard)"
        case .open: "Open a URL or deep link on the booted simulator"
        case .privacy: "Grant or revoke privacy permissions for an app"
        case .record: "Start screen recording on the booted simulator"
        case .screenshot: "Capture a screenshot of the booted simulator"
        case .shutdown: "Shut down the selected simulator"
        }
    }

    public func isApplicable(to simulator: Simulator?, isRecording: Bool) -> Bool {
        switch self {
        case .new:
            true
        case .focus, .inspect, .delete:
            simulator != nil
        case .boot:
            simulator?.state == .shutdown
        case .shutdown:
            simulator?.state == .booted
        case .erase:
            simulator?.state == .shutdown
        case .record:
            simulator?.state == .booted && !isRecording
        case .screenshot, .appearance, .open, .privacy:
            simulator?.state == .booted
        }
    }

    /// Case-insensitive prefix match. An empty prefix matches every command.
    public func matches(prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        return displayName.lowercased().hasPrefix(prefix.lowercased())
    }
}
