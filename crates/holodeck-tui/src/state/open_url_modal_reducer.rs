use super::app_state::{AppState, Modal, OpenUrlPrompt};
use super::event::{ReducerOutput, SideEffect};
use super::key::Key;

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
            let effect = SideEffect::OpenUrl { udid: updated.simulator_id, url: updated.url.to_string() };
            next.modal = Some(Modal::OpenUrl(updated));
            return ReducerOutput::with_effects(next, vec![effect]);
        }
        Key::Up => {
            let history = &state.url_history;
            if !history.is_empty() {
                updated.history_index = (updated.history_index + 1).min(history.len() as i64 - 1);
                updated.url.set(&history[updated.history_index as usize]);
                updated.error = None;
            }
        }
        Key::Down => {
            let history = &state.url_history;
            updated.history_index = (updated.history_index - 1).max(-1);
            if updated.history_index >= 0 && (updated.history_index as usize) < history.len() {
                updated.url.set(&history[updated.history_index as usize]);
            } else {
                updated.url.clear();
            }
            updated.error = None;
        }
        // ←/→, Home/End, Backspace, Delete and printable characters all edit
        // the URL in place; only an actual text change drops out of history
        // browsing.
        _ => {
            if updated.url.handle(key) {
                updated.history_index = -1;
                updated.error = None;
            }
        }
    }

    next.modal = Some(Modal::OpenUrl(updated));
    ReducerOutput::new(next)
}
