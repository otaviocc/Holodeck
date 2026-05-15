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

enum ModalReducer {

    // MARK: - Public

    static func handle(state: AppState, key: Key) -> ReducerOutput {
        var next = state
        switch state.modal {
        case .appearance:
            return appearance(state: next, key: key)
        case let .confirmErase(id):
            return confirm(state: next, id: id, key: key, status: "Erasing…", effect: .eraseSimulator(id))
        case let .confirmDelete(id):
            return confirm(state: next, id: id, key: key, status: "Deleting…", effect: .deleteSimulator(id))
        case let .createWizard(wizard):
            return WizardReducer.handle(state: next, wizard: wizard, key: key)
        case let .privacyWizard(wizard):
            return PrivacyWizardReducer.handle(state: next, wizard: wizard, key: key)
        case .help:
            next.modal = nil
            return ReducerOutput(state: next)
        case .none:
            next.modal = nil
            return ReducerOutput(state: next)
        }
    }

    // MARK: - Private

    private static func appearance(state: AppState, key: Key) -> ReducerOutput {
        var next = state
        switch key {
        case .char("l"):
            guard let sim = next.selectedSimulator else {
                next.modal = nil
                return ReducerOutput(state: next)
            }
            next.modal = nil
            next.statusMessage = "Setting appearance to light…"
            return ReducerOutput(state: next, effects: [.setAppearance(sim.id, .light)])
        case .char("d"):
            guard let sim = next.selectedSimulator else {
                next.modal = nil
                return ReducerOutput(state: next)
            }
            next.modal = nil
            next.statusMessage = "Setting appearance to dark…"
            return ReducerOutput(state: next, effects: [.setAppearance(sim.id, .dark)])
        case .escape, .char("q"):
            next.modal = nil
            return ReducerOutput(state: next)
        default:
            return ReducerOutput(state: next)
        }
    }

    private static func confirm(
        state: AppState,
        id: UUID,
        key: Key,
        status: String,
        effect: ReducerOutput.SideEffect
    ) -> ReducerOutput {
        var next = state
        switch key {
        case .char("y"), .char("Y"):
            next.modal = nil
            next.statusMessage = status
            next.pendingOperations.insert(id)
            return ReducerOutput(state: next, effects: [effect])
        case .char("n"), .char("N"), .escape, .char("q"):
            next.modal = nil
            return ReducerOutput(state: next)
        default:
            return ReducerOutput(state: next)
        }
    }
}

enum WizardReducer {

    // swiftlint:disable function_body_length
    static func handle(state: AppState, wizard: CreateWizard, key: Key) -> ReducerOutput {
        var next = state
        var updated = wizard
        if case .escape = key {
            next.modal = nil
            return ReducerOutput(state: next)
        }
        let viewport = CreateWizard.viewport(rows: state.rows)
        switch wizard.step {
        case .loading:
            return ReducerOutput(state: next)
        case .pickDeviceType:
            switch key {
            case .up, .char("k"):
                updated.deviceTypeIndex = max(0, updated.deviceTypeIndex - 1)
                if updated.deviceTypeIndex < updated.deviceTypeScrollOffset {
                    updated.deviceTypeScrollOffset = updated.deviceTypeIndex
                }
            case .down, .char("j"):
                updated.deviceTypeIndex = min(max(0, updated.deviceTypes.count - 1), updated.deviceTypeIndex + 1)
                if updated.deviceTypeIndex >= updated.deviceTypeScrollOffset + viewport {
                    updated.deviceTypeScrollOffset = updated.deviceTypeIndex - viewport + 1
                }
            case .enter:
                guard updated.selectedDeviceType != nil else { return ReducerOutput(state: next) }
                updated.step = .pickRuntime
            default: break
            }
        case .pickRuntime:
            switch key {
            case .up, .char("k"):
                updated.runtimeIndex = max(0, updated.runtimeIndex - 1)
                if updated.runtimeIndex < updated.runtimeScrollOffset {
                    updated.runtimeScrollOffset = updated.runtimeIndex
                }
            case .down, .char("j"):
                updated.runtimeIndex = min(max(0, updated.runtimes.count - 1), updated.runtimeIndex + 1)
                if updated.runtimeIndex >= updated.runtimeScrollOffset + viewport {
                    updated.runtimeScrollOffset = updated.runtimeIndex - viewport + 1
                }
            case .enter:
                guard updated.selectedRuntime != nil else { return ReducerOutput(state: next) }
                updated.step = .confirm
            case .char("b"):
                updated.step = .pickDeviceType
            default: break
            }
        case .confirm:
            switch key {
            case .enter, .char("y"):
                guard let deviceType = updated.selectedDeviceType,
                      let runtime = updated.selectedRuntime else { return ReducerOutput(state: next) }
                updated.step = .submitting
                updated.error = nil
                next.modal = .createWizard(updated)
                return ReducerOutput(state: next, effects: [
                    .createSimulator(name: updated.defaultName, deviceType: deviceType, runtime: runtime)
                ])
            case .char("b"):
                updated.step = .pickRuntime
                updated.error = nil
            default: break
            }
        case .submitting:
            return ReducerOutput(state: next)
        }
        next.modal = .createWizard(updated)
        return ReducerOutput(state: next)
    }
    // swiftlint:enable function_body_length
}
