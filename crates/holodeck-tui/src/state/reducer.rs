use std::collections::HashMap;

use uuid::Uuid;

use holodeck_core::models::{Simulator, SimulatorState};

use super::app_state::{
    AppState, CreateWizard, CreateWizardStep, LaunchAppPrompt, LaunchAppStep, Modal, OpenUrlPrompt, PendingOperation,
    PrivacyWizard, PrivacyWizardStep,
};
use super::event::{AppEvent, ReducerOutput, SideEffect};
use super::key::Key;
use super::modal_reducer;
use super::palette_command::PaletteCommand;
use super::text_input::TextField;

pub fn reduce(state: &AppState, event: AppEvent) -> ReducerOutput {
    let mut next = state.clone();
    match event {
        AppEvent::Refreshed(sims) => {
            next.simulators = AppState::sort(sims);
            let visible_count = next.visible_simulators().len() as i64;
            if visible_count == 0 {
                next.selected_index = 0;
            } else if next.selected_index >= visible_count {
                next.selected_index = visible_count - 1;
            }
            next.main_scroll_offset = clamp_main_scroll(next.main_scroll_offset, &next);
            if let Some(referenced) = next.modal.as_ref().and_then(Modal::referenced_simulator)
                && !next.simulators.iter().any(|s| s.id == referenced)
            {
                next.modal = None;
            }
            let reconciled = reconcile_pending(&next.pending_operations, &next.simulators);
            if reconciled.len() != next.pending_operations.len() && reconciled.is_empty() {
                // Every tracked operation reached its target, so the banner
                // announcing it ('Booting A…', 'Shutting down A…') clears.
                next.status_message = None;
            }
            next.pending_operations = reconciled;
            next.last_error = None;
            ReducerOutput::new(next)
        }

        AppEvent::RefreshFailed(message) => {
            next.last_error = Some(message);
            ReducerOutput::new(next)
        }

        AppEvent::Resized { rows, cols } => {
            next.rows = rows;
            next.cols = cols;
            next.main_scroll_offset = clamp_main_scroll(next.main_scroll_offset, &next);
            ReducerOutput::new(next)
        }

        AppEvent::PollTick => {
            // Polling continues during a recording: `simctl list` is a
            // read-only process independent of the recording child.
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }

        AppEvent::Key(key) => handle_key(&next, key),

        AppEvent::OperationCompleted(id) => {
            // Only still-tracked operations are handled; an entry
            // `reconcile_pending` already dropped on an earlier Refreshed
            // leaves state (including any newer op's banner) untouched.
            if next.pending_operations.remove(&id).is_none() {
                return ReducerOutput::new(next);
            }
            next.status_message = None;
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }

        AppEvent::OperationFailed(id, message) => {
            if next.pending_operations.remove(&id).is_none() {
                // The op visibly succeeded as far as the user is concerned
                // (state reached target before the simctl process
                // returned). Don't paint a red error banner over a clean
                // outcome.
                return ReducerOutput::new(next);
            }
            next.status_message = None;
            next.last_error = Some(message);
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }

        AppEvent::RecordingStarted(id, path) => {
            next.recording_device_id = Some(id);
            next.recording_path = Some(path);
            next.status_message = None;
            ReducerOutput::new(next)
        }

        AppEvent::RecordingStopped(path) => {
            next.recording_device_id = None;
            next.recording_path = None;
            next.status_message = path.map(|p| format!("Saved {}", p.display()));
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }

        AppEvent::RecordingFailed(message) => {
            next.recording_device_id = None;
            next.recording_path = None;
            next.last_error = Some(message);
            ReducerOutput::new(next)
        }

        AppEvent::ScreenshotSaved(path) => {
            let file_name = path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
            next.status_message = Some(format!("Screenshot saved {file_name}"));
            ReducerOutput::new(next)
        }

        AppEvent::ScreenshotFailed(message) => {
            next.last_error = Some(message);
            ReducerOutput::new(next)
        }

        AppEvent::AppearanceChanged(_, appearance) => {
            next.status_message = Some(format!("Appearance set to {}", appearance.raw_value()));
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }

        AppEvent::AppearanceFailed(message) => {
            next.last_error = Some(message);
            ReducerOutput::new(next)
        }

        AppEvent::TargetsLoaded { mut device_types, mut runtimes } => {
            if let Some(Modal::CreateWizard(wizard)) = &next.modal {
                let mut updated = wizard.clone();
                device_types.sort_by(|a, b| a.name.cmp(&b.name));
                runtimes.sort_by(|a, b| b.cmp(a));
                updated.device_types = device_types;
                updated.runtimes = runtimes;
                updated.step =
                    if updated.device_types.is_empty() { CreateWizardStep::Loading } else { CreateWizardStep::PickDeviceType };
                next.modal = Some(Modal::CreateWizard(updated));
            }
            ReducerOutput::new(next)
        }

        AppEvent::TargetsFailed(message) => {
            if let Some(Modal::CreateWizard(_)) = &next.modal {
                next.modal = None;
            }
            next.last_error = Some(message);
            ReducerOutput::new(next)
        }

        AppEvent::SimulatorCreated(_, name) => {
            next.modal = None;
            next.status_message = Some(format!("Created {name}"));
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }

        AppEvent::SimulatorCreateFailed(message) => {
            if let Some(Modal::CreateWizard(wizard)) = &next.modal {
                let mut updated = wizard.clone();
                updated.step = CreateWizardStep::Confirm;
                updated.error = Some(message);
                next.modal = Some(Modal::CreateWizard(updated));
            } else {
                next.last_error = Some(message);
            }
            ReducerOutput::new(next)
        }

        AppEvent::AppsLoaded(apps) => {
            // Both the privacy wizard and the launch modal request apps
            // through the same `LoadInstalledApps` effect. The modal that's
            // open is the record of who asked, so route on it rather than
            // tagging the effect or the event.
            match &next.modal {
                Some(Modal::PrivacyWizard(wizard)) => {
                    let mut updated = wizard.clone();
                    updated.all_apps = apps;
                    updated.app_index = 0;
                    updated.step = PrivacyWizardStep::PickApp;
                    updated.error = None;
                    next.modal = Some(Modal::PrivacyWizard(updated));
                }
                Some(Modal::LaunchApp(prompt)) => {
                    let mut updated = prompt.clone();
                    updated.all_apps = apps;
                    updated.app_index = 0;
                    updated.step = LaunchAppStep::PickApp;
                    updated.error = None;
                    next.modal = Some(Modal::LaunchApp(updated));
                }
                _ => {}
            }
            ReducerOutput::new(next)
        }

        AppEvent::AppsLoadFailed(message) => {
            if matches!(next.modal, Some(Modal::PrivacyWizard(_)) | Some(Modal::LaunchApp(_))) {
                next.modal = None;
            }
            next.last_error = Some(message);
            ReducerOutput::new(next)
        }

        AppEvent::PrivacyApplied { bundle_id } => {
            next.modal = None;
            next.status_message = Some(format!("Privacy updated for {bundle_id}"));
            ReducerOutput::new(next)
        }

        AppEvent::PrivacyApplyFailed(message) => {
            if let Some(Modal::PrivacyWizard(wizard)) = &next.modal {
                let mut updated = wizard.clone();
                updated.step = PrivacyWizardStep::PickAction;
                updated.error = Some(message);
                next.modal = Some(Modal::PrivacyWizard(updated));
            } else {
                next.last_error = Some(message);
            }
            ReducerOutput::new(next)
        }

        AppEvent::UrlHistoryLoaded(history) => {
            next.url_history = history;
            ReducerOutput::new(next)
        }

        AppEvent::UrlOpened { url, history } => {
            // Update history regardless (the simctl call already
            // succeeded), but only surface the modal close + status message
            // if the user is still on the open-URL modal. Esc during
            // submission drops the modal first.
            next.url_history = history;
            if let Some(Modal::OpenUrl(_)) = &next.modal {
                next.modal = None;
                next.status_message = Some(format!("Opened {url}"));
            }
            ReducerOutput::new(next)
        }

        AppEvent::UrlOpenFailed(message) => {
            if let Some(Modal::OpenUrl(prompt)) = &next.modal {
                let mut updated = prompt.clone();
                updated.is_submitting = false;
                updated.error = Some(message);
                next.modal = Some(Modal::OpenUrl(updated));
            }
            ReducerOutput::new(next)
        }

        AppEvent::AppLaunched { bundle_id } => {
            // Only surface the modal close + status message if the user is
            // still on the launch modal — Esc during submission drops the
            // modal first, mirroring `UrlOpened`.
            if let Some(Modal::LaunchApp(_)) = &next.modal {
                next.modal = None;
            }
            next.status_message = Some(format!("Launched {bundle_id}"));
            ReducerOutput::new(next)
        }

        AppEvent::AppLaunchFailed(message) => {
            if let Some(Modal::LaunchApp(prompt)) = &next.modal {
                let mut updated = prompt.clone();
                updated.step = LaunchAppStep::PickApp;
                updated.chosen_language = None;
                updated.error = Some(message);
                next.modal = Some(Modal::LaunchApp(updated));
            } else {
                next.last_error = Some(message);
            }
            ReducerOutput::new(next)
        }
    }
}

fn handle_key(state: &AppState, key: Key) -> ReducerOutput {
    if state.is_filter_focused {
        return handle_filter_key(state, key);
    }
    if state.modal.is_some() {
        return modal_reducer::handle(state, key);
    }
    let mut next = state.clone();
    let count = next.visible_simulators().len() as i64;
    match key {
        Key::Up | Key::Char('k') => {
            if count > 0 {
                next.selected_index = (next.selected_index - 1).max(0);
            }
            next.main_scroll_offset = AppState::scroll(next.main_scroll_offset, next.selected_index, next.main_list_viewport());
            ReducerOutput::new(next)
        }
        Key::Down | Key::Char('j') => {
            if count > 0 {
                next.selected_index = (next.selected_index + 1).min(count - 1);
            }
            next.main_scroll_offset = AppState::scroll(next.main_scroll_offset, next.selected_index, next.main_list_viewport());
            ReducerOutput::new(next)
        }
        Key::Char('/') => {
            next.is_filter_focused = true;
            next.filter_query.clear();
            next.selected_index = 0;
            next.main_scroll_offset = 0;
            ReducerOutput::new(next)
        }
        Key::Char(':') => {
            next.modal = Some(Modal::CommandPalette(super::app_state::CommandPalette {
                simulator_id: next.selected_simulator().map(|s| s.id),
                query: TextField::new(),
            }));
            ReducerOutput::new(next)
        }
        Key::Char('i') => run_command(PaletteCommand::Inspect, next),
        Key::Char('o') => run_command(PaletteCommand::Open, next),
        Key::Char('q') | Key::Escape => {
            if next.is_recording() {
                return ReducerOutput::with_effects(next, vec![SideEffect::StopRecording]);
            }
            next.is_quitting = true;
            ReducerOutput::new(next)
        }
        Key::Char('R') => {
            next.status_message = Some("Refreshing…".to_string());
            ReducerOutput::with_effects(next, vec![SideEffect::Refresh])
        }
        Key::Char('r') => {
            if next.recording_device_id.is_some() {
                next.status_message = Some("Stopping recording…".to_string());
                return ReducerOutput::with_effects(next, vec![SideEffect::StopRecording]);
            }
            run_command(PaletteCommand::Record, next)
        }
        Key::Char('p') => run_command(PaletteCommand::Screenshot, next),
        Key::Char('a') => run_command(PaletteCommand::Appearance, next),
        Key::Char('e') => run_command(PaletteCommand::Erase, next),
        Key::Char('d') => run_command(PaletteCommand::Delete, next),
        Key::Char('n') => run_command(PaletteCommand::New, next),
        Key::Char('f') => run_command(PaletteCommand::Focus, next),
        Key::Char('P') => run_command(PaletteCommand::Privacy, next),
        Key::Char('l') => run_command(PaletteCommand::Launch, next),
        Key::Char('?') => {
            next.modal = Some(Modal::Help);
            ReducerOutput::new(next)
        }
        Key::Enter | Key::Char(' ') => toggle_selected(next),
        _ => ReducerOutput::new(next),
    }
}

fn handle_filter_key(state: &AppState, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    match key {
        Key::Escape => {
            next.is_filter_focused = false;
            next.filter_query.clear();
            next.selected_index = 0;
            next.main_scroll_offset = 0;
        }
        Key::Enter => next.is_filter_focused = false,
        // Editing keys (typing, Backspace/Delete, ←/→, Home/End) go to the
        // query; only a text change re-anchors the list selection, so moving
        // the caret leaves the highlighted row alone.
        _ => {
            if next.filter_query.handle(key) {
                next.selected_index = 0;
                next.main_scroll_offset = 0;
            }
        }
    }
    ReducerOutput::new(next)
}

/// Executes a palette command (or the equivalent keyboard shortcut).
/// Preconditions match `PaletteCommand::is_applicable`; when the precondition
/// fails this surfaces a transient status message instead of an effect.
pub fn run_command(command: PaletteCommand, state: AppState) -> ReducerOutput {
    let mut next = state;
    match command {
        PaletteCommand::New => {
            next.modal = Some(Modal::CreateWizard(CreateWizard::new()));
            ReducerOutput::with_effects(next, vec![SideEffect::LoadTargets])
        }

        PaletteCommand::Inspect => {
            let Some(sim) = next.selected_simulator() else {
                return ReducerOutput::new(next);
            };
            let id = sim.id;
            next.modal = Some(Modal::Inspector(id));
            ReducerOutput::new(next)
        }

        PaletteCommand::Focus => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            next.status_message = Some(format!("Focusing {}…", sim.name));
            ReducerOutput::with_effects(next, vec![SideEffect::FocusSimulator(sim.id)])
        }

        PaletteCommand::Delete => {
            let Some(sim) = next.selected_simulator() else {
                return ReducerOutput::new(next);
            };
            let id = sim.id;
            next.modal = Some(Modal::ConfirmDelete(id, 1));
            ReducerOutput::new(next)
        }

        PaletteCommand::Erase => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Shutdown {
                next.status_message = Some(format!("Cannot erase: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.modal = Some(Modal::ConfirmErase(sim.id, 1));
            ReducerOutput::new(next)
        }

        PaletteCommand::Appearance => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot set appearance: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.modal = Some(Modal::Appearance(0));
            ReducerOutput::new(next)
        }

        PaletteCommand::Screenshot => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot capture: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.status_message = Some("Capturing screenshot…".to_string());
            ReducerOutput::with_effects(next, vec![SideEffect::CaptureScreenshot(sim.id)])
        }

        PaletteCommand::Record => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot record: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.status_message = Some("Starting recording…".to_string());
            ReducerOutput::with_effects(next, vec![SideEffect::StartRecording(sim.id)])
        }

        PaletteCommand::Open => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot open URL: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.modal = Some(Modal::OpenUrl(OpenUrlPrompt::new(sim.id)));
            ReducerOutput::new(next)
        }

        PaletteCommand::Privacy => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot inspect apps: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.modal = Some(Modal::PrivacyWizard(PrivacyWizard::new(sim.id)));
            ReducerOutput::with_effects(next, vec![SideEffect::LoadInstalledApps(sim.id)])
        }

        PaletteCommand::Launch => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot launch: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.modal = Some(Modal::LaunchApp(LaunchAppPrompt::new(sim.id)));
            ReducerOutput::with_effects(next, vec![SideEffect::LoadInstalledApps(sim.id)])
        }

        PaletteCommand::Boot => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if next.pending_operations.contains_key(&sim.id) {
                next.status_message = Some(format!("{} has a pending operation", sim.name));
                return ReducerOutput::new(next);
            }
            if sim.state != SimulatorState::Shutdown {
                next.status_message = Some(format!("Cannot boot: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.pending_operations.insert(sim.id, PendingOperation::Boot);
            next.status_message = Some(format!("Booting {}…", sim.name));
            ReducerOutput::with_effects(next, vec![SideEffect::Boot(sim.id)])
        }

        PaletteCommand::Shutdown => {
            let Some(sim) = next.selected_simulator().cloned() else {
                return ReducerOutput::new(next);
            };
            if next.pending_operations.contains_key(&sim.id) {
                next.status_message = Some(format!("{} has a pending operation", sim.name));
                return ReducerOutput::new(next);
            }
            if sim.state != SimulatorState::Booted {
                next.status_message = Some(format!("Cannot shut down: {} is {}", sim.name, sim.state.raw_value()));
                return ReducerOutput::new(next);
            }
            next.pending_operations.insert(sim.id, PendingOperation::Shutdown);
            next.status_message = Some(format!("Shutting down {}…", sim.name));
            ReducerOutput::with_effects(next, vec![SideEffect::Shutdown(sim.id)])
        }
    }
}

fn toggle_selected(state: AppState) -> ReducerOutput {
    let mut next = state;
    let Some(sim) = next.selected_simulator().cloned() else {
        return ReducerOutput::new(next);
    };
    if next.pending_operations.contains_key(&sim.id) {
        return ReducerOutput::new(next);
    }
    match sim.state {
        SimulatorState::Booted => {
            next.pending_operations.insert(sim.id, PendingOperation::Shutdown);
            next.status_message = Some(format!("Shutting down {}…", sim.name));
            ReducerOutput::with_effects(next, vec![SideEffect::Shutdown(sim.id)])
        }
        SimulatorState::Shutdown => {
            next.pending_operations.insert(sim.id, PendingOperation::Boot);
            next.status_message = Some(format!("Booting {}…", sim.name));
            ReducerOutput::with_effects(next, vec![SideEffect::Boot(sim.id)])
        }
        other => {
            next.status_message = Some(format!("{} is {}", sim.name, other.raw_value()));
            ReducerOutput::new(next)
        }
    }
}

/// Drops pending operations that have already reached their target state.
/// Erase/delete entries are kept until the spawned task posts
/// `OperationCompleted` because `simctl erase` does not change the sim's
/// observable state.
fn reconcile_pending(pending: &HashMap<Uuid, PendingOperation>, simulators: &[Simulator]) -> HashMap<Uuid, PendingOperation> {
    let by_id: HashMap<Uuid, &Simulator> = simulators.iter().map(|s| (s.id, s)).collect();
    pending
        .iter()
        .filter(|(id, operation)| match operation {
            PendingOperation::Delete | PendingOperation::Erase => by_id.contains_key(*id),
            PendingOperation::Boot => by_id.get(*id).is_some_and(|s| s.state != SimulatorState::Booted),
            PendingOperation::Shutdown => by_id.get(*id).is_some_and(|s| s.state != SimulatorState::Shutdown),
        })
        .map(|(id, op)| (*id, *op))
        .collect()
}

fn clamp_main_scroll(offset: i64, state: &AppState) -> i64 {
    let count = state.visible_simulators().len() as i64;
    if count == 0 {
        return 0;
    }
    let max_offset = (count - state.main_list_viewport()).max(0);
    offset.clamp(0, max_offset)
}
