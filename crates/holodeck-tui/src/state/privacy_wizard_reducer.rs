use holodeck_core::models::{PrivacyAction, PrivacyPermission};

use super::app_state::{AppState, Modal, PrivacyWizard, PrivacyWizardStep};
use super::event::{ReducerOutput, SideEffect};
use super::key::Key;

pub fn handle(state: &AppState, wizard: &PrivacyWizard, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    let mut updated = wizard.clone();

    if let Key::Escape = key {
        next.modal = None;
        return ReducerOutput::new(next);
    }

    let viewport = PrivacyWizard::app_viewport(state.rows);
    match wizard.step {
        PrivacyWizardStep::LoadingApps => return ReducerOutput::new(next),
        PrivacyWizardStep::PickApp => {
            match key {
                Key::Up | Key::Char('k') => updated.app_index = (updated.app_index - 1).max(0),
                Key::Down | Key::Char('j') => {
                    updated.app_index = (updated.app_index + 1).min((updated.apps().len() as i64 - 1).max(0));
                }
                Key::Char('s') => {
                    updated.show_system = !updated.show_system;
                    updated.app_index = 0;
                    updated.app_scroll_offset = 0;
                }
                Key::Enter => {
                    if updated.selected_app().is_none() {
                        return ReducerOutput::new(next);
                    }
                    updated.step = PrivacyWizardStep::PickPermission;
                }
                _ => {}
            }
            updated.app_scroll_offset = AppState::scroll(updated.app_scroll_offset, updated.app_index, viewport);
        }
        PrivacyWizardStep::PickPermission => match key {
            Key::Up | Key::Char('k') => updated.permission_index = (updated.permission_index - 1).max(0),
            Key::Down | Key::Char('j') => {
                updated.permission_index = (updated.permission_index + 1).min(PrivacyPermission::ALL.len() as i64 - 1);
            }
            Key::Enter => updated.step = PrivacyWizardStep::PickAction,
            Key::Char('b') => updated.step = PrivacyWizardStep::PickApp,
            _ => {}
        },
        PrivacyWizardStep::PickAction => match key {
            Key::Up | Key::Char('k') => updated.action_index = (updated.action_index - 1).max(0),
            Key::Down | Key::Char('j') => {
                updated.action_index = (updated.action_index + 1).min(PrivacyAction::ALL.len() as i64 - 1);
            }
            Key::Enter => {
                let (Some(app), Some(action), Some(permission)) =
                    (updated.selected_app(), updated.selected_action(), updated.selected_permission())
                else {
                    return ReducerOutput::new(next);
                };
                let bundle_id = app.bundle_id.clone();
                updated.step = PrivacyWizardStep::Submitting;
                updated.error = None;
                let effect = SideEffect::ApplyPrivacy { udid: updated.simulator_id, action, permission, bundle_id };
                next.modal = Some(Modal::PrivacyWizard(updated));
                return ReducerOutput::with_effects(next, vec![effect]);
            }
            Key::Char('b') => {
                updated.step = PrivacyWizardStep::PickPermission;
                updated.error = None;
            }
            _ => {}
        },
        PrivacyWizardStep::Submitting => return ReducerOutput::new(next),
    }

    next.modal = Some(Modal::PrivacyWizard(updated));
    ReducerOutput::new(next)
}
