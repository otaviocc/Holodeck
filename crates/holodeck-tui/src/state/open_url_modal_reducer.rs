use super::app_state::{AppState, Modal, OpenUrlPrompt};
use super::event::{ReducerOutput, SideEffect};
use super::key::{Key, is_printable};

pub fn handle(state: &AppState, prompt: &OpenUrlPrompt, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    let mut updated = prompt.clone();

    match key {
        Key::Escape => {
            next.modal = None;
            return ReducerOutput::new(next);
        }
        Key::Enter => {
            if updated.url.is_empty() || updated.is_submitting {
                next.modal = Some(Modal::OpenUrl(updated));
                return ReducerOutput::new(next);
            }
            updated.is_submitting = true;
            updated.error = None;
            let effect = SideEffect::OpenUrl {
                udid: updated.simulator_id,
                url: updated.url.clone(),
            };
            next.modal = Some(Modal::OpenUrl(updated));
            return ReducerOutput::with_effects(next, vec![effect]);
        }
        Key::Backspace => {
            if !updated.url.is_empty() {
                updated.url.pop();
            }
            updated.history_index = -1;
            updated.error = None;
        }
        Key::Up => {
            let history = &state.url_history;
            if !history.is_empty() {
                updated.history_index = (updated.history_index + 1).min(history.len() as i64 - 1);
                updated.url = history[updated.history_index as usize].clone();
                updated.error = None;
            }
        }
        Key::Down => {
            let history = &state.url_history;
            updated.history_index = (updated.history_index - 1).max(-1);
            if updated.history_index >= 0 && (updated.history_index as usize) < history.len() {
                updated.url = history[updated.history_index as usize].clone();
            } else {
                updated.url = String::new();
            }
            updated.error = None;
        }
        Key::Char(c) if is_printable(c) => {
            updated.url.push(c);
            updated.history_index = -1;
            updated.error = None;
        }
        _ => {}
    }

    next.modal = Some(Modal::OpenUrl(updated));
    ReducerOutput::new(next)
}
