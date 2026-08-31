use serde::{Deserialize, Serialize};

/// Selects a built-in TUI color theme. The colors themselves live in
/// `holodeck-tui::theme`; this selector round-trips through
/// `~/.config/holodeck/config.json` alongside the rest of `Config`.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ThemeName {
    /// The [Default+](https://github.com/otaviocc/default-plus) colorscheme.
    #[default]
    DefaultPlus,
    /// The terminal's own 16-color scheme, inheriting the reader's palette
    /// instead of asserting truecolor values.
    Ansi,
    /// [Tokyo Night](https://github.com/folke/tokyonight.nvim).
    TokyoNight,
    /// [Nord](https://www.nordtheme.com).
    Nord,
    /// [Dracula](https://draculatheme.com).
    Dracula,
    /// [Gruvbox](https://github.com/morhetz/gruvbox) dark.
    Gruvbox,
    /// [Catppuccin](https://catppuccin.com) Latte — the light flavor, and the
    /// only built-in theme that is not dark.
    CatppuccinLatte,
    /// [Catppuccin](https://catppuccin.com) Frappe.
    CatppuccinFrappe,
    /// [Catppuccin](https://catppuccin.com) Macchiato.
    CatppuccinMacchiato,
    /// [Catppuccin](https://catppuccin.com) Mocha.
    CatppuccinMocha,
    /// [Solarized](https://ethanschoonover.com/solarized/) Dark.
    SolarizedDark,
    /// [Vesper](https://github.com/raunofreiberg/vesper) — a restrained,
    /// mostly-monochrome palette with warm pastel accents.
    Vesper,
}

impl ThemeName {
    pub const ALL: [ThemeName; 12] = [
        ThemeName::DefaultPlus,
        ThemeName::Ansi,
        ThemeName::TokyoNight,
        ThemeName::Nord,
        ThemeName::Dracula,
        ThemeName::Gruvbox,
        ThemeName::CatppuccinLatte,
        ThemeName::CatppuccinFrappe,
        ThemeName::CatppuccinMacchiato,
        ThemeName::CatppuccinMocha,
        ThemeName::SolarizedDark,
        ThemeName::Vesper,
    ];

    pub fn raw_value(self) -> &'static str {
        match self {
            ThemeName::DefaultPlus => "default-plus",
            ThemeName::Ansi => "ansi",
            ThemeName::TokyoNight => "tokyo-night",
            ThemeName::Nord => "nord",
            ThemeName::Dracula => "dracula",
            ThemeName::Gruvbox => "gruvbox",
            ThemeName::CatppuccinLatte => "catppuccin-latte",
            ThemeName::CatppuccinFrappe => "catppuccin-frappe",
            ThemeName::CatppuccinMacchiato => "catppuccin-macchiato",
            ThemeName::CatppuccinMocha => "catppuccin-mocha",
            ThemeName::SolarizedDark => "solarized-dark",
            ThemeName::Vesper => "vesper",
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn default_is_default_plus() {
        assert_eq!(ThemeName::default(), ThemeName::DefaultPlus);
    }

    #[test]
    fn serializes_as_kebab_case() {
        assert_eq!(serde_json::to_string(&ThemeName::DefaultPlus).unwrap(), "\"default-plus\"");
        assert_eq!(serde_json::to_string(&ThemeName::Ansi).unwrap(), "\"ansi\"");
        assert_eq!(serde_json::to_string(&ThemeName::TokyoNight).unwrap(), "\"tokyo-night\"");
        assert_eq!(serde_json::to_string(&ThemeName::Nord).unwrap(), "\"nord\"");
        assert_eq!(serde_json::to_string(&ThemeName::Dracula).unwrap(), "\"dracula\"");
        assert_eq!(serde_json::to_string(&ThemeName::Gruvbox).unwrap(), "\"gruvbox\"");
        assert_eq!(serde_json::to_string(&ThemeName::CatppuccinLatte).unwrap(), "\"catppuccin-latte\"");
        assert_eq!(serde_json::to_string(&ThemeName::CatppuccinFrappe).unwrap(), "\"catppuccin-frappe\"");
        assert_eq!(serde_json::to_string(&ThemeName::CatppuccinMacchiato).unwrap(), "\"catppuccin-macchiato\"");
        assert_eq!(serde_json::to_string(&ThemeName::CatppuccinMocha).unwrap(), "\"catppuccin-mocha\"");
        assert_eq!(serde_json::to_string(&ThemeName::SolarizedDark).unwrap(), "\"solarized-dark\"");
        assert_eq!(serde_json::to_string(&ThemeName::Vesper).unwrap(), "\"vesper\"");
    }

    #[test]
    fn raw_value_round_trips_through_json_for_every_variant() {
        for name in ThemeName::ALL {
            let json = serde_json::to_string(&name).unwrap();
            assert_eq!(json, format!("\"{}\"", name.raw_value()));
            let parsed: ThemeName = serde_json::from_str(&json).unwrap();
            assert_eq!(parsed, name);
        }
    }
}
