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
            return confirm(
                state: next,
                id: id,
                key: key,
                status: "Erasing…",
                operation: .erase,
                effect: .eraseSimulator(id)
            )
        case let .confirmDelete(id):
            return confirm(
                state: next,
                id: id,
                key: key,
                status: "Deleting…",
                operation: .delete,
                effect: .deleteSimulator(id)
            )
        case let .createWizard(wizard):
            return WizardReducer.handle(state: next, wizard: wizard, key: key)
        case let .privacyWizard(wizard):
            return PrivacyWizardReducer.handle(state: next, wizard: wizard, key: key)
        case .inspector:
            next.modal = nil
            return ReducerOutput(state: next)
        case let .openURL(prompt):
            return OpenURLModalReducer.handle(state: next, prompt: prompt, key: key)
        case let .commandPalette(palette):
            return CommandPaletteReducer.handle(state: next, palette: palette, key: key)
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
        operation: PendingOperation,
        effect: ReducerOutput.SideEffect
    ) -> ReducerOutput {
        var next = state
        switch key {
        case .char("y"), .char("Y"):
            next.modal = nil
            // Don't clobber an unrelated in-flight intent (e.g. a pending
            // .boot when the user confirms .delete). The sibling reducers
            // at Reducer.swift apply the same guard on their own paths.
            guard next.pendingOperations[id] == nil else {
                next.statusMessage = "Simulator already has a pending operation"
                return ReducerOutput(state: next)
            }
            next.statusMessage = status
            next.pendingOperations[id] = operation
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
            // Esc clears the filter as long as it is live on the visible step
            // (focused, or has a non-empty query). Only closes the modal when
            // there's nothing filter-shaped left to dismiss.
            let filterIsLive = wizard.isDeviceTypeFilterFocused || !wizard.deviceTypeFilter.isEmpty
            if wizard.step == .pickDeviceType, filterIsLive {
                updated.isDeviceTypeFilterFocused = false
                updated.deviceTypeFilter = ""
                updated.deviceTypeIndex = 0
                updated.deviceTypeScrollOffset = 0
                next.modal = .createWizard(updated)
                return ReducerOutput(state: next)
            }
            next.modal = nil
            return ReducerOutput(state: next)
        }
        let viewport = CreateWizard.viewport(rows: state.rows)
        switch wizard.step {
        case .loading:
            return ReducerOutput(state: next)
        case .pickDeviceType:
            if wizard.isDeviceTypeFilterFocused {
                switch key {
                case .enter:
                    updated.isDeviceTypeFilterFocused = false
                case .backspace:
                    if !updated.deviceTypeFilter.isEmpty { updated.deviceTypeFilter.removeLast() }
                    updated.deviceTypeIndex = 0
                    updated.deviceTypeScrollOffset = 0
                case let .char(character) where TextInput.isPrintable(character):
                    updated.deviceTypeFilter.append(character)
                    updated.deviceTypeIndex = 0
                    updated.deviceTypeScrollOffset = 0
                default:
                    break
                }
                next.modal = .createWizard(updated)
                return ReducerOutput(state: next)
            }
            switch key {
            case .up, .char("k"):
                updated.deviceTypeIndex = max(0, updated.deviceTypeIndex - 1)
            case .down, .char("j"):
                let lastIndex = Swift.max(0, updated.visibleDeviceTypes.count - 1)
                updated.deviceTypeIndex = min(lastIndex, updated.deviceTypeIndex + 1)
            case .char("/"):
                updated.isDeviceTypeFilterFocused = true
                // Preserve an existing filter so the user can keep editing —
                // Esc is the affordance for clearing. Only reset cursor/scroll
                // when entering edit mode fresh (no query yet).
                if updated.deviceTypeFilter.isEmpty {
                    updated.deviceTypeIndex = 0
                    updated.deviceTypeScrollOffset = 0
                }
            case .enter:
                guard updated.selectedDeviceType != nil else { return ReducerOutput(state: next) }
                updated.step = .pickRuntime
            default: break
            }
            updated.deviceTypeScrollOffset = AppState.scroll(
                offset: updated.deviceTypeScrollOffset,
                index: updated.deviceTypeIndex,
                viewport: updated.deviceTypeViewport(rows: state.rows)
            )
        case .pickRuntime:
            switch key {
            case .up, .char("k"):
                updated.runtimeIndex = max(0, updated.runtimeIndex - 1)
            case .down, .char("j"):
                updated.runtimeIndex = min(max(0, updated.runtimes.count - 1), updated.runtimeIndex + 1)
            case .enter:
                guard updated.selectedRuntime != nil else { return ReducerOutput(state: next) }
                updated.step = .confirm
            case .char("b"):
                updated.step = .pickDeviceType
            default: break
            }
            updated.runtimeScrollOffset = AppState.scroll(
                offset: updated.runtimeScrollOffset,
                index: updated.runtimeIndex,
                viewport: viewport
            )
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
