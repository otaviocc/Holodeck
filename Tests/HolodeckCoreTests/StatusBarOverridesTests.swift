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

import Testing
@testable import HolodeckCore

struct StatusBarOverridesTests {

    @Test("It should report isEmpty when no fields are set")
    func emptyOverrides() {
        // Given
        let overrides = StatusBarOverrides()

        // Then
        #expect(overrides.isEmpty)
        #expect(overrides.simctlArguments == [])
    }

    @Test("It should report not-empty when any field is set")
    func nonEmptyOverrides() {
        // Given
        let overrides = StatusBarOverrides(time: "9:41")

        // Then
        #expect(!overrides.isEmpty)
    }

    @Test("It should emit every set field as a --flag value pair in canonical order")
    func simctlArgumentsCanonicalOrder() {
        // Given
        let overrides = StatusBarOverrides(
            time: "9:41",
            batteryState: .discharging,
            batteryLevel: 75,
            wifiBars: 3,
            cellularBars: 4,
            operatorName: "Carrier"
        )

        // When
        let args = overrides.simctlArguments

        // Then
        #expect(args == [
            "--time", "9:41",
            "--batteryState", "discharging",
            "--batteryLevel", "75",
            "--wifiBars", "3",
            "--cellularBars", "4",
            "--operatorName", "Carrier"
        ])
    }

    @Test("It should omit unset fields from simctlArguments")
    func simctlArgumentsOmitsUnset() {
        // Given
        let overrides = StatusBarOverrides(batteryLevel: 50)

        // Then
        #expect(overrides.simctlArguments == ["--batteryLevel", "50"])
    }
}
