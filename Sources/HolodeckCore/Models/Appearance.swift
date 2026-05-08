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

public enum Appearance: String, Sendable, CaseIterable {

    case light
    case dark
}

public enum BatteryState: String, Sendable, CaseIterable {

    case charging
    case charged
    case discharging
}

public struct StatusBarOverrides: Sendable, Equatable {

    // MARK: - Properties

    public var time: String?
    public var batteryState: BatteryState?
    public var batteryLevel: Int?
    public var wifiBars: Int?
    public var cellularBars: Int?
    public var operatorName: String?

    // MARK: - Lifecycle

    public init(
        time: String? = nil,
        batteryState: BatteryState? = nil,
        batteryLevel: Int? = nil,
        wifiBars: Int? = nil,
        cellularBars: Int? = nil,
        operatorName: String? = nil
    ) {
        self.time = time
        self.batteryState = batteryState
        self.batteryLevel = batteryLevel
        self.wifiBars = wifiBars
        self.cellularBars = cellularBars
        self.operatorName = operatorName
    }

    // MARK: - Public

    public var isEmpty: Bool {
        time == nil
            && batteryState == nil
            && batteryLevel == nil
            && wifiBars == nil
            && cellularBars == nil
            && operatorName == nil
    }

    public var simctlArguments: [String] {
        var args: [String] = []
        if let time { args += ["--time", time] }
        if let batteryState { args += ["--batteryState", batteryState.rawValue] }
        if let batteryLevel { args += ["--batteryLevel", String(batteryLevel)] }
        if let wifiBars { args += ["--wifiBars", String(wifiBars)] }
        if let cellularBars { args += ["--cellularBars", String(cellularBars)] }
        if let operatorName { args += ["--operatorName", operatorName] }
        return args
    }
}
