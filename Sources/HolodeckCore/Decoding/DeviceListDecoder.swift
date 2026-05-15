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

public enum DeviceListDecoder {

    // MARK: - Nested types

    private struct RawList: Decodable {

        let devices: [String: [RawDevice]]
    }

    private struct RawDevice: Decodable {

        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool
        let deviceTypeIdentifier: String?
        let dataPath: String?
        let logPath: String?
    }

    private struct RawTargets: Decodable {

        let devicetypes: [RawDeviceType]?
        let runtimes: [RawRuntime]?
    }

    private struct RawDeviceType: Decodable {

        let identifier: String
        let name: String
    }

    private struct RawRuntime: Decodable {

        let identifier: String
        let name: String
        let version: String?
        let isAvailable: Bool?
    }

    // MARK: - Properties

    private static let decoder = JSONDecoder()

    // MARK: - Public

    public static func decodeAvailableTargets(_ data: Data) throws -> AvailableTargets {
        let raw = try decoder.decode(RawTargets.self, from: data)
        let deviceTypes = (raw.devicetypes ?? []).map { DeviceType(identifier: $0.identifier, name: $0.name) }
        let runtimes = (raw.runtimes ?? []).compactMap { rawRuntime -> Runtime? in
            guard rawRuntime.isAvailable ?? true else { return nil }
            return Runtime(identifier: rawRuntime.identifier, versionString: rawRuntime.version)
        }
        return AvailableTargets(deviceTypes: deviceTypes, runtimes: runtimes)
    }

    public static func decode(_ data: Data) throws -> [Simulator] {
        let raw = try decoder.decode(RawList.self, from: data)
        var result: [Simulator] = []
        for (runtimeId, devices) in raw.devices {
            guard let runtime = Runtime(identifier: runtimeId) else { continue }
            for device in devices {
                guard let udid = UUID(uuidString: device.udid) else { continue }
                guard let state = SimulatorState(rawValue: device.state) else { continue }
                let deviceType = DeviceType(identifier: device.deviceTypeIdentifier ?? "")
                result.append(Simulator(
                    id: udid,
                    name: device.name,
                    runtime: runtime,
                    deviceType: deviceType,
                    state: state,
                    isAvailable: device.isAvailable,
                    dataPath: device.dataPath.map { URL(fileURLWithPath: $0) },
                    logPath: device.logPath.map { URL(fileURLWithPath: $0) }
                ))
            }
        }
        return result
    }
}
