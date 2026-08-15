//! Verifies rendering logic with `ratatui::backend::TestBackend` rather than
//! a live PTY (this environment has none — see the port plan's testing
//! notes on ratatui's `TestBackend` as the CI-friendly analogue of the Swift
//! suite's ANSI-stripped `contains(...)` view assertions).

mod support;

use holodeck_core::models::InstalledApp;
use holodeck_tui::Theme;
use holodeck_tui::state::{AppState, CommandPalette, CreateWizard, Modal, OpenUrlPrompt, PrivacyWizard};
use holodeck_tui::view::render;
use ratatui::Terminal;
use ratatui::backend::TestBackend;
use support::{booted, shutdown, state_with};

fn rendered(state: &AppState) -> String {
    rendered_with(state, &Theme::default_plus())
}

fn rendered_with(state: &AppState, theme: &Theme) -> String {
    let (text, _) = render_to_text_and_buffer(state, theme);
    text
}

fn render_to_text_and_buffer(state: &AppState, theme: &Theme) -> (String, ratatui::buffer::Buffer) {
    let backend = TestBackend::new(80, 24);
    let mut terminal = Terminal::new(backend).unwrap();
    terminal.draw(|frame| render(frame, state, theme)).unwrap();
    let buffer = terminal.backend().buffer().clone();
    let area = buffer.area;
    let mut out = String::new();
    for y in 0..area.height {
        for x in 0..area.width {
            out.push_str(buffer[(x, y)].symbol());
        }
        out.push('\n');
    }
    (out, buffer)
}

#[test]
fn main_list_shows_header_and_simulators() {
    let state = state_with(vec![booted("iPhone 17 Pro"), shutdown("iPhone 12")]);
    let text = rendered(&state);
    assert!(text.contains("holodeck"));
    assert!(text.contains("iPhone 17 Pro"));
    assert!(text.contains("iPhone 12"));
    assert!(text.contains("Booted"));
    assert!(text.contains("Shutdown"));
}

#[test]
fn empty_simulator_list_shows_placeholder() {
    let state = state_with(vec![]);
    let text = rendered(&state);
    assert!(text.contains("no simulators"));
}

#[test]
fn filter_banner_appears_when_filter_is_focused() {
    let mut state = state_with(vec![booted("A")]);
    state.is_filter_focused = true;
    state.filter_query = "iPh".to_string();
    let text = rendered(&state);
    assert!(text.contains("Filter: iPh"));
}

#[test]
fn recording_banner_shows_while_recording() {
    let mut state = state_with(vec![booted("A")]);
    state.recording_device_id = Some(state.simulators[0].id);
    let text = rendered(&state);
    assert!(text.contains("Recording"));
}

#[test]
fn status_bar_shows_error_over_status_message() {
    let mut state = state_with(vec![]);
    state.status_message = Some("Refreshing…".to_string());
    state.last_error = Some("boom".to_string());
    let text = rendered(&state);
    assert!(text.contains("boom"));
}

#[test]
fn appearance_modal_banner_renders() {
    let mut state = state_with(vec![booted("A")]);
    state.modal = Some(Modal::Appearance);
    let text = rendered(&state);
    assert!(text.contains("Appearance"));
    assert!(text.contains("light"));
    assert!(text.contains("dark"));
}

#[test]
fn confirm_erase_banner_renders() {
    let mut state = state_with(vec![shutdown("A")]);
    let id = state.simulators[0].id;
    state.modal = Some(Modal::ConfirmErase(id));
    let text = rendered(&state);
    assert!(text.contains("Erase"));
}

#[test]
fn help_overlay_lists_keybindings() {
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::Help);
    let text = rendered(&state);
    assert!(text.contains("Keybindings"));
    assert!(text.contains("Navigate the simulator list"));
    assert!(text.contains("Quit"));
}

#[test]
fn inspector_shows_simulator_details() {
    let mut state = state_with(vec![booted("A")]);
    let id = state.simulators[0].id;
    state.modal = Some(Modal::Inspector(id));
    let text = rendered(&state);
    assert!(text.contains("Inspector"));
    assert!(text.contains(&id.to_string().to_uppercase()));
    assert!(text.contains("Booted"));
}

#[test]
fn open_url_prompt_shows_typed_url_and_error() {
    let mut prompt = OpenUrlPrompt::new(uuid::Uuid::new_v4());
    prompt.url = "https://apple.com".to_string();
    prompt.error = Some("bad url".to_string());
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::OpenUrl(prompt));
    let text = rendered(&state);
    assert!(text.contains("https://apple.com"));
    assert!(text.contains("bad url"));
}

#[test]
fn create_wizard_confirm_step_shows_selection() {
    use holodeck_core::models::{DeviceType, Runtime};
    let mut wizard = CreateWizard::new();
    wizard.step = holodeck_tui::state::CreateWizardStep::Confirm;
    wizard.device_types = vec![DeviceType::new("id", "iPhone 17 Pro")];
    wizard.runtimes = vec![Runtime::from_identifier("com.apple.CoreSimulator.SimRuntime.iOS-18-0").unwrap()];
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::CreateWizard(wizard));
    let text = rendered(&state);
    assert!(text.contains("iPhone 17 Pro"));
    assert!(text.contains("iOS 18.0"));
}

#[test]
fn privacy_wizard_pick_app_lists_apps() {
    let mut wizard = PrivacyWizard::new(uuid::Uuid::new_v4());
    wizard.step = holodeck_tui::state::PrivacyWizardStep::PickApp;
    wizard.all_apps = vec![InstalledApp::new("com.example.a", "Alpha", None, true)];
    let mut state = state_with(vec![]);
    state.modal = Some(Modal::PrivacyWizard(wizard));
    let text = rendered(&state);
    assert!(text.contains("Alpha"));
    assert!(text.contains("com.example.a"));
}

#[test]
fn command_palette_overlay_shows_query_and_ghost_suffix() {
    let mut state = state_with(vec![shutdown("A")]);
    state.modal = Some(Modal::CommandPalette(CommandPalette {
        simulator_id: Some(state.simulators[0].id),
        query: "bo".to_string(),
    }));
    let text = rendered(&state);
    assert!(text.contains("Command palette"));
    assert!(text.contains("bo"));
}

// MARK: - Theme wiring

#[test]
fn booted_and_shutdown_dots_use_success_and_hint_colors() {
    // A is selected (index 0); the list's highlight style patches over a
    // selected row's own colors, so B and C — left unselected — are what
    // this test checks.
    let state = state_with(vec![booted("A"), booted("B"), shutdown("C")]);
    let theme = Theme::default_plus();
    let (_, buffer) = render_to_text_and_buffer(&state, &theme);
    let dots: Vec<_> = buffer
        .content()
        .iter()
        .filter(|cell| cell.symbol() == "●" || cell.symbol() == "○")
        .collect();
    assert_eq!(dots.len(), 3, "expected two booted dots and one shutdown dot");
    assert!(
        dots.iter().any(|cell| cell.symbol() == "●" && cell.fg == theme.green),
        "an unselected booted dot should be green"
    );
    assert!(
        dots.iter().any(|cell| cell.symbol() == "○" && cell.fg == theme.muted_text),
        "the shutdown dot should be muted"
    );
}

#[test]
fn status_bar_uses_error_color_over_bar_background() {
    let mut state = state_with(vec![]);
    state.last_error = Some("boom".to_string());
    let theme = Theme::default_plus();
    let (_, buffer) = render_to_text_and_buffer(&state, &theme);
    let cell = &buffer[(1, 23)]; // inside "boom" on the bottom status-bar row
    assert_eq!(cell.fg, theme.red);
    assert_eq!(cell.bg, theme.selection_background);
}

#[test]
fn switching_to_the_ansi_theme_changes_rendered_colors() {
    // Same state, same text content, different theme: the two buffers must
    // differ (in styling — the symbols are identical), proving the theme
    // actually reaches rendering rather than being plumbed and ignored.
    let state = state_with(vec![booted("A"), shutdown("B")]);
    let (default_plus_text, default_plus_buffer) = render_to_text_and_buffer(&state, &Theme::default_plus());
    let (ansi_text, ansi_buffer) = render_to_text_and_buffer(&state, &Theme::ansi());

    assert_eq!(
        default_plus_text, ansi_text,
        "content should be identical — only styling should differ"
    );
    assert_ne!(
        default_plus_buffer, ansi_buffer,
        "the two themes should produce visibly different styling"
    );
}
