/// Reducer-facing key abstraction, independent of the terminal backend.
/// Phase 5 maps crossterm's `KeyEvent` onto this; keeping the reducer
/// decoupled from crossterm is what lets these tests run without a terminal.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Key {
    Up,
    Down,
    Left,
    Right,
    Enter,
    Escape,
    Tab,
    Backspace,
    Char(char),
    Unknown,
}

/// Accepts anything visually representable on one line: rejects newlines/line
/// separators and C0/DEL control characters; admits letters, digits,
/// punctuation, symbols, and other whitespace.
pub fn is_printable(c: char) -> bool {
    if matches!(c, '\n' | '\r' | '\u{0B}' | '\u{0C}' | '\u{85}' | '\u{2028}' | '\u{2029}') {
        return false;
    }
    (c as u32) >= 0x20 && (c as u32) != 0x7F
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_newlines_and_control_characters() {
        assert!(!is_printable('\n'));
        assert!(!is_printable('\r'));
        assert!(!is_printable('\u{7F}'));
        assert!(!is_printable('\u{1B}'));
    }

    #[test]
    fn accepts_letters_digits_punctuation_and_space() {
        for c in ['a', 'Z', '0', '!', ' ', 'é', '—'] {
            assert!(is_printable(c), "{c:?} should be printable");
        }
    }
}
