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

public struct HolodeckConfigResolver: Sendable {

    // MARK: - Properties

    package var base: @Sendable () -> URL
    package var file: @Sendable (_ fileName: ConfigFileName) -> URL

    // MARK: - Lifecycle

    package init(
        base: @Sendable @escaping () -> URL,
        file: @Sendable @escaping (_ fileName: ConfigFileName) -> URL
    ) {
        self.base = base
        self.file = file
    }
}

public extension HolodeckConfigResolver {

    /// Resolves the on-disk directory where holodeck stores user state, honoring
    /// `$XDG_CONFIG_HOME` when set and falling back to `~/.config`.
    static func live(
        processInfo: ProcessInfo = .processInfo,
        fileManager: FileManager = .default
    ) -> Self {
        let xdg = processInfo.environment["XDG_CONFIG_HOME"]
        let home = fileManager.homeDirectoryForCurrentUser
        let parent = xdg.map {
            URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath)
        } ?? home.appendingPathComponent(".config")
        let base = parent.appendingPathComponent("holodeck")

        return Self(
            base: { base },
            file: { fileName in
                base.appendingPathComponent(fileName.rawValue)
            }
        )
    }
}
