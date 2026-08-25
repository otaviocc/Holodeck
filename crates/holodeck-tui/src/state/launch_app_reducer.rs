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
                Key::Char('r') => {
                    if updated.selected_app().is_some() {
                        updated.step = LaunchAppStep::PickRegion;
                    }
                }
                Key::Enter => return submit(next, updated, None, None),
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
                    // Attach the choice and chain into the region picker
                    // rather than launching now — Esc there either skips
                    // the region (submits with just this language) or, if
                    // the region step is reached directly instead, cancels.
                    updated.chosen_language = Some(language);
                    updated.step = LaunchAppStep::PickRegion;
                    updated.region_index = 0;
                    updated.region_scroll_offset = 0;
                    updated.region_filter.clear();
                    updated.is_region_filter_focused = false;
                }
                _ => {}
            }
            let viewport = updated.language_viewport(state.rows);
            updated.language_scroll_offset = AppState::scroll(updated.language_scroll_offset, updated.language_index, viewport);
        }
        LaunchAppStep::PickRegion => {
            if updated.is_region_filter_focused {
                match key {
                    Key::Enter => updated.is_region_filter_focused = false,
                    Key::Backspace => {
                        updated.region_filter.pop();
                        updated.region_index = 0;
                        updated.region_scroll_offset = 0;
                    }
                    Key::Char(c) if is_printable(c) => {
                        updated.region_filter.push(c);
                        updated.region_index = 0;
                        updated.region_scroll_offset = 0;
                    }
                    Key::Escape => {
                        updated.region_filter.clear();
                        updated.is_region_filter_focused = false;
                        updated.region_index = 0;
                        updated.region_scroll_offset = 0;
                    }
                    _ => {}
                }
                next.modal = Some(Modal::LaunchApp(updated));
                return ReducerOutput::new(next);
            }
            match key {
                Key::Escape => {
                    let language = updated.chosen_language.map(|l| l.bcp47.to_string());
                    if language.is_some() {
                        // Reached via the language chain: skip the region,
                        // launch with the language alone.
                        return submit(next, updated, language, None);
                    }
                    // Reached directly (region-only attempt): cancel back.
                    updated.step = LaunchAppStep::PickApp;
                    updated.region_filter.clear();
                    updated.region_index = 0;
                    updated.region_scroll_offset = 0;
                }
                Key::Up | Key::Char('k') => updated.region_index = (updated.region_index - 1).max(0),
                Key::Down | Key::Char('j') => {
                    updated.region_index = (updated.region_index + 1).min((updated.visible_regions().len() as i64 - 1).max(0));
                }
                Key::Char('/') => updated.is_region_filter_focused = true,
                Key::Enter => {
                    let Some(region) = updated.selected_region() else {
                        next.modal = Some(Modal::LaunchApp(updated));
                        return ReducerOutput::new(next);
                    };
                    let language = updated.chosen_language.map(|l| l.bcp47.to_string());
                    let region = Some(region.region_code.to_string());
                    return submit(next, updated, language, region);
                }
                _ => {}
            }
            let viewport = updated.region_viewport(state.rows);
            updated.region_scroll_offset = AppState::scroll(updated.region_scroll_offset, updated.region_index, viewport);
        }
    }

    next.modal = Some(Modal::LaunchApp(updated));
    ReducerOutput::new(next)
}

fn submit(mut next: AppState, mut updated: LaunchAppPrompt, language: Option<String>, region: Option<String>) -> ReducerOutput {
    let Some(app) = updated.selected_app() else {
        next.modal = Some(Modal::LaunchApp(updated));
        return ReducerOutput::new(next);
    };
    let bundle_id = app.bundle_id.clone();
    updated.step = LaunchAppStep::Submitting;
    updated.error = None;
    let effect = SideEffect::LaunchApp { udid: updated.simulator_id, bundle_id, language, region };
    next.modal = Some(Modal::LaunchApp(updated));
    ReducerOutput::with_effects(next, vec![effect])
}
