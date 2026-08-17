use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};

use crate::state::{
    AppState, CommandPalette, CreateWizard, CreateWizardStep, Modal, OpenUrlPrompt, PrivacyWizard, PrivacyWizardStep,
};
use crate::theme::Theme;

const HELP_ENTRIES: &[(&str, &str)] = &[
    ("↑ ↓ / j k", "Navigate the simulator list"),
    ("Enter / Space", "Boot or shut down the selection"),
    ("R", "Force refresh"),
    ("r", "Start / stop recording"),
    ("p", "Screenshot"),
    ("a", "Appearance submenu (l light / d dark / Esc)"),
    ("n", "New simulator wizard"),
    ("f", "Focus Simulator.app on the selection"),
    ("e", "Erase (shut-down sims only; y/n confirm)"),
    ("d", "Delete (y/n confirm)"),
    ("P", "Privacy wizard"),
    ("/", "Filter simulators by name"),
    ("i", "Inspect the selected simulator"),
    ("o", "Open a URL / deep link on the selected booted sim"),
    (":", "Command palette"),
    ("?", "Help overlay"),
    ("q / Esc", "Quit (or cancel the active modal)"),
];

pub fn render(frame: &mut Frame, state: &AppState, theme: &Theme) {
    // Always render the main simulator list first, then overlay the active modal on top.
    render_main(frame, state, theme);

    match &state.modal {
        Some(Modal::Help) => render_help(frame, theme),
        Some(Modal::Inspector(id)) => render_inspector(frame, state, theme, *id),
        Some(Modal::OpenUrl(prompt)) => render_open_url(frame, theme, prompt),
        Some(Modal::CreateWizard(wizard)) => render_create_wizard(frame, state, theme, wizard),
        Some(Modal::PrivacyWizard(wizard)) => render_privacy_wizard(frame, state, theme, wizard),
        Some(Modal::CommandPalette(palette)) => render_command_palette_overlay(frame, state, theme, palette, frame.area()),
        _ => {}
    }
}

// MARK: - Popup overlay geometry

/// Computes a centered floating popup `Rect` over `area`.
///
/// `width_pct` and `height_pct` are percentages (0–100) of `area` dimensions.
/// The result is clamped so the popup never exceeds `area`.
fn popup_rect(area: Rect, width_pct: u16, height_pct: u16) -> Rect {
    let width = (area.width * width_pct / 100).min(area.width);
    let height = (area.height * height_pct / 100).min(area.height);
    let x = area.x + (area.width.saturating_sub(width)) / 2;
    let y = area.y + (area.height.saturating_sub(height)) / 2;
    Rect { x, y, width, height }
}

/// Renders a centered floating popup with a title and returns the inner `Rect`
/// available for content (i.e. inside the border).
fn render_popup(frame: &mut Frame, area: Rect, width_pct: u16, height_pct: u16, title: &str, theme: &Theme) -> Rect {
    let popup = popup_rect(area, width_pct, height_pct);
    frame.render_widget(Clear, popup);
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(theme.accent())
        .title(format!(" {title} "))
        .style(theme.base());
    let inner = block.inner(popup);
    frame.render_widget(block, popup);
    inner
}

// MARK: - Main simulator list

fn render_main(frame: &mut Frame, state: &AppState, theme: &Theme) {
    let mut banner_rows: Vec<Line> = Vec::new();
    if state.is_recording() {
        banner_rows.push(Line::styled(" ● Recording — press r or q to stop", theme.error().add_modifier(Modifier::BOLD)));
    }
    match &state.modal {
        Some(Modal::Appearance) => {
            banner_rows.push(Line::styled(" Appearance — l: light  d: dark  Esc: cancel", theme.warning()))
        }
        Some(Modal::ConfirmErase(_)) => banner_rows.push(Line::styled(" Erase this simulator? [y]es / [n]o", theme.warning())),
        Some(Modal::ConfirmDelete(_)) => banner_rows.push(Line::styled(" Delete this simulator? [y]es / [n]o", theme.warning())),
        _ => {}
    }
    if state.is_filter_focused || !state.filter_query.is_empty() {
        banner_rows.push(Line::styled(format!(" Filter: {}_", state.filter_query), theme.base()));
    }

    let mut constraints = vec![Constraint::Length(1)]; // header
    constraints.push(Constraint::Length(banner_rows.len() as u16));
    constraints.push(Constraint::Min(1)); // list
    constraints.push(Constraint::Length(1)); // status bar
    let areas = Layout::vertical(constraints).split(frame.area());

    let header_left = " holodeck ";
    let header_right = " ⏎ toggle  : cmd  ? help  q quit ";
    let gap = (state.cols as usize).saturating_sub(header_left.len() + header_right.len());
    let header_line = Line::from(vec![
        Span::styled(header_left, theme.bar()),
        Span::styled(" ".repeat(gap), theme.bar()),
        Span::styled(header_right, theme.bar()),
    ]);
    frame.render_widget(Paragraph::new(header_line), areas[0]);
    if !banner_rows.is_empty() {
        frame.render_widget(Paragraph::new(banner_rows), areas[1]);
    }
    render_simulator_list(frame, state, theme, areas[2]);
    render_status_bar(frame, state, theme, areas[3]);
}

fn render_simulator_list(frame: &mut Frame, state: &AppState, theme: &Theme, area: Rect) {
    let visible = state.visible_simulators();
    if visible.is_empty() {
        let message = if state.simulators.is_empty() { "(no simulators)" } else { "(no matches)" };
        frame.render_widget(Paragraph::new(message).style(theme.hint()), area);
        return;
    }

    let mut items = Vec::with_capacity(visible.len() + 4);
    let mut selected_row = None;
    let mut current_runtime = None;
    for (i, sim) in visible.iter().enumerate() {
        if current_runtime != Some(&sim.runtime) {
            items.push(ListItem::new(Line::styled(sim.runtime.display_name(), theme.accent())));
            current_runtime = Some(&sim.runtime);
        }
        if i as i64 == state.selected_index {
            selected_row = Some(items.len());
        }
        let pending = state.pending_operations.get(&sim.id);
        let status = pending.map(|op| format!(" ({op:?})")).unwrap_or_default();
        let (dot, dot_style) = match sim.state.raw_value() {
            "Booted" => ("●", theme.success()),
            _ => ("○", theme.hint()),
        };
        let line = Line::from(vec![
            Span::styled(format!("  {dot} "), dot_style),
            Span::styled(format!("{}{status}  [{}]", sim.name, sim.state.raw_value()), theme.base()),
        ]);
        items.push(ListItem::new(line));
    }

    let mut list_state = ListState::default();
    list_state.select(selected_row);
    let list = List::new(items).highlight_style(theme.bar());
    frame.render_stateful_widget(list, area, &mut list_state);
}

fn render_status_bar(frame: &mut Frame, state: &AppState, theme: &Theme, area: Rect) {
    let bar = theme.bar();
    let (text, style) = if let Some(err) = &state.last_error {
        (err.clone(), bar.fg(theme.red))
    } else if let Some(msg) = &state.status_message {
        (msg.clone(), bar.fg(theme.yellow))
    } else if let Some(sim) = state.selected_simulator() {
        (format!("{} — {}", sim.name, sim.id), bar)
    } else {
        (String::new(), bar)
    };
    frame.render_widget(Paragraph::new(text).style(style), area);
}

// MARK: - Help

fn render_help(frame: &mut Frame, theme: &Theme) {
    let key_width = HELP_ENTRIES.iter().map(|(k, _)| k.len()).max().unwrap_or(0);
    // Content rows: title + blank + one per entry + blank + footer
    let content_height = (2 + HELP_ENTRIES.len() + 2) as u16;
    // Popup height: content + 2 border rows, clamped to terminal height
    let popup_height_pct = ((content_height + 2) * 100 / frame.area().height.max(1)).min(90) as u16;

    let inner = render_popup(frame, frame.area(), 60, popup_height_pct.max(40), "Keybindings", theme);

    let mut lines = vec![Line::from("")];
    for (key, description) in HELP_ENTRIES {
        lines.push(Line::styled(format!("  {key:key_width$}  {description}"), theme.base()));
    }
    lines.push(Line::from(""));
    lines.push(Line::styled("  Press any key to close", theme.hint()));
    frame.render_widget(Paragraph::new(lines), inner);
}

// MARK: - Inspector

fn render_inspector(frame: &mut Frame, state: &AppState, theme: &Theme, id: uuid::Uuid) {
    let inner = render_popup(frame, frame.area(), 70, 60, "Inspector", theme);

    let Some(sim) = state.simulators.iter().find(|s| s.id == id) else {
        frame.render_widget(
            Paragraph::new("  Simulator no longer available. Press any key to close.").style(theme.hint()),
            inner,
        );
        return;
    };
    let rows = [
        ("Name", sim.name.clone()),
        ("UDID", sim.id.to_string().to_uppercase()),
        ("Runtime", sim.runtime.display_name()),
        ("Device type", sim.device_type.name.clone()),
        ("State", sim.state.raw_value().to_string()),
        ("Available", sim.is_available.to_string()),
        ("Data path", sim.data_path.as_ref().map(|p| p.display().to_string()).unwrap_or_default()),
        ("Log path", sim.log_path.as_ref().map(|p| p.display().to_string()).unwrap_or_default()),
    ];
    let label_width = rows.iter().map(|(l, _)| l.len()).max().unwrap_or(0);
    let mut lines = vec![Line::from("")];
    for (label, value) in rows {
        lines.push(Line::styled(format!("  {label:label_width$}  {value}"), theme.base()));
    }
    lines.push(Line::from(""));
    lines.push(Line::styled("  Press any key to close", theme.hint()));
    frame.render_widget(Paragraph::new(lines).wrap(Wrap { trim: false }), inner);
}

// MARK: - Open URL

fn render_open_url(frame: &mut Frame, theme: &Theme, prompt: &OpenUrlPrompt) {
    let inner = render_popup(frame, frame.area(), 70, 40, "Open URL", theme);

    let mut lines = vec![Line::from("")];
    lines.push(Line::styled(format!("  {}_", prompt.url), theme.base()));
    lines.push(Line::from(""));
    if let Some(error) = &prompt.error {
        lines.push(Line::styled(format!("  ⚠ {error}"), theme.error()));
    } else if prompt.is_submitting {
        lines.push(Line::styled("  Opening…", theme.warning()));
    } else {
        lines.push(Line::from(""));
    }
    lines.push(Line::from(""));
    lines.push(Line::styled("  ↑/↓ history · Enter open · Esc cancel", theme.hint()));
    frame.render_widget(Paragraph::new(lines).wrap(Wrap { trim: false }), inner);
}

// MARK: - Create wizard

fn render_create_wizard(frame: &mut Frame, state: &AppState, theme: &Theme, wizard: &CreateWizard) {
    let inner = render_popup(frame, frame.area(), 80, 80, breadcrumb(wizard.step), theme);

    // Split inner area: optional filter banner, list/content, footer
    let filter_visible = wizard.is_device_type_filter_focused || !wizard.device_type_filter.is_empty();
    let filter_height = if filter_visible && wizard.step == CreateWizardStep::PickDeviceType { 1 } else { 0 };
    let areas = Layout::vertical([
        Constraint::Length(filter_height),
        Constraint::Min(1),
        Constraint::Length(1),
    ])
    .split(inner);

    if filter_height > 0 {
        frame.render_widget(
            Paragraph::new(format!("  Filter: {}_", wizard.device_type_filter)).style(theme.base()),
            areas[0],
        );
    }

    match wizard.step {
        CreateWizardStep::Loading | CreateWizardStep::Submitting => {
            frame.render_widget(Paragraph::new("  Loading…").style(theme.hint()), areas[1]);
        }
        CreateWizardStep::PickDeviceType => {
            let visible = wizard.visible_device_types();
            let items: Vec<ListItem> =
                visible.iter().map(|d| ListItem::new(Span::styled(format!("  {}", d.name), theme.base()))).collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.device_type_index).ok());
            let list = List::new(items).highlight_style(theme.bar());
            frame.render_stateful_widget(list, areas[1], &mut list_state);
        }
        CreateWizardStep::PickRuntime => {
            let items: Vec<ListItem> = wizard
                .runtimes
                .iter()
                .map(|r| ListItem::new(Span::styled(format!("  {}", r.display_name()), theme.base())))
                .collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.runtime_index).ok());
            let list = List::new(items).highlight_style(theme.bar());
            frame.render_stateful_widget(list, areas[1], &mut list_state);
        }
        CreateWizardStep::Confirm => {
            let mut lines = vec![Line::from("")];
            lines.push(Line::styled(format!("  Name:    {}", wizard.default_name()), theme.base()));
            if let Some(d) = wizard.selected_device_type() {
                lines.push(Line::styled(format!("  Device:  {}", d.name), theme.base()));
            }
            if let Some(r) = wizard.selected_runtime() {
                lines.push(Line::styled(format!("  Runtime: {}", r.display_name()), theme.base()));
            }
            if let Some(error) = &wizard.error {
                lines.push(Line::from(""));
                lines.push(Line::styled(format!("  ⚠ {error}"), theme.error()));
            }
            frame.render_widget(Paragraph::new(lines), areas[1]);
        }
    }

    frame.render_widget(Paragraph::new(wizard_footer_hint(wizard.step)).style(theme.hint()), areas[2]);

    // Keep scroll math consistent with the popup inner height.
    let _ = state;
}

fn breadcrumb(step: CreateWizardStep) -> &'static str {
    match step {
        CreateWizardStep::Loading => "New simulator — loading…",
        CreateWizardStep::PickDeviceType => "New simulator — device type",
        CreateWizardStep::PickRuntime => "New simulator — runtime",
        CreateWizardStep::Confirm => "New simulator — confirm",
        CreateWizardStep::Submitting => "New simulator — creating…",
    }
}

fn wizard_footer_hint(step: CreateWizardStep) -> &'static str {
    match step {
        CreateWizardStep::PickDeviceType => "↑/↓ select · / filter · Enter next · Esc cancel",
        CreateWizardStep::PickRuntime => "↑/↓ select · Enter next · b back · Esc cancel",
        CreateWizardStep::Confirm => "Enter/y confirm · b back · Esc cancel",
        _ => "Esc cancel",
    }
}

// MARK: - Privacy wizard

fn render_privacy_wizard(frame: &mut Frame, state: &AppState, theme: &Theme, wizard: &PrivacyWizard) {
    let inner = render_popup(frame, frame.area(), 80, 80, privacy_breadcrumb(wizard.step), theme);

    let areas = Layout::vertical([Constraint::Min(1), Constraint::Length(1)]).split(inner);

    match wizard.step {
        PrivacyWizardStep::LoadingApps | PrivacyWizardStep::Submitting => {
            frame.render_widget(Paragraph::new("  Loading…").style(theme.hint()), areas[0]);
        }
        PrivacyWizardStep::PickApp => {
            let apps = wizard.apps();
            if apps.is_empty() {
                frame.render_widget(Paragraph::new("  (no apps)").style(theme.hint()), areas[0]);
            } else {
                let items: Vec<ListItem> = apps
                    .iter()
                    .map(|a| ListItem::new(Span::styled(format!("  {} ({})", a.name, a.bundle_id), theme.base())))
                    .collect();
                let mut list_state = ListState::default();
                list_state.select(usize::try_from(wizard.app_index).ok());
                let list = List::new(items).highlight_style(theme.bar());
                frame.render_stateful_widget(list, areas[0], &mut list_state);
            }
        }
        PrivacyWizardStep::PickPermission => {
            let items: Vec<ListItem> = holodeck_core::models::PrivacyPermission::ALL
                .iter()
                .map(|p| ListItem::new(Span::styled(format!("  {}", p.raw_value()), theme.base())))
                .collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.permission_index).ok());
            let list = List::new(items).highlight_style(theme.bar());
            frame.render_stateful_widget(list, areas[0], &mut list_state);
        }
        PrivacyWizardStep::PickAction => {
            let items: Vec<ListItem> = holodeck_core::models::PrivacyAction::ALL
                .iter()
                .map(|a| ListItem::new(Span::styled(format!("  {}", a.raw_value()), theme.base())))
                .collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.action_index).ok());
            let list = List::new(items).highlight_style(theme.bar());
            frame.render_stateful_widget(list, areas[0], &mut list_state);
        }
    }

    frame.render_widget(Paragraph::new(privacy_footer_hint(wizard.step)).style(theme.hint()), areas[1]);

    let _ = state;
}

fn privacy_breadcrumb(step: PrivacyWizardStep) -> &'static str {
    match step {
        PrivacyWizardStep::LoadingApps => "Privacy — loading apps…",
        PrivacyWizardStep::PickApp => "Privacy — pick an app",
        PrivacyWizardStep::PickPermission => "Privacy — pick a permission",
        PrivacyWizardStep::PickAction => "Privacy — pick an action",
        PrivacyWizardStep::Submitting => "Privacy — applying…",
    }
}

fn privacy_footer_hint(step: PrivacyWizardStep) -> &'static str {
    match step {
        PrivacyWizardStep::PickApp => "↑/↓ select · s toggle system apps · Enter next · Esc cancel",
        PrivacyWizardStep::PickPermission => "↑/↓ select · Enter next · b back · Esc cancel",
        PrivacyWizardStep::PickAction => "↑/↓ select · Enter apply · b back · Esc cancel",
        _ => "Esc cancel",
    }
}

// MARK: - Command palette overlay

fn render_command_palette_overlay(frame: &mut Frame, state: &AppState, theme: &Theme, palette: &CommandPalette, area: Rect) {
    let box_width = area.width.saturating_sub(4).clamp(24, 60);
    let box_height = 5u16.min(area.height);
    let x = area.x + (area.width.saturating_sub(box_width)) / 2;
    let y = area.y + (area.height.saturating_sub(box_height)) / 2;
    let popup = Rect { x, y, width: box_width, height: box_height };

    frame.render_widget(Clear, popup);
    let block =
        Block::default().borders(Borders::ALL).border_style(theme.accent()).title(" Command palette ").style(theme.base());
    let inner = block.inner(popup);
    frame.render_widget(block, popup);

    let matched = crate::state::PaletteCommand::all()
        .into_iter()
        .find(|c| c.is_applicable(state.selected_simulator(), state.is_recording()) && c.matches(&palette.query));
    let ghost = matched
        .map(|c| c.display_name())
        .filter(|name| name.len() > palette.query.len())
        .map(|name| name[palette.query.chars().count()..].to_string())
        .unwrap_or_default();

    let mut lines =
        vec![Line::from(vec![Span::styled(format!("> {}", palette.query), theme.base()), Span::styled(ghost, theme.hint())])];
    if let Some(command) = matched {
        lines.push(Line::from(""));
        lines.push(Line::styled(command.description(), theme.hint()));
    }
    frame.render_widget(Paragraph::new(lines), inner);
}
