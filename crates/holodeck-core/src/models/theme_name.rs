use serde::{Deserialize, Serialize};

/// Which built-in TUI color theme to use. The actual colors live in
/// `holodeck-tui::theme` (a rendering concern) — this is just the selector,
/// kept in Core alongside the rest of `Config` so it round-trips through
/// `~/.config/holodeck/config.json` like `videoCodec`/`screenshotType`.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum ThemeName {
    /// The [Default+](https://github.com/otaviocc/default-plus) colorscheme.
    #[default]
    DefaultPlus,
    /// The terminal's own 16-color scheme — correct on a background whose
    /// depth/appearance nothing has detected, at the cost of not matching
    /// any specific palette exactly on every terminal.
    Ansi,
    /// [Tokyo Night](https://github.com/folke/tokyonight.nvim).
    TokyoNight,
    /// [Nord](https://www.nordtheme.com).
    Nord,
    /// [Dracula](https://draculatheme.com).
    Dracula,
    /// [Gruvbox](https://github.com/morhetz/gruvbox) dark.
    Gruvbox,
    /// [Catppuccin](https://catppuccin.com) Mocha.
    CatppuccinMocha,
    /// [Solarized](https://ethanschoonover.com/solarized/) Dark.
    SolarizedDark,
}

impl ThemeName {
    pub const ALL: [ThemeName; 8] = [
        ThemeName::DefaultPlus,
        ThemeName::Ansi,
        ThemeName::TokyoNight,
        ThemeName::Nord,
        ThemeName::Dracula,
        ThemeName::Gruvbox,
        ThemeName::CatppuccinMocha,
        ThemeName::SolarizedDark,
    ];

    pub fn raw_value(self) -> &'static str {
        match self {
            ThemeName::DefaultPlus => "default-plus",
            ThemeName::Ansi => "ansi",
            ThemeName::TokyoNight => "tokyo-night",
            ThemeName::Nord => "nord",
            ThemeName::Dracula => "dracula",
            ThemeName::Gruvbox => "gruvbox",
            ThemeName::CatppuccinMocha => "catppuccin-mocha",
            ThemeName::SolarizedDark => "solarized-dark",
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
        assert_eq!(serde_json::to_string(&ThemeName::CatppuccinMocha).unwrap(), "\"catppuccin-mocha\"");
        assert_eq!(serde_json::to_string(&ThemeName::SolarizedDark).unwrap(), "\"solarized-dark\"");
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
