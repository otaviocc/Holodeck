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

public struct Simulator: Sendable, Equatable, Identifiable {

    // MARK: - Properties

    public let id: UUID
    public let name: String
    public let runtime: Runtime
    public let deviceType: DeviceType
    public let state: SimulatorState
    public let isAvailable: Bool
    public let dataPath: URL?
    public let logPath: URL?

    // MARK: - Lifecycle

    public init(
        id: UUID,
        name: String,
        runtime: Runtime,
        deviceType: DeviceType,
        state: SimulatorState,
        isAvailable: Bool,
        dataPath: URL?,
        logPath: URL?
    ) {
        self.id = id
        self.name = name
        self.runtime = runtime
        self.deviceType = deviceType
        self.state = state
        self.isAvailable = isAvailable
        self.dataPath = dataPath
        self.logPath = logPath
    }
}
