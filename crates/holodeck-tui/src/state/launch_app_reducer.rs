use super::app_state::{AppState, LaunchAppPrompt, LaunchAppStep, Modal};
use super::event::{ReducerOutput, SideEffect};
use super::key::{Key, is_printable};

pub fn handle(state: &AppState, prompt: &LaunchAppPrompt, key: Key) -> ReducerOutput {
    let mut next = state.clone();
    let mut updated = prompt.clone();

    match prompt.step {
        LaunchAppStep::LoadingApps | LaunchAppStep::Submitting => {
            if let Key::Escape = key {
                next.modal = None;
            }
            return ReducerOutput::new(next);
        }
        LaunchAppStep::PickApp => {
            if let Key::Escape = key {
                next.modal = None;
                return ReducerOutput::new(next);
            }
            let viewport = LaunchAppPrompt::app_viewport(state.rows);
            match key {
                Key::Up | Key::Char('k') => updated.app_index = (updated.app_index - 1).max(0),
                Key::Down | Key::Char('j') => {
                    updated.app_index = (updated.app_index + 1).min((updated.apps().len() as i64 - 1).max(0));
                }
                Key::Char('s') => {
                    updated.show_system = !updated.show_system;
                    updated.app_index = 0;
                    updated.app_scroll_offset = 0;
                }
                Key::Char('l') => {
                    if updated.selected_app().is_some() {
                        updated.step = LaunchAppStep::PickLanguage;
                    }
                }
                Key::Enter => return submit(next, updated, None),
                _ => {}
            }
            updated.app_scroll_offset = AppState::scroll(updated.app_scroll_offset, updated.app_index, viewport);
        }
        LaunchAppStep::PickLanguage => {
            if updated.is_language_filter_focused {
                match key {
                    Key::Enter => updated.is_language_filter_focused = false,
                    Key::Backspace => {
                        updated.language_filter.pop();
                        updated.language_index = 0;
                        updated.language_scroll_offset = 0;
                    }
                    Key::Char(c) if is_printable(c) => {
                        updated.language_filter.push(c);
                        updated.language_index = 0;
                        updated.language_scroll_offset = 0;
                    }
                    Key::Escape => {
                        updated.language_filter.clear();
                        updated.is_language_filter_focused = false;
                        updated.language_index = 0;
                        updated.language_scroll_offset = 0;
                    }
                    _ => {}
                }
                next.modal = Some(Modal::LaunchApp(updated));
                return ReducerOutput::new(next);
            }
            match key {
                Key::Escape => {
                    updated.step = LaunchAppStep::PickApp;
                    updated.language_filter.clear();
                    updated.language_index = 0;
                    updated.language_scroll_offset = 0;
                }
                Key::Up | Key::Char('k') => updated.language_index = (updated.language_index - 1).max(0),
                Key::Down | Key::Char('j') => {
                    updated.language_index =
                        (updated.language_index + 1).min((updated.visible_languages().len() as i64 - 1).max(0));
                }
                Key::Char('/') => updated.is_language_filter_focused = true,
                Key::Enter => {
                    let Some(language) = updated.selected_language() else {
                        next.modal = Some(Modal::LaunchApp(updated));
                        return ReducerOutput::new(next);
                    };
                    let bcp47 = language.bcp47.to_string();
                    return submit(next, updated, Some(bcp47));
                }
                _ => {}
            }
            let viewport = updated.language_viewport(state.rows);
            updated.language_scroll_offset = AppState::scroll(updated.language_scroll_offset, updated.language_index, viewport);
        }
    }

    next.modal = Some(Modal::LaunchApp(updated));
    ReducerOutput::new(next)
}

fn submit(mut next: AppState, mut updated: LaunchAppPrompt, language: Option<String>) -> ReducerOutput {
    let Some(app) = updated.selected_app() else {
        next.modal = Some(Modal::LaunchApp(updated));
        return ReducerOutput::new(next);
    };
    let bundle_id = app.bundle_id.clone();
    updated.step = LaunchAppStep::Submitting;
    updated.error = None;
    let effect = SideEffect::LaunchApp { udid: updated.simulator_id, bundle_id, language };
    next.modal = Some(Modal::LaunchApp(updated));
    ReducerOutput::with_effects(next, vec![effect])
}
