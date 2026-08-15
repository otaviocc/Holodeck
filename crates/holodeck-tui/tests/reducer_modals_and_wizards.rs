mod support;

use holodeck_core::models::{DeviceType, InstalledApp, PrivacyAction, PrivacyPermission, Runtime};
use holodeck_tui::state::{
    AppEvent, CreateWizard, CreateWizardStep, Key, Modal, PendingOperation, PrivacyWizard, PrivacyWizardStep, SideEffect, reduce,
};
use support::{booted, shutdown, state_with};

// MARK: - Confirm erase / delete

#[test]
fn n_key_opens_erase_confirmation_only_for_shutdown_sims() {
    let state = state_with(vec![shutdown("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('e')));
    assert_eq!(out.state.modal, Some(Modal::ConfirmErase(state.simulators[0].id)));
}

#[test]
fn erase_is_refused_for_a_booted_simulator() {
    let state = state_with(vec![booted("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('e')));
    assert_eq!(out.state.modal, None);
    assert!(out.state.status_message.unwrap().contains("Cannot erase"));
}

#[test]
fn confirm_erase_yes_dispatches_effect_and_tracks_pending() {
    let mut state = state_with(vec![shutdown("A")]);
    let id = state.simulators[0].id;
    state.modal = Some(Modal::ConfirmErase(id));
    let out = reduce(&state, AppEvent::Key(Key::Char('y')));
    assert_eq!(out.state.modal, None);
    assert_eq!(out.effects, vec![SideEffect::EraseSimulator(id)]);
    assert_eq!(out.state.pending_operations.get(&id), Some(&PendingOperation::Erase));
}

#[test]
fn confirm_erase_no_dismisses_without_effect() {
    let mut state = state_with(vec![shutdown("A")]);
    state.modal = Some(Modal::ConfirmErase(state.simulators[0].id));
    let out = reduce(&state, AppEvent::Key(Key::Char('n')));
    assert_eq!(out.state.modal, None);
    assert!(out.effects.is_empty());
}

#[test]
fn confirm_delete_declines_if_another_operation_is_already_pending() {
    let mut state = state_with(vec![shutdown("A")]);
    let id = state.simulators[0].id;
    state.modal = Some(Modal::ConfirmDelete(id));
    state.pending_operations.insert(id, PendingOperation::Boot);
    let out = reduce(&state, AppEvent::Key(Key::Char('y')));
    assert!(out.effects.is_empty());
    assert!(out.state.status_message.unwrap().contains("pending operation"));
}

// MARK: - Appearance modal

#[test]
fn appearance_modal_light_and_dark_keys_dispatch_and_close() {
    let mut state = state_with(vec![booted("A")]);
    state.modal = Some(Modal::Appearance);
    let out = reduce(&state, AppEvent::Key(Key::Char('l')));
    assert_eq!(out.state.modal, None);
    assert_eq!(
        out.effects,
        vec![SideEffect::SetAppearance(
            state.simulators[0].id,
            holodeck_core::models::Appearance::Light
        )]
    );
}

#[test]
fn appearance_modal_escape_closes_without_effect() {
    let mut state = state_with(vec![booted("A")]);
    state.modal = Some(Modal::Appearance);
    let out = reduce(&state, AppEvent::Key(Key::Escape));
    assert_eq!(out.state.modal, None);
    assert!(out.effects.is_empty());
}

// MARK: - Help / inspector

#[test]
fn question_mark_opens_help_and_any_key_closes_it() {
    let state = state_with(vec![]);
    let opened = reduce(&state, AppEvent::Key(Key::Char('?')));
    assert_eq!(opened.state.modal, Some(Modal::Help));
    let closed = reduce(&opened.state, AppEvent::Key(Key::Char('x')));
    assert_eq!(closed.state.modal, None);
}

#[test]
fn i_opens_inspector_and_any_key_closes_it() {
    let state = state_with(vec![booted("A")]);
    let opened = reduce(&state, AppEvent::Key(Key::Char('i')));
    assert_eq!(opened.state.modal, Some(Modal::Inspector(state.simulators[0].id)));
    let closed = reduce(&opened.state, AppEvent::Key(Key::Char('x')));
    assert_eq!(closed.state.modal, None);
}

// MARK: - Create wizard

fn device_type(name: &str) -> DeviceType {
    DeviceType::new(format!("id-{name}"), name.to_string())
}

fn runtime(version: &str) -> Runtime {
    Runtime::from_identifier_with_version("com.apple.CoreSimulator.SimRuntime.iOS-18-0", Some(version)).unwrap()
}

#[test]
fn n_opens_create_wizard_and_requests_targets() {
    let state = state_with(vec![]);
    let out = reduce(&state, AppEvent::Key(Key::Char('n')));
    assert!(matches!(out.state.modal, Some(Modal::CreateWizard(_))));
    assert_eq!(out.effects, vec![SideEffect::LoadTargets]);
}

#[test]
fn targets_loaded_sorts_device_types_ascending_and_runtimes_descending() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(CreateWizard::new()));
    let out = reduce(
        &state,
        AppEvent::TargetsLoaded {
            device_types: vec![device_type("iPhone 17e"), device_type("iPad Pro")],
            runtimes: vec![runtime("17.0"), runtime("18.0")],
        },
    );
    let Some(Modal::CreateWizard(wizard)) = out.state.modal else {
        panic!("expected CreateWizard modal")
    };
    assert_eq!(wizard.device_types[0].name, "iPad Pro");
    assert_eq!(
        wizard.runtimes[0].version,
        holodeck_core::models::SemanticVersion::new(18, 0, 0)
    );
    assert_eq!(wizard.step, CreateWizardStep::PickDeviceType);
}

#[test]
fn empty_targets_leave_wizard_on_loading_step() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(CreateWizard::new()));
    let out = reduce(
        &state,
        AppEvent::TargetsLoaded {
            device_types: vec![],
            runtimes: vec![],
        },
    );
    let Some(Modal::CreateWizard(wizard)) = out.state.modal else {
        panic!()
    };
    assert_eq!(wizard.step, CreateWizardStep::Loading);
}

#[test]
fn device_type_navigation_and_filter_and_enter_advances_to_runtime() {
    let mut wizard = CreateWizard::new();
    wizard.step = CreateWizardStep::PickDeviceType;
    wizard.device_types = vec![device_type("iPhone 17 Pro"), device_type("iPad Pro")];
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(wizard));

    let filtered = reduce(&state, AppEvent::Key(Key::Char('/')));
    let filtered = reduce(&filtered.state, AppEvent::Key(Key::Char('a')));
    let filtered = reduce(&filtered.state, AppEvent::Key(Key::Char('d')));
    let Some(Modal::CreateWizard(w)) = &filtered.state.modal else {
        panic!()
    };
    assert_eq!(w.visible_device_types().len(), 1);
    assert_eq!(w.visible_device_types()[0].name, "iPad Pro");

    let confirmed_filter = reduce(&filtered.state, AppEvent::Key(Key::Enter));
    let Some(Modal::CreateWizard(w)) = &confirmed_filter.state.modal else {
        panic!()
    };
    assert!(!w.is_device_type_filter_focused);

    let advanced = reduce(&confirmed_filter.state, AppEvent::Key(Key::Enter));
    let Some(Modal::CreateWizard(w)) = &advanced.state.modal else {
        panic!()
    };
    assert_eq!(w.step, CreateWizardStep::PickRuntime);
}

#[test]
fn escape_clears_a_live_filter_before_closing_the_wizard() {
    let mut wizard = CreateWizard::new();
    wizard.step = CreateWizardStep::PickDeviceType;
    wizard.device_type_filter = "pro".to_string();
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(wizard));

    let cleared = reduce(&state, AppEvent::Key(Key::Escape));
    let Some(Modal::CreateWizard(w)) = &cleared.state.modal else {
        panic!("filter clear should keep modal open")
    };
    assert!(w.device_type_filter.is_empty());

    let closed = reduce(&cleared.state, AppEvent::Key(Key::Escape));
    assert_eq!(closed.state.modal, None);
}

#[test]
fn confirm_step_submits_create_simulator_effect() {
    let mut wizard = CreateWizard::new();
    wizard.step = CreateWizardStep::Confirm;
    wizard.device_types = vec![device_type("iPhone 17 Pro")];
    wizard.runtimes = vec![runtime("18.0")];
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(wizard));

    let out = reduce(&state, AppEvent::Key(Key::Enter));
    let Some(SideEffect::CreateSimulator { name, .. }) = out.effects.first() else {
        panic!("expected CreateSimulator effect")
    };
    assert_eq!(name, "iPhone 17 Pro (iOS 18.0)");
}

#[test]
fn simulator_create_failed_returns_to_confirm_step_with_error() {
    let mut wizard = CreateWizard::new();
    wizard.step = CreateWizardStep::Submitting;
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(wizard));

    let out = reduce(&state, AppEvent::SimulatorCreateFailed("boom".to_string()));
    let Some(Modal::CreateWizard(w)) = out.state.modal else {
        panic!()
    };
    assert_eq!(w.step, CreateWizardStep::Confirm);
    assert_eq!(w.error, Some("boom".to_string()));
}

// MARK: - Privacy wizard

fn app(bundle_id: &str, is_user: bool) -> InstalledApp {
    InstalledApp::new(bundle_id, bundle_id, None, is_user)
}

#[test]
fn capital_p_opens_privacy_wizard_and_loads_apps() {
    let state = state_with(vec![booted("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('P')));
    assert!(matches!(out.state.modal, Some(Modal::PrivacyWizard(_))));
    assert_eq!(out.effects, vec![SideEffect::LoadInstalledApps(state.simulators[0].id)]);
}

#[test]
fn privacy_wizard_refused_for_a_shutdown_simulator() {
    let state = state_with(vec![shutdown("A")]);
    let out = reduce(&state, AppEvent::Key(Key::Char('P')));
    assert_eq!(out.state.modal, None);
}

#[test]
fn apps_loaded_populates_wizard_and_advances_to_pick_app() {
    let mut state = state_with(vec![booted("A")]);
    state.modal = Some(Modal::PrivacyWizard(PrivacyWizard::new(state.simulators[0].id)));
    let out = reduce(
        &state,
        AppEvent::AppsLoaded(vec![app("com.example.a", true), app("com.example.b", false)]),
    );
    let Some(Modal::PrivacyWizard(w)) = out.state.modal else {
        panic!()
    };
    assert_eq!(w.step, PrivacyWizardStep::PickApp);
    assert_eq!(w.apps().len(), 1, "system apps hidden by default");
}

#[test]
fn s_toggles_system_apps_in_privacy_wizard() {
    let mut wizard = PrivacyWizard::new(uuid::Uuid::new_v4());
    wizard.step = PrivacyWizardStep::PickApp;
    wizard.all_apps = vec![app("com.example.a", true), app("com.example.b", false)];
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::PrivacyWizard(wizard));

    let out = reduce(&state, AppEvent::Key(Key::Char('s')));
    let Some(Modal::PrivacyWizard(w)) = out.state.modal else {
        panic!()
    };
    assert_eq!(w.apps().len(), 2);
}

#[test]
fn privacy_wizard_flow_reaches_apply_privacy_effect() {
    let sim_id = uuid::Uuid::new_v4();
    let mut wizard = PrivacyWizard::new(sim_id);
    wizard.step = PrivacyWizardStep::PickApp;
    wizard.all_apps = vec![app("com.example.a", true)];
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::PrivacyWizard(wizard));

    // pick app -> pick permission -> pick action -> submit
    let step1 = reduce(&state, AppEvent::Key(Key::Enter));
    let step2 = reduce(&step1.state, AppEvent::Key(Key::Enter));
    let out = reduce(&step2.state, AppEvent::Key(Key::Enter));

    assert_eq!(
        out.effects,
        vec![SideEffect::ApplyPrivacy {
            udid: sim_id,
            action: PrivacyAction::ALL[0],
            permission: PrivacyPermission::ALL[0],
            bundle_id: "com.example.a".to_string(),
        }]
    );
}

#[test]
fn privacy_apply_failed_returns_to_pick_action_with_error() {
    let mut wizard = PrivacyWizard::new(uuid::Uuid::new_v4());
    wizard.step = PrivacyWizardStep::Submitting;
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::PrivacyWizard(wizard));

    let out = reduce(&state, AppEvent::PrivacyApplyFailed("boom".to_string()));
    let Some(Modal::PrivacyWizard(w)) = out.state.modal else {
        panic!()
    };
    assert_eq!(w.step, PrivacyWizardStep::PickAction);
    assert_eq!(w.error, Some("boom".to_string()));
}

#[test]
fn privacy_applied_closes_modal_and_sets_status() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::PrivacyWizard(PrivacyWizard::new(uuid::Uuid::new_v4())));
    let out = reduce(
        &state,
        AppEvent::PrivacyApplied {
            bundle_id: "com.example.a".to_string(),
        },
    );
    assert_eq!(out.state.modal, None);
    assert!(out.state.status_message.unwrap().contains("com.example.a"));
}
