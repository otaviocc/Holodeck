use super::app_state::{AppState, CommandPalette, Modal};
use super::event::ReducerOutput;
use super::key::{Key, is_printable};
use super::palette_command::PaletteCommand;
use super::reducer::run_command;

pub fn handle(state: &AppState, palette: &CommandPalette, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    let mut updated = palette.clone();

    match key {
        Key::Escape => {
            next.modal = None;
            return ReducerOutput::new(next);
        }
        Key::Enter => {
            if updated.query.is_empty() {
                next.modal = None;
                return ReducerOutput::new(next);
            }
            let Some(command) = top_match(&updated.query, &next) else {
                next.modal = None;
                next.last_error = Some(format!("No matching command: {}", updated.query));
                return ReducerOutput::new(next);
            };
            next.modal = None;
            return run_command(command, next);
        }
        Key::Tab => {
            if let Some(command) = top_match(&updated.query, &next) {
                // Preserve the user's typed casing; only append the
                // unmatched suffix.
                let name = command.display_name();
                let suffix = if name.chars().count() > updated.query.chars().count() {
                    name.chars().skip(updated.query.chars().count()).collect::<String>()
                } else {
                    String::new()
                };
                updated.query.push_str(&suffix);
            }
        }
        Key::Backspace => {
            if !updated.query.is_empty() {
                updated.query.pop();
            }
        }
        Key::Char(c) if is_printable(c) => {
            updated.query.push(c);
        }
        _ => {}
    }

    next.modal = Some(Modal::CommandPalette(updated));
    ReducerOutput::new(next)
}

/// First applicable command whose `display_name` begins with `query`. An
/// empty query returns the first applicable command (for Enter-from-empty).
pub fn top_match(query: &str, state: &AppState) -> Option<PaletteCommand> {
    let sim = state.selected_simulator();
    let is_recording = state.is_recording();
    PaletteCommand::all().into_iter().find(|c| c.is_applicable(sim, is_recording) && c.matches(query))
}
