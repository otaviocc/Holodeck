mod support;

use holodeck_tui::state::{AppEvent, CommandPalette, Key, Modal, OpenUrlPrompt, SideEffect, reduce};
use support::{booted, shutdown, state_with};

// MARK: - Command palette

#[test]
fn colon_opens_the_command_palette_with_the_selected_simulator() {
    let state = state_with(vec![booted("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char(':')));
    let Some(Modal::CommandPalette(palette)) = out.state.modal else { panic!("expected CommandPalette modal") };
    assert_eq!(palette.simulator_id, Some(state.simulators[0].id));
    assert_eq!(palette.query, "");
}

#[test]
fn typing_and_backspace_edit_the_palette_query() {
    let mut state = state_with(vec![booted("A")]);
    state.modal = Some(Modal::CommandPalette(CommandPalette::default()));
    let typed = reduce(&state, AppEvent::Key(Key::Char('b')));
    let typed = reduce(&typed.state, AppEvent::Key(Key::Char('o')));
    let Some(Modal::CommandPalette(p)) = &typed.state.modal else { panic!() };
    assert_eq!(p.query, "bo");

    let backspaced = reduce(&typed.state, AppEvent::Key(Key::Backspace));
    let Some(Modal::CommandPalette(p)) = &backspaced.state.modal else { panic!() };
    assert_eq!(p.query, "b");
}

#[test]
fn tab_completes_to_the_top_matching_command_preserving_typed_casing() {
    let mut state = state_with(vec![booted("A")]);
    state.modal =
        Some(Modal::CommandPalette(CommandPalette { simulator_id: Some(state.simulators[0].id), query: "Sh".to_string() }));
    let out = reduce(&state, AppEvent::Key(Key::Tab));
    let Some(Modal::CommandPalette(p)) = &out.state.modal else { panic!() };
    assert_eq!(p.query, "Shutdown");
}

#[test]
fn enter_on_empty_query_closes_the_palette_without_running_anything() {
    let mut state = state_with(vec![booted("A")]);
    state.modal = Some(Modal::CommandPalette(CommandPalette::default()));
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert_eq!(out.state.modal, None);
    assert!(out.effects.is_empty());
}

#[test]
fn enter_with_no_matching_command_surfaces_an_error() {
    let mut state = state_with(vec![booted("A")]);
    state.modal =
        Some(Modal::CommandPalette(CommandPalette { simulator_id: Some(state.simulators[0].id), query: "zzz".to_string() }));
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert_eq!(out.state.modal, None);
    assert!(out.state.last_error.unwrap().contains("zzz"));
}

#[test]
fn enter_with_a_matching_command_runs_it() {
    let mut state = state_with(vec![shutdown("A")]);
    state.modal =
        Some(Modal::CommandPalette(CommandPalette { simulator_id: Some(state.simulators[0].id), query: "boot".to_string() }));
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert_eq!(out.state.modal, None);
    assert_eq!(out.effects, vec![SideEffect::Boot(state.simulators[0].id)]);
}

#[test]
fn escape_closes_the_palette() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CommandPalette(CommandPalette::default()));
    let out = reduce(&state, AppEvent::Key(Key::Escape));
    assert_eq!(out.state.modal, None);
}

// MARK: - Open URL modal

#[test]
fn o_opens_the_open_url_modal_only_for_a_booted_simulator() {
    let state = state_with(vec![booted("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('o')));
    assert!(matches!(out.state.modal, Some(Modal::OpenUrl(_))));

    let shutdown_state = state_with(vec![shutdown("A")]);
    let refused = reduce(&shutdown_state, AppEvent::Key(Key::Char('o')));
    assert_eq!(refused.state.modal, None);
}

#[test]
fn typing_builds_the_url_and_backspace_edits_it() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::OpenUrl(OpenUrlPrompt::new(uuid::Uuid::new_v4())));
    let typed = reduce(&state, AppEvent::Key(Key::Char('h')));
    let Some(Modal::OpenUrl(p)) = &typed.state.modal else { panic!() };
    assert_eq!(p.url, "h");

    let backspaced = reduce(&typed.state, AppEvent::Key(Key::Backspace));
    let Some(Modal::OpenUrl(p)) = &backspaced.state.modal else { panic!() };
    assert_eq!(p.url, "");
}

#[test]
fn up_recalls_history_and_down_walks_back_to_empty() {
    let mut state = state_with(vec![]);
    state.url_history = vec!["https://b.com".to_string(), "https://a.com".to_string()];
    state.modal = Some(Modal::OpenUrl(OpenUrlPrompt::new(uuid::Uuid::new_v4())));

    let up1 = reduce(&state, AppEvent::Key(Key::Up));
    let Some(Modal::OpenUrl(p)) = &up1.state.modal else { panic!() };
    assert_eq!(p.url, "https://b.com");

    let up2 = reduce(&up1.state, AppEvent::Key(Key::Up));
    let Some(Modal::OpenUrl(p)) = &up2.state.modal else { panic!() };
    assert_eq!(p.url, "https://a.com");

    let down1 = reduce(&up2.state, AppEvent::Key(Key::Down));
    let Some(Modal::OpenUrl(p)) = &down1.state.modal else { panic!() };
    assert_eq!(p.url, "https://b.com");

    let down2 = reduce(&down1.state, AppEvent::Key(Key::Down));
    let Some(Modal::OpenUrl(p)) = &down2.state.modal else { panic!() };
    assert_eq!(p.url, "");
}

#[test]
fn enter_with_a_url_submits_and_marks_submitting() {
    let sim_id = uuid::Uuid::new_v4();
    let mut prompt = OpenUrlPrompt::new(sim_id);
    prompt.url = "https://apple.com".to_string();
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::OpenUrl(prompt));

    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert_eq!(out.effects, vec![SideEffect::OpenUrl { udid: sim_id, url: "https://apple.com".to_string() }]);
    let Some(Modal::OpenUrl(p)) = &out.state.modal else { panic!() };
    assert!(p.is_submitting);
}

#[test]
fn enter_with_an_empty_url_is_a_no_op() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::OpenUrl(OpenUrlPrompt::new(uuid::Uuid::new_v4())));
    let out = reduce(&state, AppEvent::Key(Key::Enter));
    assert!(out.effects.is_empty());
}

#[test]
fn url_opened_closes_the_modal_and_updates_history() {
    let mut prompt = OpenUrlPrompt::new(uuid::Uuid::new_v4());
    prompt.is_submitting = true;
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::OpenUrl(prompt));

    let out = reduce(
        &state,
        AppEvent::UrlOpened { url: "https://apple.com".to_string(), history: vec!["https://apple.com".to_string()] },
    );
    assert_eq!(out.state.modal, None);
    assert_eq!(out.state.url_history, vec!["https://apple.com".to_string()]);
    assert!(out.state.status_message.unwrap().contains("https://apple.com"));
}

#[test]
fn url_opened_still_updates_history_even_if_the_modal_was_dismissed_mid_flight() {
    let state = state_with(vec![]); // modal already None
    let out = reduce(
        &state,
        AppEvent::UrlOpened { url: "https://apple.com".to_string(), history: vec!["https://apple.com".to_string()] },
    );
    assert_eq!(out.state.modal, None);
    assert_eq!(out.state.url_history, vec!["https://apple.com".to_string()]);
    assert_eq!(out.state.status_message, None, "no modal to close means no status message either");
}

#[test]
fn url_open_failed_resurfaces_the_prompt_with_an_error() {
    let mut prompt = OpenUrlPrompt::new(uuid::Uuid::new_v4());
    prompt.is_submitting = true;
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::OpenUrl(prompt));

    let out = reduce(&state, AppEvent::UrlOpenFailed("boom".to_string()));
    let Some(Modal::OpenUrl(p)) = &out.state.modal else { panic!() };
    assert!(!p.is_submitting);
    assert_eq!(p.error, Some("boom".to_string()));
}
