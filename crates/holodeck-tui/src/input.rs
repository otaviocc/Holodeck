use ratatui::crossterm::event::{KeyCode, KeyEvent, KeyEventKind};

use crate::state::Key;

/// Maps a crossterm `KeyEvent` onto the reducer's terminal-independent `Key`.
/// Only key-press events map to a `Key`; key-release events (reported by
/// terminals supporting `PushKeyboardEnhancementFlags`) yield `None`.
pub fn map_key_event(event: KeyEvent) -> Option<Key> {
    if event.kind != KeyEventKind::Press {
        return None;
    }
    Some(match event.code {
        KeyCode::Up => Key::Up,
        KeyCode::Down => Key::Down,
        KeyCode::Left => Key::Left,
        KeyCode::Right => Key::Right,
        KeyCode::Enter => Key::Enter,
        KeyCode::Esc => Key::Escape,
        KeyCode::Tab => Key::Tab,
        KeyCode::Backspace => Key::Backspace,
        KeyCode::Delete => Key::Delete,
        KeyCode::Home => Key::Home,
        KeyCode::End => Key::End,
        KeyCode::Char(c) => Key::Char(c),
        _ => Key::Unknown,
    })
}

#[cfg(test)]
mod tests {
    use ratatui::crossterm::event::{KeyModifiers, MediaKeyCode};

    use super::*;

    fn press(code: KeyCode) -> KeyEvent {
        KeyEvent::new(code, KeyModifiers::NONE)
    }

    #[test]
    fn maps_arrows_and_editing_keys() {
        assert_eq!(map_key_event(press(KeyCode::Up)), Some(Key::Up));
        assert_eq!(map_key_event(press(KeyCode::Down)), Some(Key::Down));
        assert_eq!(map_key_event(press(KeyCode::Enter)), Some(Key::Enter));
        assert_eq!(map_key_event(press(KeyCode::Esc)), Some(Key::Escape));
        assert_eq!(map_key_event(press(KeyCode::Backspace)), Some(Key::Backspace));
        assert_eq!(map_key_event(press(KeyCode::Delete)), Some(Key::Delete));
        assert_eq!(map_key_event(press(KeyCode::Home)), Some(Key::Home));
        assert_eq!(map_key_event(press(KeyCode::End)), Some(Key::End));
    }

    #[test]
    fn maps_printable_characters() {
        assert_eq!(map_key_event(press(KeyCode::Char('q'))), Some(Key::Char('q')));
    }

    #[test]
    fn unrecognized_codes_map_to_unknown() {
        assert_eq!(map_key_event(press(KeyCode::Media(MediaKeyCode::Play))), Some(Key::Unknown));
    }

    #[test]
    fn key_release_events_are_ignored() {
        let mut event = press(KeyCode::Char('a'));
        event.kind = KeyEventKind::Release;
        assert_eq!(map_key_event(event), None);
    }
}
