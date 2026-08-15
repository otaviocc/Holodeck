use ratatui::prelude::*;
use ratatui::widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap};

use crate::state::{
    AppState, CommandPalette, CreateWizard, CreateWizardStep, Modal, OpenUrlPrompt, PrivacyWizard, PrivacyWizardStep,
};

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

pub fn render(frame: &mut Frame, state: &AppState) {
    match &state.modal {
        Some(Modal::Help) => render_help(frame),
        Some(Modal::Inspector(id)) => render_inspector(frame, state, *id),
        Some(Modal::OpenUrl(prompt)) => render_open_url(frame, prompt),
        Some(Modal::CreateWizard(wizard)) => render_create_wizard(frame, state, wizard),
        Some(Modal::PrivacyWizard(wizard)) => render_privacy_wizard(frame, state, wizard),
        _ => render_main(frame, state),
    }
}

// MARK: - Main simulator list

fn render_main(frame: &mut Frame, state: &AppState) {
    let mut banner_rows: Vec<Line> = Vec::new();
    if state.is_recording() {
        banner_rows.push(Line::styled(
            " ● Recording — press r or q to stop",
            Style::default().fg(Color::Red).add_modifier(Modifier::BOLD),
        ));
    }
    match &state.modal {
        Some(Modal::Appearance) => banner_rows.push(Line::styled(
            " Appearance — l: light  d: dark  Esc: cancel",
            Style::default().fg(Color::Yellow),
        )),
        Some(Modal::ConfirmErase(_)) => banner_rows.push(Line::styled(
            " Erase this simulator? [y]es / [n]o",
            Style::default().fg(Color::Yellow),
        )),
        Some(Modal::ConfirmDelete(_)) => banner_rows.push(Line::styled(
            " Delete this simulator? [y]es / [n]o",
            Style::default().fg(Color::Yellow),
        )),
        _ => {}
    }
    if state.is_filter_focused || !state.filter_query.is_empty() {
        banner_rows.push(Line::from(format!(" Filter: {}_", state.filter_query)));
    }

    let mut constraints = vec![Constraint::Length(1)]; // header
    constraints.push(Constraint::Length(banner_rows.len() as u16));
    constraints.push(Constraint::Min(1)); // list
    constraints.push(Constraint::Length(1)); // status bar
    let areas = Layout::vertical(constraints).split(frame.area());

    frame.render_widget(
        Paragraph::new(Line::styled(
            " holodeck — iOS Simulator manager",
            Style::default().add_modifier(Modifier::BOLD),
        )),
        areas[0],
    );
    if !banner_rows.is_empty() {
        frame.render_widget(Paragraph::new(banner_rows), areas[1]);
    }
    render_simulator_list(frame, state, areas[2]);
    render_status_bar(frame, state, areas[3]);

    if let Some(Modal::CommandPalette(palette)) = &state.modal {
        render_command_palette_overlay(frame, state, palette, frame.area());
    }
}

fn render_simulator_list(frame: &mut Frame, state: &AppState, area: Rect) {
    let visible = state.visible_simulators();
    if visible.is_empty() {
        let message = if state.simulators.is_empty() {
            "(no simulators)"
        } else {
            "(no matches)"
        };
        frame.render_widget(Paragraph::new(message), area);
        return;
    }

    let mut items = Vec::with_capacity(visible.len() + 4);
    let mut selected_row = None;
    let mut current_runtime = None;
    for (i, sim) in visible.iter().enumerate() {
        if current_runtime != Some(&sim.runtime) {
            items.push(ListItem::new(Line::styled(
                sim.runtime.display_name(),
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD),
            )));
            current_runtime = Some(&sim.runtime);
        }
        if i as i64 == state.selected_index {
            selected_row = Some(items.len());
        }
        let pending = state.pending_operations.get(&sim.id);
        let status = pending.map(|op| format!(" ({op:?})")).unwrap_or_default();
        let dot = match sim.state.raw_value() {
            "Booted" => "●",
            _ => "○",
        };
        items.push(ListItem::new(format!(
            "  {dot} {}{status}  [{}]",
            sim.name,
            sim.state.raw_value()
        )));
    }

    let mut list_state = ListState::default();
    list_state.select(selected_row);
    let list = List::new(items).highlight_style(Style::default().add_modifier(Modifier::REVERSED));
    frame.render_stateful_widget(list, area, &mut list_state);
}

fn render_status_bar(frame: &mut Frame, state: &AppState, area: Rect) {
    let (text, style) = if let Some(err) = &state.last_error {
        (err.clone(), Style::default().fg(Color::Red))
    } else if let Some(msg) = &state.status_message {
        (msg.clone(), Style::default().fg(Color::Yellow))
    } else if let Some(sim) = state.selected_simulator() {
        (format!("{} — {}", sim.name, sim.id), Style::default())
    } else {
        (String::new(), Style::default())
    };
    frame.render_widget(Paragraph::new(text).style(style.add_modifier(Modifier::REVERSED)), area);
}

// MARK: - Help

fn render_help(frame: &mut Frame) {
    let key_width = HELP_ENTRIES.iter().map(|(k, _)| k.len()).max().unwrap_or(0);
    let mut lines = vec![
        Line::styled("Keybindings", Style::default().add_modifier(Modifier::BOLD)),
        Line::from(""),
    ];
    for (key, description) in HELP_ENTRIES {
        lines.push(Line::from(format!("  {key:key_width$}  {description}")));
    }
    lines.push(Line::from(""));
    lines.push(Line::styled("Press any key to close", Style::default().fg(Color::DarkGray)));
    frame.render_widget(Paragraph::new(lines), frame.area());
}

// MARK: - Inspector

fn render_inspector(frame: &mut Frame, state: &AppState, id: uuid::Uuid) {
    let Some(sim) = state.simulators.iter().find(|s| s.id == id) else {
        frame.render_widget(
            Paragraph::new("Simulator no longer available. Press any key to close."),
            frame.area(),
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
        (
            "Data path",
            sim.data_path.as_ref().map(|p| p.display().to_string()).unwrap_or_default(),
        ),
        (
            "Log path",
            sim.log_path.as_ref().map(|p| p.display().to_string()).unwrap_or_default(),
        ),
    ];
    let label_width = rows.iter().map(|(l, _)| l.len()).max().unwrap_or(0);
    let mut lines = vec![
        Line::styled("Inspector", Style::default().add_modifier(Modifier::BOLD)),
        Line::from(""),
    ];
    for (label, value) in rows {
        lines.push(Line::from(format!("  {label:label_width$}  {value}")));
    }
    lines.push(Line::from(""));
    lines.push(Line::styled("Press any key to close", Style::default().fg(Color::DarkGray)));
    frame.render_widget(Paragraph::new(lines), frame.area());
}

// MARK: - Open URL

fn render_open_url(frame: &mut Frame, prompt: &OpenUrlPrompt) {
    let mut lines = vec![
        Line::styled("Open URL", Style::default().add_modifier(Modifier::BOLD)),
        Line::from(""),
    ];
    lines.push(Line::from(format!("  {}_", prompt.url)));
    lines.push(Line::from(""));
    if let Some(error) = &prompt.error {
        lines.push(Line::styled(format!("  ⚠ {error}"), Style::default().fg(Color::Red)));
    } else if prompt.is_submitting {
        lines.push(Line::styled("  Opening…", Style::default().fg(Color::Yellow)));
    }
    lines.push(Line::from(""));
    lines.push(Line::styled(
        "↑/↓ history · Enter open · Esc cancel",
        Style::default().fg(Color::DarkGray),
    ));
    frame.render_widget(Paragraph::new(lines).wrap(Wrap { trim: false }), frame.area());
}

// MARK: - Create wizard

fn render_create_wizard(frame: &mut Frame, state: &AppState, wizard: &CreateWizard) {
    let areas = Layout::vertical([
        Constraint::Length(1),
        Constraint::Length(1),
        Constraint::Min(1),
        Constraint::Length(1),
    ])
    .split(frame.area());
    frame.render_widget(
        Paragraph::new(Line::styled(
            breadcrumb(wizard.step),
            Style::default().add_modifier(Modifier::REVERSED),
        )),
        areas[0],
    );

    match wizard.step {
        CreateWizardStep::Loading | CreateWizardStep::Submitting => {
            frame.render_widget(Paragraph::new("Loading…"), areas[2]);
        }
        CreateWizardStep::PickDeviceType => {
            if wizard.is_device_type_filter_focused || !wizard.device_type_filter.is_empty() {
                frame.render_widget(Paragraph::new(format!("Filter: {}_", wizard.device_type_filter)), areas[1]);
            }
            let visible = wizard.visible_device_types();
            let items: Vec<ListItem> = visible.iter().map(|d| ListItem::new(d.name.clone())).collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.device_type_index).ok());
            let list = List::new(items).highlight_style(Style::default().add_modifier(Modifier::REVERSED));
            frame.render_stateful_widget(list, areas[2], &mut list_state);
        }
        CreateWizardStep::PickRuntime => {
            let items: Vec<ListItem> = wizard.runtimes.iter().map(|r| ListItem::new(r.display_name())).collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.runtime_index).ok());
            let list = List::new(items).highlight_style(Style::default().add_modifier(Modifier::REVERSED));
            frame.render_stateful_widget(list, areas[2], &mut list_state);
        }
        CreateWizardStep::Confirm => {
            let mut lines = vec![Line::from(format!("Name: {}", wizard.default_name()))];
            if let Some(d) = wizard.selected_device_type() {
                lines.push(Line::from(format!("Device: {}", d.name)));
            }
            if let Some(r) = wizard.selected_runtime() {
                lines.push(Line::from(format!("Runtime: {}", r.display_name())));
            }
            if let Some(error) = &wizard.error {
                lines.push(Line::from(""));
                lines.push(Line::styled(format!("⚠ {error}"), Style::default().fg(Color::Red)));
            }
            lines.push(Line::from(""));
            lines.push(Line::styled("Enter/y confirm · b back", Style::default().fg(Color::DarkGray)));
            frame.render_widget(Paragraph::new(lines), areas[2]);
        }
    }

    render_footer(frame, areas[3], wizard_footer_hint(wizard.step), state);
}

fn breadcrumb(step: CreateWizardStep) -> &'static str {
    match step {
        CreateWizardStep::Loading => " New simulator — loading targets…",
        CreateWizardStep::PickDeviceType => " New simulator — device type",
        CreateWizardStep::PickRuntime => " New simulator — runtime",
        CreateWizardStep::Confirm => " New simulator — confirm",
        CreateWizardStep::Submitting => " New simulator — creating…",
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

fn render_privacy_wizard(frame: &mut Frame, state: &AppState, wizard: &PrivacyWizard) {
    let areas = Layout::vertical([Constraint::Length(1), Constraint::Min(1), Constraint::Length(1)]).split(frame.area());
    frame.render_widget(
        Paragraph::new(Line::styled(
            privacy_breadcrumb(wizard.step),
            Style::default().add_modifier(Modifier::REVERSED),
        )),
        areas[0],
    );

    match wizard.step {
        PrivacyWizardStep::LoadingApps | PrivacyWizardStep::Submitting => {
            frame.render_widget(Paragraph::new("Loading…"), areas[1]);
        }
        PrivacyWizardStep::PickApp => {
            let apps = wizard.apps();
            if apps.is_empty() {
                frame.render_widget(Paragraph::new("(no apps)"), areas[1]);
            } else {
                let items: Vec<ListItem> = apps
                    .iter()
                    .map(|a| ListItem::new(format!("{} ({})", a.name, a.bundle_id)))
                    .collect();
                let mut list_state = ListState::default();
                list_state.select(usize::try_from(wizard.app_index).ok());
                let list = List::new(items).highlight_style(Style::default().add_modifier(Modifier::REVERSED));
                frame.render_stateful_widget(list, areas[1], &mut list_state);
            }
        }
        PrivacyWizardStep::PickPermission => {
            let items: Vec<ListItem> = holodeck_core::models::PrivacyPermission::ALL
                .iter()
                .map(|p| ListItem::new(p.raw_value()))
                .collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.permission_index).ok());
            let list = List::new(items).highlight_style(Style::default().add_modifier(Modifier::REVERSED));
            frame.render_stateful_widget(list, areas[1], &mut list_state);
        }
        PrivacyWizardStep::PickAction => {
            let items: Vec<ListItem> = holodeck_core::models::PrivacyAction::ALL
                .iter()
                .map(|a| ListItem::new(a.raw_value()))
                .collect();
            let mut list_state = ListState::default();
            list_state.select(usize::try_from(wizard.action_index).ok());
            let list = List::new(items).highlight_style(Style::default().add_modifier(Modifier::REVERSED));
            frame.render_stateful_widget(list, areas[1], &mut list_state);
        }
    }

    let _ = state;
    render_footer(frame, areas[2], privacy_footer_hint(wizard.step), state);
}

fn privacy_breadcrumb(step: PrivacyWizardStep) -> &'static str {
    match step {
        PrivacyWizardStep::LoadingApps => " Privacy — loading apps…",
        PrivacyWizardStep::PickApp => " Privacy — pick an app",
        PrivacyWizardStep::PickPermission => " Privacy — pick a permission",
        PrivacyWizardStep::PickAction => " Privacy — pick an action",
        PrivacyWizardStep::Submitting => " Privacy — applying…",
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

fn render_footer(frame: &mut Frame, area: Rect, hint: &str, _state: &AppState) {
    frame.render_widget(Paragraph::new(hint).style(Style::default().fg(Color::DarkGray)), area);
}

// MARK: - Command palette overlay

fn render_command_palette_overlay(frame: &mut Frame, state: &AppState, palette: &CommandPalette, area: Rect) {
    let box_width = area.width.saturating_sub(4).clamp(24, 60);
    let box_height = 5u16.min(area.height);
    let x = area.x + (area.width.saturating_sub(box_width)) / 2;
    let y = area.y + (area.height.saturating_sub(box_height)) / 2;
    let popup = Rect {
        x,
        y,
        width: box_width,
        height: box_height,
    };

    frame.render_widget(Clear, popup);
    let block = Block::default().borders(Borders::ALL).title(" Command palette ");
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

    let mut lines = vec![Line::from(vec![
        Span::raw(format!("> {}", palette.query)),
        Span::styled(ghost, Style::default().fg(Color::DarkGray)),
    ])];
    if let Some(command) = matched {
        lines.push(Line::from(""));
        lines.push(Line::styled(command.description(), Style::default().fg(Color::DarkGray)));
    }
    frame.render_widget(Paragraph::new(lines), inner);
}
