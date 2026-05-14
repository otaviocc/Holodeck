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

enum PrivacyWizardReducer {

    // swiftlint:disable function_body_length
    static func handle(state: AppState, wizard: PrivacyWizard, key: Key) -> ReducerOutput {
        var next = state
        var updated = wizard
        if case .escape = key {
            next.modal = nil
            return ReducerOutput(state: next)
        }
        switch wizard.step {
        case .loadingApps:
            return ReducerOutput(state: next)
        case .pickApp:
            switch key {
            case .up, .char("k"):
                updated.appIndex = max(0, updated.appIndex - 1)
            case .down, .char("j"):
                updated.appIndex = min(max(0, updated.apps.count - 1), updated.appIndex + 1)
            case .char("s"):
                updated.showSystem.toggle()
                updated.appIndex = 0
            case .enter:
                guard updated.selectedApp != nil else { return ReducerOutput(state: next) }
                updated.step = .pickAction
            default: break
            }
        case .pickAction:
            switch key {
            case .up, .char("k"):
                updated.actionIndex = max(0, updated.actionIndex - 1)
            case .down, .char("j"):
                updated.actionIndex = min(PrivacyAction.allCases.count - 1, updated.actionIndex + 1)
            case .enter:
                updated.step = .pickPermission
            case .char("b"):
                updated.step = .pickApp
            default: break
            }
        case .pickPermission:
            switch key {
            case .up, .char("k"):
                updated.permissionIndex = max(0, updated.permissionIndex - 1)
            case .down, .char("j"):
                updated.permissionIndex = min(PrivacyPermission.allCases.count - 1, updated.permissionIndex + 1)
            case .enter:
                guard let app = updated.selectedApp,
                      let action = updated.selectedAction,
                      let permission = updated.selectedPermission else { return ReducerOutput(state: next) }
                updated.step = .submitting
                updated.error = nil
                next.modal = .privacyWizard(updated)
                return ReducerOutput(state: next, effects: [
                    .applyPrivacy(
                        udid: updated.simulatorID,
                        action: action,
                        permission: permission,
                        bundleID: app.bundleID
                    )
                ])
            case .char("b"):
                updated.step = .pickAction
                updated.error = nil
            default: break
            }
        case .submitting:
            return ReducerOutput(state: next)
        }
        next.modal = .privacyWizard(updated)
        return ReducerOutput(state: next)
    }
    // swiftlint:enable function_body_length
}
