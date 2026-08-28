use std::fmt;
use std::ops::Deref;

use super::key::{Key, is_printable};

/// A single-line editable text buffer with a movable caret.
///
/// `cursor` is a *character* index in `0..=value.chars().count()` — never a
/// byte offset — so multi-byte input (accents, emoji) stays safe on every
/// insert and delete. Every mutation keeps it in range; the render side reads
/// it back through `cursor()` to draw the caret in place.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct TextField {
    value: String,
    cursor: usize,
}

impl TextField {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn as_str(&self) -> &str {
        &self.value
    }

    pub fn cursor(&self) -> usize {
        self.cursor
    }

    /// Replaces the whole buffer and parks the caret at the end.
    pub fn set(&mut self, value: &str) {
        self.value.clear();
        self.value.push_str(value);
        self.cursor = self.value.chars().count();
    }

    pub fn clear(&mut self) {
        self.value.clear();
        self.cursor = 0;
    }

    /// Applies one editing key. Returns `true` only when the *text* changed,
    /// so callers can reset their selection index and scroll offset on edits
    /// while a bare caret move leaves the list where it was.
    ///
    /// Keys this does not own (Enter, Escape, Tab, Up/Down, …) return `false`
    /// untouched — each reducer matches those ahead of calling here.
    pub fn handle(&mut self, key: Key) -> bool {
        let count = self.value.chars().count();
        self.cursor = self.cursor.min(count);
        match key {
            Key::Left => {
                self.cursor = self.cursor.saturating_sub(1);
                false
            }
            Key::Right => {
                self.cursor = (self.cursor + 1).min(count);
                false
            }
            Key::Home => {
                self.cursor = 0;
                false
            }
            Key::End => {
                self.cursor = count;
                false
            }
            Key::Backspace => {
                if self.cursor == 0 {
                    return false;
                }
                self.cursor -= 1;
                self.value.remove(self.byte_offset(self.cursor));
                true
            }
            Key::Delete => {
                if self.cursor >= count {
                    return false;
                }
                self.value.remove(self.byte_offset(self.cursor));
                true
            }
            Key::Char(c) if is_printable(c) => {
                let at = self.byte_offset(self.cursor);
                self.value.insert(at, c);
                self.cursor += 1;
                true
            }
            _ => false,
        }
    }

    /// Byte offset of character index `index`; `value.len()` when `index` is
    /// the end position.
    fn byte_offset(&self, index: usize) -> usize {
        self.value.char_indices().nth(index).map_or(self.value.len(), |(offset, _)| offset)
    }
}

impl From<&str> for TextField {
    fn from(value: &str) -> Self {
        let mut field = Self::new();
        field.set(value);
        field
    }
}

impl Deref for TextField {
    type Target = str;

    fn deref(&self) -> &str {
        &self.value
    }
}

impl fmt::Display for TextField {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter.write_str(&self.value)
    }
}

impl PartialEq<&str> for TextField {
    fn eq(&self, other: &&str) -> bool {
        self.value == *other
    }
}

impl PartialEq<str> for TextField {
    fn eq(&self, other: &str) -> bool {
        self.value == other
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn apply(field: &mut TextField, keys: &[Key]) {
        for key in keys {
            field.handle(*key);
        }
    }

    #[test]
    fn typing_appends_and_moves_the_caret() {
        let mut field = TextField::new();
        apply(&mut field, &[Key::Char('a'), Key::Char('b')]);
        assert_eq!(field, "ab");
        assert_eq!(field.cursor(), 2);
    }

    #[test]
    fn left_then_typing_inserts_in_the_middle() {
        let mut field = TextField::from("ac");
        apply(&mut field, &[Key::Left, Key::Char('b')]);
        assert_eq!(field, "abc");
        assert_eq!(field.cursor(), 2);
    }

    #[test]
    fn caret_moves_do_not_report_a_text_change() {
        let mut field = TextField::from("ab");
        assert!(!field.handle(Key::Left));
        assert!(!field.handle(Key::Right));
        assert!(!field.handle(Key::Home));
        assert!(!field.handle(Key::End));
        assert_eq!(field, "ab");
    }

    #[test]
    fn caret_clamps_at_both_edges() {
        let mut field = TextField::from("ab");
        apply(&mut field, &[Key::Left, Key::Left, Key::Left]);
        assert_eq!(field.cursor(), 0);
        apply(&mut field, &[Key::Right, Key::Right, Key::Right]);
        assert_eq!(field.cursor(), 2);
    }

    #[test]
    fn backspace_deletes_before_the_caret_and_is_a_no_op_at_the_start() {
        let mut field = TextField::from("abc");
        field.handle(Key::Left);
        assert!(field.handle(Key::Backspace));
        assert_eq!(field, "ac");
        assert_eq!(field.cursor(), 1);

        field.handle(Key::Home);
        assert!(!field.handle(Key::Backspace));
        assert_eq!(field, "ac");
    }

    #[test]
    fn delete_removes_under_the_caret_and_is_a_no_op_at_the_end() {
        let mut field = TextField::from("abc");
        field.handle(Key::Home);
        assert!(field.handle(Key::Delete));
        assert_eq!(field, "bc");
        assert_eq!(field.cursor(), 0);

        field.handle(Key::End);
        assert!(!field.handle(Key::Delete));
        assert_eq!(field, "bc");
    }

    #[test]
    fn home_and_end_jump_to_the_edges() {
        let mut field = TextField::from("hello");
        field.handle(Key::Home);
        assert_eq!(field.cursor(), 0);
        field.handle(Key::End);
        assert_eq!(field.cursor(), 5);
    }

    #[test]
    fn multi_byte_characters_are_edited_by_character_not_byte() {
        let mut field = TextField::from("héé");
        assert!(field.handle(Key::Backspace));
        assert_eq!(field, "hé");
        apply(&mut field, &[Key::Left, Key::Char('👋')]);
        assert_eq!(field, "h👋é");
        assert!(field.handle(Key::Delete));
        assert_eq!(field, "h👋");
    }

    #[test]
    fn set_parks_the_caret_at_the_end_and_clear_resets_it() {
        let mut field = TextField::from("abc");
        field.handle(Key::Home);
        field.set("https://apple.com");
        assert_eq!(field.cursor(), 17);
        field.clear();
        assert_eq!(field, "");
        assert_eq!(field.cursor(), 0);
    }

    #[test]
    fn unowned_keys_are_ignored() {
        let mut field = TextField::from("ab");
        assert!(!field.handle(Key::Enter));
        assert!(!field.handle(Key::Escape));
        assert!(!field.handle(Key::Tab));
        assert!(!field.handle(Key::Char('\n')));
        assert_eq!(field, "ab");
    }
}
