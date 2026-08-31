//! Named semantic colors for the TUI, resolved once at startup from
//! `Config::theme` into a struct of named `Style`s the view layer reads.
//!
//! The shipped default is [`Theme::default_plus`] — the
//! [Default+](https://github.com/otaviocc/default-plus) colorscheme, ported
//! from its canonical `palette.yaml` (base colors + the 6 "hero" accents
//! reused across every other Default+ port). [`Theme::ansi`] inherits the
//! reader's own terminal scheme instead of asserting truecolor. Also built
//! in: [`Theme::tokyo_night`], [`Theme::nord`], [`Theme::dracula`],
//! [`Theme::gruvbox`], all four Catppuccin flavors
//! ([`Theme::catppuccin_latte`], [`Theme::catppuccin_frappe`],
//! [`Theme::catppuccin_macchiato`], [`Theme::catppuccin_mocha`]),
//! [`Theme::solarized_dark`], and [`Theme::vesper`] — each ported from its
//! own project's canonical palette values. Catppuccin Latte is the only
//! light built-in.

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
    /// Header text, readout numbers, chrome accents.
    pub chrome: Color,
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
            ThemeName::CatppuccinLatte => Self::catppuccin_latte(),
            ThemeName::CatppuccinFrappe => Self::catppuccin_frappe(),
            ThemeName::CatppuccinMacchiato => Self::catppuccin_macchiato(),
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
            chrome: rgb(0x56, 0xD0, 0xB3),
            highlight: rgb(0x35, 0xB0, 0xD8),
            notice: rgb(0xF2, 0x24, 0x8C),
        }
    }

    /// The terminal's own 16-color scheme, using ANSI color names so every
    /// style follows the reader's palette instead of fixed truecolor values.
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
            chrome: Color::Cyan,
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
            chrome: rgb(0x7A, 0xA2, 0xF7),
            highlight: rgb(0x7A, 0xA2, 0xF7),
            notice: rgb(0xBB, 0x9A, 0xF7),
        }
    }

    /// [Nord](https://www.nordtheme.com), values taken from the official
    /// palette (`nord0`-`nord15`), with `nord8` ("frost", light blue-cyan)
    /// as the accent.
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
            chrome: rgb(0x88, 0xC0, 0xD0),
            highlight: rgb(0x81, 0xA1, 0xC1),
            notice: rgb(0xB4, 0x8E, 0xAD),
        }
    }

    /// [Dracula](https://draculatheme.com), values taken from the official
    /// spec, whose ANSI mapping fills the blue slot with the purple hex.
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
            chrome: rgb(0xBD, 0x93, 0xF9),
            // Dracula's own ANSI spec maps "blue" to the purple hex.
            highlight: rgb(0xBD, 0x93, 0xF9),
            notice: rgb(0xFF, 0x79, 0xC6),
        }
    }

    /// [Gruvbox](https://github.com/morhetz/gruvbox) dark, using the
    /// "bright" accent set (the palette's ANSI 8-15 range) for foreground
    /// text.
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
            chrome: rgb(0x8E, 0xC0, 0x7C),
            highlight: rgb(0x83, 0xA5, 0x98),
            notice: rgb(0xD3, 0x86, 0x9B),
        }
    }

    /// [Catppuccin](https://catppuccin.com) Latte, values taken from the
    /// official palette. This is Catppuccin's light flavor and the only
    /// built-in theme with a light background, so `foreground` is a dark
    /// slate rather than the near-white every other theme uses.
    pub fn catppuccin_latte() -> Self {
        Self {
            background: rgb(0xEF, 0xF1, 0xF5),
            foreground: rgb(0x4C, 0x4F, 0x69),
            muted: rgb(0x9C, 0xA0, 0xB0),
            muted_text: rgb(0x6C, 0x6F, 0x85),
            selection_background: rgb(0xBC, 0xC0, 0xCC),
            selection_foreground: rgb(0x4C, 0x4F, 0x69),
            error: rgb(0xD2, 0x0F, 0x39),
            success: rgb(0x40, 0xA0, 0x2B),
            warning: rgb(0xDF, 0x8E, 0x1D),
            accent: rgb(0x17, 0x92, 0x99),
            chrome: rgb(0x1E, 0x66, 0xF5),
            highlight: rgb(0x1E, 0x66, 0xF5),
            notice: rgb(0x88, 0x39, 0xEF),
        }
    }

    /// [Catppuccin](https://catppuccin.com) Frappe, values taken from the
    /// official palette. The lightest of the three dark flavors.
    pub fn catppuccin_frappe() -> Self {
        Self {
            background: rgb(0x30, 0x34, 0x46),
            foreground: rgb(0xC6, 0xD0, 0xF5),
            muted: rgb(0x73, 0x79, 0x94),
            muted_text: rgb(0xA5, 0xAD, 0xCE),
            selection_background: rgb(0x51, 0x57, 0x6D),
            selection_foreground: rgb(0xC6, 0xD0, 0xF5),
            error: rgb(0xE7, 0x82, 0x84),
            success: rgb(0xA6, 0xD1, 0x89),
            warning: rgb(0xE5, 0xC8, 0x90),
            accent: rgb(0x81, 0xC8, 0xBE),
            chrome: rgb(0x8C, 0xAA, 0xEE),
            highlight: rgb(0x8C, 0xAA, 0xEE),
            notice: rgb(0xCA, 0x9E, 0xE6),
        }
    }

    /// [Catppuccin](https://catppuccin.com) Macchiato, values taken from the
    /// official palette. Sits between Frappe and Mocha in contrast.
    pub fn catppuccin_macchiato() -> Self {
        Self {
            background: rgb(0x24, 0x27, 0x3A),
            foreground: rgb(0xCA, 0xD3, 0xF5),
            muted: rgb(0x6E, 0x73, 0x8D),
            muted_text: rgb(0xA5, 0xAD, 0xCB),
            selection_background: rgb(0x49, 0x4D, 0x64),
            selection_foreground: rgb(0xCA, 0xD3, 0xF5),
            error: rgb(0xED, 0x87, 0x96),
            success: rgb(0xA6, 0xDA, 0x95),
            warning: rgb(0xEE, 0xD4, 0x9F),
            accent: rgb(0x8B, 0xD5, 0xCA),
            chrome: rgb(0x8A, 0xAD, 0xF4),
            highlight: rgb(0x8A, 0xAD, 0xF4),
            notice: rgb(0xC6, 0xA0, 0xF6),
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
            chrome: rgb(0x89, 0xB4, 0xFA),
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
            chrome: rgb(0x26, 0x8B, 0xD2),
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
            chrome: rgb(0xF5, 0x91, 0xB2),
            highlight: rgb(0xF5, 0x91, 0xB2),
            notice: rgb(0xEC, 0xAA, 0xD6),
        }
    }

    // MARK: - Semantic accessors

    /// Regular body text, over the theme's own background.
    ///
    /// The background matters as much as the foreground here: it is what the
    /// full-frame wash in `view::render` paints, and what makes popups opaque
    /// over the list behind them. Without it a theme would only ever tint the
    /// text and inherit the terminal's background, which silently breaks any
    /// light theme on a dark terminal. [`Theme::ansi`] sets `background` to
    /// [`Color::Reset`], so for that theme this stays a no-op by design.
    pub fn base(&self) -> Style {
        Style::new().fg(self.foreground).bg(self.background)
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

    /// The main list's selected row — the same filled-bar look for every
    /// highlighted row across the UI.
    pub fn bar(&self) -> Style {
        Style::new().fg(self.selection_foreground).bg(self.selection_background)
    }

    /// Full-row background wash for header and status bar.
    pub fn chrome_bar(&self) -> Style {
        Style::new().bg(self.muted)
    }

    /// Horizontal rule (hairline) between bars and content.
    pub fn rule(&self) -> Style {
        Style::new().fg(self.muted)
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
        assert_eq!(Theme::from_name(ThemeName::CatppuccinLatte), Theme::catppuccin_latte());
        assert_eq!(Theme::from_name(ThemeName::CatppuccinFrappe), Theme::catppuccin_frappe());
        assert_eq!(Theme::from_name(ThemeName::CatppuccinMacchiato), Theme::catppuccin_macchiato());
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
    fn catppuccin_latte_matches_the_canonical_hexes_and_is_the_only_light_built_in() {
        let theme = Theme::catppuccin_latte();
        assert_eq!(theme.background, Color::Rgb(0xEF, 0xF1, 0xF5));
        assert_eq!(theme.foreground, Color::Rgb(0x4C, 0x4F, 0x69));
        assert_eq!(theme.highlight, Color::Rgb(0x1E, 0x66, 0xF5));
        assert_eq!(theme.notice, Color::Rgb(0x88, 0x39, 0xEF));
        // Latte is the light flavor: unlike every other built-in, its
        // background is brighter than its foreground.
        let luma = |color| match color {
            Color::Rgb(r, g, b) => Some(u32::from(r) * 299 + u32::from(g) * 587 + u32::from(b) * 114),
            _ => None,
        };
        assert!(luma(theme.background) > luma(theme.foreground));
        for name in ThemeName::ALL {
            if name == ThemeName::CatppuccinLatte || name == ThemeName::Ansi {
                continue;
            }
            let other = Theme::from_name(name);
            assert!(
                luma(other.background) < luma(other.foreground),
                "{name:?} should be a dark theme, with a background darker than its foreground"
            );
        }
    }

    #[test]
    fn catppuccin_frappe_matches_the_canonical_hexes() {
        let theme = Theme::catppuccin_frappe();
        assert_eq!(theme.background, Color::Rgb(0x30, 0x34, 0x46));
        assert_eq!(theme.foreground, Color::Rgb(0xC6, 0xD0, 0xF5));
        assert_eq!(theme.highlight, Color::Rgb(0x8C, 0xAA, 0xEE));
        assert_eq!(theme.notice, Color::Rgb(0xCA, 0x9E, 0xE6));
    }

    #[test]
    fn catppuccin_macchiato_matches_the_canonical_hexes() {
        let theme = Theme::catppuccin_macchiato();
        assert_eq!(theme.background, Color::Rgb(0x24, 0x27, 0x3A));
        assert_eq!(theme.foreground, Color::Rgb(0xCA, 0xD3, 0xF5));
        assert_eq!(theme.highlight, Color::Rgb(0x8A, 0xAD, 0xF4));
        assert_eq!(theme.notice, Color::Rgb(0xC6, 0xA0, 0xF6));
    }

    #[test]
    fn the_four_catppuccin_flavors_darken_in_canonical_order() {
        // Latte -> Frappe -> Macchiato -> Mocha is Catppuccin's own ordering,
        // lightest to darkest. Guards against pasting one flavor's base into
        // another's constructor.
        let bases = [
            Theme::catppuccin_latte().background,
            Theme::catppuccin_frappe().background,
            Theme::catppuccin_macchiato().background,
            Theme::catppuccin_mocha().background,
        ];
        let luma = |color| match color {
            Color::Rgb(r, g, b) => u32::from(r) * 299 + u32::from(g) * 587 + u32::from(b) * 114,
            _ => unreachable!("Catppuccin flavors are all truecolor"),
        };
        for pair in bases.windows(2) {
            assert!(luma(pair[0]) > luma(pair[1]), "each Catppuccin flavor should be darker than the last");
        }
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
        assert_eq!(theme.chrome, Color::Rgb(0xF5, 0x91, 0xB2));
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

    #[test]
    fn chrome_bar_uses_muted_as_background() {
        let theme = Theme::default_plus();
        let style = theme.chrome_bar();
        assert_eq!(style.bg, Some(theme.muted));
        assert_eq!(style.fg, None);
    }

    #[test]
    fn rule_uses_muted_as_foreground() {
        let theme = Theme::default_plus();
        let style = theme.rule();
        assert_eq!(style.fg, Some(theme.muted));
        assert_eq!(style.bg, None);
    }
}
