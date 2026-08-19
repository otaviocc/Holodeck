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
//! of asserting truecolor. A handful of other well-known terminal/TUI
//! themes are also built in: [`Theme::tokyo_night`], [`Theme::nord`],
//! [`Theme::dracula`], [`Theme::gruvbox`], [`Theme::catppuccin_mocha`],
//! [`Theme::solarized_dark`], and [`Theme::vesper`] — all ported from each
//! project's own canonical palette values.

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
    /// Errors, validation failures, `last_error`.
    pub error: Color,
    /// Booted-simulator dot, confirmation affordances.
    pub success: Color,
    /// In-flight / transient status messages.
    pub warning: Color,
    /// Popup borders, command-palette chrome, runtime-group headers.
    pub accent: Color,
    /// Spare accent (blue slot in the original palette).
    pub highlight: Color,
    /// Spare accent (magenta slot in the original palette).
    pub notice: Color,
}

impl Theme {
    pub fn from_name(name: ThemeName) -> Self {
        match name {
            ThemeName::DefaultPlus => Self::default_plus(),
            ThemeName::Ansi => Self::ansi(),
            ThemeName::TokyoNight => Self::tokyo_night(),
            ThemeName::Nord => Self::nord(),
            ThemeName::Dracula => Self::dracula(),
            ThemeName::Gruvbox => Self::gruvbox(),
            ThemeName::CatppuccinMocha => Self::catppuccin_mocha(),
            ThemeName::SolarizedDark => Self::solarized_dark(),
            ThemeName::Vesper => Self::vesper(),
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
            error: rgb(0xFC, 0x46, 0x51),
            success: rgb(0x2E, 0xA8, 0x5B),
            warning: rgb(0xFF, 0xE7, 0x6D),
            accent: rgb(0x56, 0xD0, 0xB3),
            highlight: rgb(0x35, 0xB0, 0xD8),
            notice: rgb(0xF2, 0x24, 0x8C),
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
            error: Color::Red,
            success: Color::Green,
            warning: Color::Yellow,
            accent: Color::Cyan,
            highlight: Color::Blue,
            notice: Color::Magenta,
        }
    }

    /// [Tokyo Night](https://github.com/folke/tokyonight.nvim) (the "Night"
    /// variant), values taken from that project's canonical Lua palette.
    pub fn tokyo_night() -> Self {
        Self {
            background: rgb(0x1A, 0x1B, 0x26),
            foreground: rgb(0xC0, 0xCA, 0xF5),
            muted: rgb(0x56, 0x5F, 0x89),
            muted_text: rgb(0x56, 0x5F, 0x89),
            selection_background: rgb(0x29, 0x2E, 0x42),
            selection_foreground: rgb(0xC0, 0xCA, 0xF5),
            error: rgb(0xF7, 0x76, 0x8E),
            success: rgb(0x9E, 0xCE, 0x6A),
            warning: rgb(0xE0, 0xAF, 0x68),
            accent: rgb(0x7D, 0xCF, 0xFF),
            highlight: rgb(0x7A, 0xA2, 0xF7),
            notice: rgb(0xBB, 0x9A, 0xF7),
        }
    }

    /// [Nord](https://www.nordtheme.com), values taken from the official
    /// palette (`nord0`-`nord15`). Uses `nord8` ("frost", light blue-cyan)
    /// as the accent rather than `nord7`, matching how most terminal ports
    /// pick the brightest frost tone for emphasis.
    pub fn nord() -> Self {
        Self {
            background: rgb(0x2E, 0x34, 0x40),
            foreground: rgb(0xD8, 0xDE, 0xE9),
            muted: rgb(0x4C, 0x56, 0x6A),
            muted_text: rgb(0x4C, 0x56, 0x6A),
            selection_background: rgb(0x43, 0x4C, 0x5E),
            selection_foreground: rgb(0xEC, 0xEF, 0xF4),
            error: rgb(0xBF, 0x61, 0x6A),
            success: rgb(0xA3, 0xBE, 0x8C),
            warning: rgb(0xEB, 0xCB, 0x8B),
            accent: rgb(0x88, 0xC0, 0xD0),
            highlight: rgb(0x81, 0xA1, 0xC1),
            notice: rgb(0xB4, 0x8E, 0xAD),
        }
    }

    /// [Dracula](https://draculatheme.com), values taken from the official
    /// spec. Dracula has no distinct "blue" — its own ANSI spec maps the
    /// blue slot to the purple hex, which this mirrors.
    pub fn dracula() -> Self {
        Self {
            background: rgb(0x28, 0x2A, 0x36),
            foreground: rgb(0xF8, 0xF8, 0xF2),
            muted: rgb(0x62, 0x72, 0xA4),
            muted_text: rgb(0x62, 0x72, 0xA4),
            selection_background: rgb(0x44, 0x47, 0x5A),
            selection_foreground: rgb(0xF8, 0xF8, 0xF2),
            error: rgb(0xFF, 0x55, 0x55),
            success: rgb(0x50, 0xFA, 0x7B),
            warning: rgb(0xF1, 0xFA, 0x8C),
            accent: rgb(0x8B, 0xE9, 0xFD),
            // Dracula's own ANSI spec maps "blue" to the purple hex.
            highlight: rgb(0xBD, 0x93, 0xF9),
            notice: rgb(0xFF, 0x79, 0xC6),
        }
    }

    /// [Gruvbox](https://github.com/morhetz/gruvbox) dark, "bright" accent
    /// set (gruvbox's neutral tones are deliberately desaturated/earthy;
    /// the bright set reads better as foreground text on its own dark
    /// background, which is how most terminal ports use it for ANSI 8-15).
    pub fn gruvbox() -> Self {
        Self {
            background: rgb(0x28, 0x28, 0x28),
            foreground: rgb(0xEB, 0xDB, 0xB2),
            muted: rgb(0x92, 0x83, 0x74),
            muted_text: rgb(0x92, 0x83, 0x74),
            selection_background: rgb(0x50, 0x49, 0x45),
            selection_foreground: rgb(0xFB, 0xF1, 0xC7),
            error: rgb(0xFB, 0x49, 0x34),
            success: rgb(0xB8, 0xBB, 0x26),
            warning: rgb(0xFA, 0xBD, 0x2F),
            accent: rgb(0x8E, 0xC0, 0x7C),
            highlight: rgb(0x83, 0xA5, 0x98),
            notice: rgb(0xD3, 0x86, 0x9B),
        }
    }

    /// [Catppuccin](https://catppuccin.com) Mocha, values taken from the
    /// official palette.
    pub fn catppuccin_mocha() -> Self {
        Self {
            background: rgb(0x1E, 0x1E, 0x2E),
            foreground: rgb(0xCD, 0xD6, 0xF4),
            muted: rgb(0x6C, 0x70, 0x86),
            muted_text: rgb(0xA6, 0xAD, 0xC8),
            selection_background: rgb(0x45, 0x47, 0x5A),
            selection_foreground: rgb(0xCD, 0xD6, 0xF4),
            error: rgb(0xF3, 0x8B, 0xA8),
            success: rgb(0xA6, 0xE3, 0xA1),
            warning: rgb(0xF9, 0xE2, 0xAF),
            accent: rgb(0x94, 0xE2, 0xD5),
            highlight: rgb(0x89, 0xB4, 0xFA),
            notice: rgb(0xCB, 0xA6, 0xF7),
        }
    }

    /// [Solarized](https://ethanschoonover.com/solarized/) Dark, values
    /// taken from the official base16 spec (`base03`-`base3`).
    pub fn solarized_dark() -> Self {
        Self {
            background: rgb(0x00, 0x2B, 0x36),
            foreground: rgb(0x83, 0x94, 0x96),
            muted: rgb(0x58, 0x6E, 0x75),
            muted_text: rgb(0x58, 0x6E, 0x75),
            selection_background: rgb(0x07, 0x36, 0x42),
            selection_foreground: rgb(0x93, 0xA1, 0xA1),
            error: rgb(0xDC, 0x32, 0x2F),
            success: rgb(0x85, 0x99, 0x00),
            warning: rgb(0xB5, 0x89, 0x00),
            accent: rgb(0x2A, 0xA1, 0x98),
            highlight: rgb(0x26, 0x8B, 0xD2),
            notice: rgb(0xD3, 0x36, 0x82),
        }
    }

    /// [Vesper](https://github.com/raunofreiberg/vesper) — an ultra-muted,
    /// near-monochromatic palette with warm pastel accents. Values taken
    /// from the canonical VS Code theme.
    pub fn vesper() -> Self {
        Self {
            background: rgb(0x10, 0x10, 0x10),
            foreground: rgb(0xFF, 0xFF, 0xFF),
            muted: rgb(0x50, 0x50, 0x50),
            muted_text: rgb(0x7E, 0x7E, 0x7E),
            selection_background: rgb(0x23, 0x23, 0x23),
            selection_foreground: rgb(0xFF, 0xFF, 0xFF),
            error: rgb(0xFF, 0x80, 0x80),
            success: rgb(0x90, 0xB9, 0x9F),
            warning: rgb(0xFF, 0xC7, 0x99),
            accent: rgb(0xFF, 0xC7, 0x99),
            highlight: rgb(0xF5, 0x91, 0xB2),
            notice: rgb(0xEC, 0xAA, 0xD6),
        }
    }

    // MARK: - Semantic accessors

    /// Regular body text.
    pub fn base(&self) -> Style {
        Style::new().fg(self.foreground)
    }

    /// The title bar / breadcrumb chrome.
    pub fn header(&self) -> Style {
        Style::new().fg(self.accent).add_modifier(Modifier::BOLD)
    }

    /// Runtime group headers, the command-palette border — anything drawing
    /// attention without signaling success/warning/error.
    pub fn accent_style(&self) -> Style {
        Style::new().fg(self.accent).add_modifier(Modifier::BOLD)
    }

    /// A booted simulator's indicator dot, confirmation affordances.
    pub fn success(&self) -> Style {
        Style::new().fg(self.success)
    }

    /// In-flight/transient status messages, confirm-prompt banners.
    pub fn warning(&self) -> Style {
        Style::new().fg(self.warning)
    }

    /// `last_error`, validation failures.
    pub fn error(&self) -> Style {
        Style::new().fg(self.error)
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
    fn from_name_selects_the_matching_built_in_for_every_theme() {
        assert_eq!(Theme::from_name(ThemeName::DefaultPlus), Theme::default_plus());
        assert_eq!(Theme::from_name(ThemeName::Ansi), Theme::ansi());
        assert_eq!(Theme::from_name(ThemeName::TokyoNight), Theme::tokyo_night());
        assert_eq!(Theme::from_name(ThemeName::Nord), Theme::nord());
        assert_eq!(Theme::from_name(ThemeName::Dracula), Theme::dracula());
        assert_eq!(Theme::from_name(ThemeName::Gruvbox), Theme::gruvbox());
        assert_eq!(Theme::from_name(ThemeName::CatppuccinMocha), Theme::catppuccin_mocha());
        assert_eq!(Theme::from_name(ThemeName::SolarizedDark), Theme::solarized_dark());
        assert_eq!(Theme::from_name(ThemeName::Vesper), Theme::vesper());
    }

    #[test]
    fn every_built_in_theme_is_reachable_from_its_theme_name() {
        for name in ThemeName::ALL {
            let _ = Theme::from_name(name);
        }
    }

    #[test]
    fn tokyo_night_matches_the_canonical_hexes() {
        let theme = Theme::tokyo_night();
        assert_eq!(theme.background, Color::Rgb(0x1A, 0x1B, 0x26));
        assert_eq!(theme.foreground, Color::Rgb(0xC0, 0xCA, 0xF5));
        assert_eq!(theme.highlight, Color::Rgb(0x7A, 0xA2, 0xF7));
        assert_eq!(theme.error, Color::Rgb(0xF7, 0x76, 0x8E));
    }

    #[test]
    fn nord_matches_the_canonical_hexes() {
        let theme = Theme::nord();
        assert_eq!(theme.background, Color::Rgb(0x2E, 0x34, 0x40));
        assert_eq!(theme.foreground, Color::Rgb(0xD8, 0xDE, 0xE9));
        assert_eq!(theme.accent, Color::Rgb(0x88, 0xC0, 0xD0));
        assert_eq!(theme.error, Color::Rgb(0xBF, 0x61, 0x6A));
    }

    #[test]
    fn dracula_matches_the_canonical_hexes_and_highlight_borrows_purple() {
        let theme = Theme::dracula();
        assert_eq!(theme.background, Color::Rgb(0x28, 0x2A, 0x36));
        assert_eq!(theme.foreground, Color::Rgb(0xF8, 0xF8, 0xF2));
        assert_eq!(theme.accent, Color::Rgb(0x8B, 0xE9, 0xFD));
        // Dracula's own ANSI spec maps "blue" to the purple hex.
        assert_eq!(theme.highlight, Color::Rgb(0xBD, 0x93, 0xF9));
    }

    #[test]
    fn gruvbox_matches_the_canonical_hexes() {
        let theme = Theme::gruvbox();
        assert_eq!(theme.background, Color::Rgb(0x28, 0x28, 0x28));
        assert_eq!(theme.foreground, Color::Rgb(0xEB, 0xDB, 0xB2));
        assert_eq!(theme.warning, Color::Rgb(0xFA, 0xBD, 0x2F));
    }

    #[test]
    fn catppuccin_mocha_matches_the_canonical_hexes() {
        let theme = Theme::catppuccin_mocha();
        assert_eq!(theme.background, Color::Rgb(0x1E, 0x1E, 0x2E));
        assert_eq!(theme.foreground, Color::Rgb(0xCD, 0xD6, 0xF4));
        assert_eq!(theme.highlight, Color::Rgb(0x89, 0xB4, 0xFA));
        assert_eq!(theme.notice, Color::Rgb(0xCB, 0xA6, 0xF7));
    }

    #[test]
    fn vesper_matches_the_canonical_hexes() {
        let theme = Theme::vesper();
        assert_eq!(theme.background, Color::Rgb(0x10, 0x10, 0x10));
        assert_eq!(theme.foreground, Color::Rgb(0xFF, 0xFF, 0xFF));
        assert_eq!(theme.muted, Color::Rgb(0x50, 0x50, 0x50));
        assert_eq!(theme.error, Color::Rgb(0xFF, 0x80, 0x80));
        assert_eq!(theme.accent, Color::Rgb(0xFF, 0xC7, 0x99));
    }

    #[test]
    fn solarized_dark_matches_the_canonical_hexes() {
        let theme = Theme::solarized_dark();
        assert_eq!(theme.background, Color::Rgb(0x00, 0x2B, 0x36));
        assert_eq!(theme.foreground, Color::Rgb(0x83, 0x94, 0x96));
        assert_eq!(theme.highlight, Color::Rgb(0x26, 0x8B, 0xD2));
        assert_eq!(theme.warning, Color::Rgb(0xB5, 0x89, 0x00));
    }

    #[test]
    fn every_built_in_theme_is_visually_distinct() {
        let themes = ThemeName::ALL.map(Theme::from_name);
        for (i, a) in themes.iter().enumerate() {
            for b in &themes[i + 1..] {
                assert_ne!(a, b, "two built-in themes should never be identical");
            }
        }
    }

    #[test]
    fn default_plus_matches_the_canonical_palette_hexes() {
        let theme = Theme::default_plus();
        assert_eq!(theme.background, Color::Rgb(0x1E, 0x1E, 0x1E));
        assert_eq!(theme.selection_background, Color::Rgb(0x54, 0x55, 0x4A));
        assert_eq!(theme.success, Color::Rgb(0x2E, 0xA8, 0x5B));
        assert_eq!(theme.error, Color::Rgb(0xFC, 0x46, 0x51));
    }

    #[test]
    fn ansi_theme_uses_named_terminal_colors_not_truecolor() {
        let theme = Theme::ansi();
        assert_eq!(theme.error, Color::Red);
        assert_eq!(theme.accent, Color::Cyan);
    }

    #[test]
    fn bar_style_pairs_selection_background_and_foreground() {
        let theme = Theme::default_plus();
        let style = theme.bar();
        assert_eq!(style.bg, Some(theme.selection_background));
        assert_eq!(style.fg, Some(theme.selection_foreground));
    }
}
