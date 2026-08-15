use uuid::Uuid;

use holodeck_core::models::Appearance;

use super::app_state::{AppState, CreateWizard, CreateWizardStep, Modal, PendingOperation};
use super::command_palette_reducer;
use super::event::{ReducerOutput, SideEffect};
use super::key::{Key, is_printable};
use super::open_url_modal_reducer;
use super::privacy_wizard_reducer;

pub fn handle(state: &AppState, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    match state.modal.clone() {
        Some(Modal::Appearance) => appearance(&next, key),
        Some(Modal::ConfirmErase(id)) => confirm(
            &next,
            id,
            key,
            "Erasing…",
            PendingOperation::Erase,
            SideEffect::EraseSimulator(id),
        ),
        Some(Modal::ConfirmDelete(id)) => confirm(
            &next,
            id,
            key,
            "Deleting…",
            PendingOperation::Delete,
            SideEffect::DeleteSimulator(id),
        ),
        Some(Modal::CreateWizard(wizard)) => wizard_handle(&next, &wizard, key),
        Some(Modal::PrivacyWizard(wizard)) => privacy_wizard_reducer::handle(&next, &wizard, key),
        Some(Modal::Inspector(_)) => {
            next.modal = None;
            ReducerOutput::new(next)
        }
        Some(Modal::OpenUrl(prompt)) => open_url_modal_reducer::handle(&next, &prompt, key),
        Some(Modal::CommandPalette(palette)) => command_palette_reducer::handle(&next, &palette, key),
        Some(Modal::Help) | None => {
            next.modal = None;
            ReducerOutput::new(next)
        }
    }
}

fn appearance(state: &AppState, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    match key {
        Key::Char('l') => {
            let Some(sim) = next.selected_simulator().cloned() else {
                next.modal = None;
                return ReducerOutput::new(next);
            };
            next.modal = None;
            next.status_message = Some("Setting appearance to light…".to_string());
            ReducerOutput::with_effects(next, vec![SideEffect::SetAppearance(sim.id, Appearance::Light)])
        }
        Key::Char('d') => {
            let Some(sim) = next.selected_simulator().cloned() else {
                next.modal = None;
                return ReducerOutput::new(next);
            };
            next.modal = None;
            next.status_message = Some("Setting appearance to dark…".to_string());
            ReducerOutput::with_effects(next, vec![SideEffect::SetAppearance(sim.id, Appearance::Dark)])
        }
        Key::Escape | Key::Char('q') => {
            next.modal = None;
            ReducerOutput::new(next)
        }
        _ => ReducerOutput::new(next),
    }
}

fn confirm(state: &AppState, id: Uuid, key: Key, status: &str, operation: PendingOperation, effect: SideEffect) -> ReducerOutput {
    let mut next = state.clone();
    match key {
        Key::Char('y') | Key::Char('Y') => {
            next.modal = None;
            // Don't clobber an unrelated in-flight intent (e.g. a pending
            // Boot when the user confirms Delete). The sibling reducers in
            // reducer.rs apply the same guard on their own paths.
            if next.pending_operations.contains_key(&id) {
                next.status_message = Some("Simulator already has a pending operation".to_string());
                return ReducerOutput::new(next);
            }
            next.status_message = Some(status.to_string());
            next.pending_operations.insert(id, operation);
            ReducerOutput::with_effects(next, vec![effect])
        }
        Key::Char('n') | Key::Char('N') | Key::Escape | Key::Char('q') => {
            next.modal = None;
            ReducerOutput::new(next)
        }
        _ => ReducerOutput::new(next),
    }
}

fn wizard_handle(state: &AppState, wizard: &CreateWizard, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    let mut updated = wizard.clone();

    if let Key::Escape = key {
        // Esc clears the filter as long as it is live on the visible step
        // (focused, or has a non-empty query). Only closes the modal when
        // there's nothing filter-shaped left to dismiss.
        let filter_is_live = wizard.is_device_type_filter_focused || !wizard.device_type_filter.is_empty();
        if wizard.step == CreateWizardStep::PickDeviceType && filter_is_live {
            updated.is_device_type_filter_focused = false;
            updated.device_type_filter.clear();
            updated.device_type_index = 0;
            updated.device_type_scroll_offset = 0;
            next.modal = Some(Modal::CreateWizard(updated));
            return ReducerOutput::new(next);
        }
        next.modal = None;
        return ReducerOutput::new(next);
    }

    let viewport = CreateWizard::viewport(state.rows);
    match wizard.step {
        CreateWizardStep::Loading => return ReducerOutput::new(next),
        CreateWizardStep::PickDeviceType => {
            if wizard.is_device_type_filter_focused {
                match key {
                    Key::Enter => updated.is_device_type_filter_focused = false,
                    Key::Backspace => {
                        if !updated.device_type_filter.is_empty() {
                            updated.device_type_filter.pop();
                        }
                        updated.device_type_index = 0;
                        updated.device_type_scroll_offset = 0;
                    }
                    Key::Char(c) if is_printable(c) => {
                        updated.device_type_filter.push(c);
                        updated.device_type_index = 0;
                        updated.device_type_scroll_offset = 0;
                    }
                    _ => {}
                }
                next.modal = Some(Modal::CreateWizard(updated));
                return ReducerOutput::new(next);
            }
            match key {
                Key::Up | Key::Char('k') => updated.device_type_index = (updated.device_type_index - 1).max(0),
                Key::Down | Key::Char('j') => {
                    let last_index = (updated.visible_device_types().len() as i64 - 1).max(0);
                    updated.device_type_index = (updated.device_type_index + 1).min(last_index);
                }
                Key::Char('/') => {
                    updated.is_device_type_filter_focused = true;
                    // Preserve an existing filter so the user can keep
                    // editing — Esc is the affordance for clearing. Only
                    // reset cursor/scroll when entering edit mode fresh (no
                    // query yet).
                    if updated.device_type_filter.is_empty() {
                        updated.device_type_index = 0;
                        updated.device_type_scroll_offset = 0;
                    }
                }
                Key::Enter => {
                    if updated.selected_device_type().is_none() {
                        return ReducerOutput::new(next);
                    }
                    updated.step = CreateWizardStep::PickRuntime;
                }
                _ => {}
            }
            let device_type_viewport = updated.device_type_viewport(state.rows);
            updated.device_type_scroll_offset = AppState::scroll(
                updated.device_type_scroll_offset,
                updated.device_type_index,
                device_type_viewport,
            );
        }
        CreateWizardStep::PickRuntime => {
            match key {
                Key::Up | Key::Char('k') => updated.runtime_index = (updated.runtime_index - 1).max(0),
                Key::Down | Key::Char('j') => {
                    updated.runtime_index = (updated.runtime_index + 1).min((updated.runtimes.len() as i64 - 1).max(0));
                }
                Key::Enter => {
                    if updated.selected_runtime().is_none() {
                        return ReducerOutput::new(next);
                    }
                    updated.step = CreateWizardStep::Confirm;
                }
                Key::Char('b') => updated.step = CreateWizardStep::PickDeviceType,
                _ => {}
            }
            updated.runtime_scroll_offset = AppState::scroll(updated.runtime_scroll_offset, updated.runtime_index, viewport);
        }
        CreateWizardStep::Confirm => match key {
            Key::Enter | Key::Char('y') => {
                let (Some(device_type), Some(runtime)) =
                    (updated.selected_device_type().cloned(), updated.selected_runtime().cloned())
                else {
                    return ReducerOutput::new(next);
                };
                updated.step = CreateWizardStep::Submitting;
                updated.error = None;
                let effect = SideEffect::CreateSimulator {
                    name: updated.default_name(),
                    device_type,
                    runtime,
                };
                next.modal = Some(Modal::CreateWizard(updated));
                return ReducerOutput::with_effects(next, vec![effect]);
            }
            Key::Char('b') => {
                updated.step = CreateWizardStep::PickRuntime;
                updated.error = None;
            }
            _ => {}
        },
        CreateWizardStep::Submitting => return ReducerOutput::new(next),
    }

    next.modal = Some(Modal::CreateWizard(updated));
    ReducerOutput::new(next)
}
