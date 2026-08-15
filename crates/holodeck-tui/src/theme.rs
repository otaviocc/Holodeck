//! Named semantic colors for the TUI, resolved once at startup from
//! `Config::theme` (Rust analogue of vigia's `theme.rs`: a struct of named
//! `Style`s with built-in palettes, rather than `Color` literals scattered
//! through the view layer).
//!
//! The shipped default is [`Theme::default_plus`] — the
//! [Default+](https://github.com/otaviocc/default-plus) colorscheme, ported
//! here from its canonical `palette.yaml` (base colors + the 6 "hero"
//! accents reused across every other Default+ port). [`Theme::ansi`] is kept
//! as an alternative that inherits the reader's own terminal scheme instead
//! of asserting truecolor.

use holodeck_core::models::ThemeName;
use ratatui::style::{Color, Modifier, Style};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Theme {
    pub background: Color,
    pub foreground: Color,
    /// Structural chrome: borders, unfocused/inactive elements.
    pub muted: Color,
    /// Secondary text: hints, footers, "press any key to close".
    pub muted_text: Color,
    pub selection_background: Color,
    pub selection_foreground: Color,
    pub red: Color,
    pub green: Color,
    pub yellow: Color,
    pub blue: Color,
    pub magenta: Color,
    pub cyan: Color,
}

impl Theme {
    pub fn from_name(name: ThemeName) -> Self {
        match name {
            ThemeName::DefaultPlus => Self::default_plus(),
            ThemeName::Ansi => Self::ansi(),
        }
    }

    /// The [Default+](https://github.com/otaviocc/default-plus) colorscheme,
    /// values taken verbatim from that repo's `palette.yaml` (`base` +
    /// `accent`).
    pub fn default_plus() -> Self {
        Self {
            background: rgb(0x1E, 0x1E, 0x1E),
            foreground: rgb(0xFF, 0xFF, 0xFF),
            muted: rgb(0x4D, 0x4D, 0x4D),
            muted_text: rgb(0x8E, 0x8E, 0x8E),
            selection_background: rgb(0x54, 0x55, 0x4A),
            selection_foreground: rgb(0xFF, 0xFF, 0xFF),
            red: rgb(0xFC, 0x46, 0x51),
            green: rgb(0x2E, 0xA8, 0x5B),
            yellow: rgb(0xFF, 0xE7, 0x6D),
            blue: rgb(0x35, 0xB0, 0xD8),
            magenta: rgb(0xF2, 0x24, 0x8C),
            cyan: rgb(0x56, 0xD0, 0xB3),
        }
    }

    /// The terminal's own 16-color scheme. Correct on a background whose
    /// depth/appearance nothing here has detected, at the cost of not
    /// matching Default+ exactly on every terminal — see vigia's `theme.rs`
    /// for the same reasoning about why an ANSI-named palette is the safe
    /// fallback rather than the default.
    pub fn ansi() -> Self {
        Self {
            background: Color::Reset,
            foreground: Color::Reset,
            muted: Color::DarkGray,
            muted_text: Color::DarkGray,
            selection_background: Color::DarkGray,
            selection_foreground: Color::White,
            red: Color::Red,
            green: Color::Green,
            yellow: Color::Yellow,
            blue: Color::Blue,
            magenta: Color::Magenta,
            cyan: Color::Cyan,
        }
    }

    // MARK: - Semantic accessors

    /// Regular body text.
    pub fn base(&self) -> Style {
        Style::new().fg(self.foreground)
    }

    /// The title bar / breadcrumb chrome.
    pub fn header(&self) -> Style {
        Style::new().fg(self.cyan).add_modifier(Modifier::BOLD)
    }

    /// Runtime group headers, the command-palette border — anything drawing
    /// attention without signaling success/warning/error.
    pub fn accent(&self) -> Style {
        Style::new().fg(self.cyan).add_modifier(Modifier::BOLD)
    }

    /// A booted simulator's indicator dot, confirmation affordances.
    pub fn success(&self) -> Style {
        Style::new().fg(self.green)
    }

    /// In-flight/transient status messages, confirm-prompt banners.
    pub fn warning(&self) -> Style {
        Style::new().fg(self.yellow)
    }

    /// `last_error`, validation failures.
    pub fn error(&self) -> Style {
        Style::new().fg(self.red)
    }

    /// Footer key hints, "press any key to close", the ghost autocomplete
    /// suffix, a shutdown simulator's indicator dot.
    pub fn hint(&self) -> Style {
        Style::new().fg(self.muted_text)
    }

    /// The main list's selected row, and the header/status/wizard-breadcrumb
    /// bars — the same filled-bar look everywhere it appears.
    pub fn bar(&self) -> Style {
        Style::new().fg(self.selection_foreground).bg(self.selection_background)
    }
}

impl Default for Theme {
    fn default() -> Self {
        Self::from_name(ThemeName::default())
    }
}

const fn rgb(r: u8, g: u8, b: u8) -> Color {
    Color::Rgb(r, g, b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_theme_is_default_plus() {
        assert_eq!(Theme::default(), Theme::default_plus());
    }

    #[test]
    fn from_name_selects_the_matching_built_in() {
        assert_eq!(Theme::from_name(ThemeName::DefaultPlus), Theme::default_plus());
        assert_eq!(Theme::from_name(ThemeName::Ansi), Theme::ansi());
    }

    #[test]
    fn default_plus_matches_the_canonical_palette_hexes() {
        let theme = Theme::default_plus();
        assert_eq!(theme.background, Color::Rgb(0x1E, 0x1E, 0x1E));
        assert_eq!(theme.selection_background, Color::Rgb(0x54, 0x55, 0x4A));
        assert_eq!(theme.green, Color::Rgb(0x2E, 0xA8, 0x5B));
        assert_eq!(theme.red, Color::Rgb(0xFC, 0x46, 0x51));
    }

    #[test]
    fn ansi_theme_uses_named_terminal_colors_not_truecolor() {
        let theme = Theme::ansi();
        assert_eq!(theme.red, Color::Red);
        assert_eq!(theme.cyan, Color::Cyan);
    }

    #[test]
    fn bar_style_pairs_selection_background_and_foreground() {
        let theme = Theme::default_plus();
        let style = theme.bar();
        assert_eq!(style.bg, Some(theme.selection_background));
        assert_eq!(style.fg, Some(theme.selection_foreground));
    }
}
