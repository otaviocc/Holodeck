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
    /// Default+ exactly on every terminal.
    Ansi,
}

impl ThemeName {
    pub fn raw_value(self) -> &'static str {
        match self {
            ThemeName::DefaultPlus => "default-plus",
            ThemeName::Ansi => "ansi",
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
    }
}
