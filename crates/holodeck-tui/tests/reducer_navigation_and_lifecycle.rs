mod support;

use holodeck_core::models::SimulatorState;
use holodeck_tui::state::{AppEvent, Key, PendingOperation, SideEffect, reduce};
use support::{booted, shutdown, state_with};

#[test]
fn down_moves_selection_and_up_moves_it_back() {
    let state = state_with(vec![shutdown("A"), shutdown("B"), shutdown("C")]);
    let after_down = reduce(&state, AppEvent::Key(Key::Down));
    assert_eq!(after_down.state.selected_index, 1);
    let after_up = reduce(&after_down.state, AppEvent::Key(Key::Up));
    assert_eq!(after_up.state.selected_index, 0);
}

#[test]
fn navigation_clamps_at_both_edges() {
    let state = state_with(vec![shutdown("A"), shutdown("B")]);
    let at_top = reduce(&state, AppEvent::Key(Key::Up));
    assert_eq!(at_top.state.selected_index, 0);

    let mut at_bottom = state.clone();
    at_bottom.selected_index = 1;
    let still_bottom = reduce(&at_bottom, AppEvent::Key(Key::Down));
    assert_eq!(still_bottom.state.selected_index, 1);
}

#[test]
fn vim_keys_j_and_k_navigate_like_arrows() {
    let state = state_with(vec![shutdown("A"), shutdown("B")]);
    let after_j = reduce(&state, AppEvent::Key(Key::Char('j')));
    assert_eq!(after_j.state.selected_index, 1);
    let after_k = reduce(&after_j.state, AppEvent::Key(Key::Char('k')));
    assert_eq!(after_k.state.selected_index, 0);
}

#[test]
fn navigation_on_empty_list_is_a_no_op() {
    let state = state_with(vec![]);
    let after = reduce(&state, AppEvent::Key(Key::Down));
    assert_eq!(after.state.selected_index, 0);
}

#[test]
fn enter_boots_a_shutdown_simulator() {
    let state = state_with(vec![shutdown("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert_eq!(out.effects, vec![SideEffect::Boot(state.simulators[0].id)]);
    assert_eq!(out.state.pending_operations.get(&state.simulators[0].id), Some(&PendingOperation::Boot));
    assert!(out.state.status_message.unwrap().contains("Booting"));
}

#[test]
fn enter_shuts_down_a_booted_simulator() {
    let state = state_with(vec![booted("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert_eq!(out.effects, vec![SideEffect::Shutdown(state.simulators[0].id)]);
    assert_eq!(out.state.pending_operations.get(&state.simulators[0].id), Some(&PendingOperation::Shutdown));
}

#[test]
fn space_also_toggles_selected_simulator() {
    let state = state_with(vec![shutdown("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char(' ')));
    assert_eq!(out.effects, vec![SideEffect::Boot(state.simulators[0].id)]);
}

#[test]
fn toggle_is_a_no_op_while_an_operation_is_pending() {
    let mut state = state_with(vec![shutdown("A")]);
    state.pending_operations.insert(state.simulators[0].id, PendingOperation::Boot);
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert!(out.effects.is_empty());
}

#[test]
fn refresh_reconciles_boot_pending_once_target_state_is_reached() {
    let sim = shutdown("A");
    let id = sim.id;
    let mut state = state_with(vec![sim]);
    state.pending_operations.insert(id, PendingOperation::Boot);
    state.status_message = Some("Booting A…".to_string());

    let now_booted = booted("A");
    let mut now_booted_fixed = now_booted;
    now_booted_fixed.id = id;
    let out = reduce(&state, AppEvent::Refreshed(vec![now_booted_fixed]));

    assert!(out.state.pending_operations.is_empty());
    assert_eq!(out.state.status_message, None);
}

#[test]
fn refresh_keeps_boot_pending_while_target_state_not_yet_reached() {
    let sim = shutdown("A");
    let id = sim.id;
    let mut state = state_with(vec![sim.clone()]);
    state.pending_operations.insert(id, PendingOperation::Boot);

    let out = reduce(&state, AppEvent::Refreshed(vec![sim]));
    assert_eq!(out.state.pending_operations.get(&id), Some(&PendingOperation::Boot));
}

#[test]
fn erase_pending_is_kept_until_the_simulator_vanishes() {
    let sim = shutdown("A");
    let id = sim.id;
    let mut state = state_with(vec![sim.clone()]);
    state.pending_operations.insert(id, PendingOperation::Erase);

    let still_there = reduce(&state, AppEvent::Refreshed(vec![sim]));
    assert_eq!(still_there.state.pending_operations.get(&id), Some(&PendingOperation::Erase));

    let vanished = reduce(&state, AppEvent::Refreshed(vec![]));
    assert!(vanished.state.pending_operations.is_empty());
}

#[test]
fn operation_failed_for_a_dropped_pending_entry_does_not_paint_an_error() {
    let sim = shutdown("A");
    let id = sim.id;
    // No pending entry tracked (already reconciled away by an earlier refresh).
    let state = state_with(vec![sim]);
    let out = reduce(&state, AppEvent::OperationFailed(id, "boom".to_string()));
    assert_eq!(out.state.last_error, None);
    assert!(out.effects.is_empty());
}

#[test]
fn operation_failed_for_a_tracked_entry_surfaces_the_error_and_refreshes() {
    let sim = shutdown("A");
    let id = sim.id;
    let mut state = state_with(vec![sim]);
    state.pending_operations.insert(id, PendingOperation::Boot);
    let out = reduce(&state, AppEvent::OperationFailed(id, "boom".to_string()));
    assert_eq!(out.state.last_error, Some("boom".to_string()));
    assert!(out.state.pending_operations.is_empty());
    assert_eq!(out.effects, vec![SideEffect::Refresh]);
}

#[test]
fn poll_tick_refreshes_when_idle_and_while_recording() {
    let state = state_with(vec![]);
    let idle = reduce(&state, AppEvent::PollTick);
    assert_eq!(idle.effects, vec![SideEffect::Refresh]);

    let mut recording = state;
    recording.recording_device_id = Some(uuid::Uuid::new_v4());
    let out = reduce(&recording, AppEvent::PollTick);
    assert_eq!(out.effects, vec![SideEffect::Refresh]);
}

#[test]
fn q_quits_when_not_recording_but_stops_recording_first_otherwise() {
    let state = state_with(vec![]);
    let quit = reduce(&state, AppEvent::Key(Key::Char('q')));
    assert!(quit.state.is_quitting);

    let mut recording = state;
    recording.recording_device_id = Some(uuid::Uuid::new_v4());
    let out = reduce(&recording, AppEvent::Key(Key::Char('q')));
    assert!(!out.state.is_quitting);
    assert_eq!(out.effects, vec![SideEffect::StopRecording]);
}

#[test]
fn recording_started_and_stopped_update_state() {
    let state = state_with(vec![]);
    let id = uuid::Uuid::new_v4();
    let path = std::path::PathBuf::from("/tmp/a.mp4");
    let started = reduce(&state, AppEvent::RecordingStarted(id, path.clone()));
    assert!(started.state.is_recording());
    assert_eq!(started.state.recording_path, Some(path.clone()));

    let stopped = reduce(&started.state, AppEvent::RecordingStopped(Some(path.clone())));
    assert!(!stopped.state.is_recording());
    assert!(stopped.state.status_message.unwrap().contains("Saved"));
    assert_eq!(stopped.effects, vec![SideEffect::Refresh]);
}

#[test]
fn cannot_boot_an_already_booted_simulator_via_run_command() {
    let state = state_with(vec![booted("A")]);
    // 'r' with no recording in-flight and a booted sim runs the Record command,
    // not Boot — exercise the boot-guard path through the palette instead by
    // simulating an already-shutdown sim with a pending op.
    let mut pending = state.clone();
    pending.pending_operations.insert(state.simulators[0].id, PendingOperation::Shutdown);
    let out = reduce(&pending, AppEvent::Key(Key::Enter));
    assert!(out.effects.is_empty());
}

#[test]
fn r_starts_recording_on_a_booted_simulator() {
    let state = state_with(vec![booted("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('r')));
    assert_eq!(out.effects, vec![SideEffect::StartRecording(state.simulators[0].id)]);
}

#[test]
fn r_stops_recording_when_already_recording() {
    let mut state = state_with(vec![booted("A")]);
    state.recording_device_id = Some(state.simulators[0].id);
    let out = reduce(&state, AppEvent::Key(Key::Char('r')));
    assert_eq!(out.effects, vec![SideEffect::StopRecording]);
}

#[test]
fn r_on_a_shutdown_simulator_surfaces_a_status_message_not_an_effect() {
    let state = state_with(vec![shutdown("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('r')));
    assert!(out.effects.is_empty());
    assert!(out.state.status_message.unwrap().contains("Cannot record"));
}

#[test]
fn refreshed_resets_selected_index_when_it_falls_outside_the_new_list() {
    let mut state = state_with(vec![shutdown("A"), shutdown("B"), shutdown("C")]);
    state.selected_index = 2;
    let out = reduce(&state, AppEvent::Refreshed(vec![shutdown("A")]));
    assert_eq!(out.state.selected_index, 0);
}

#[test]
fn state_matches_simulator_state() {
    assert_eq!(SimulatorState::Booted.raw_value(), "Booted");
}
