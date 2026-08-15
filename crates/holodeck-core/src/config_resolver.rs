use std::path::{Path, PathBuf};

/// Resolves the on-disk directory where holodeck stores user state, honoring
/// `$XDG_CONFIG_HOME` when set and falling back to `~/.config`.
#[derive(Debug, Clone)]
pub struct ConfigResolver {
    base: PathBuf,
}

impl ConfigResolver {
    pub fn live() -> Self {
        let parent = std::env::var("XDG_CONFIG_HOME")
            .ok()
            .filter(|xdg| !xdg.is_empty())
            .map(|xdg| PathBuf::from(shellexpand::tilde(&xdg).into_owned()))
            .or_else(|| dirs::home_dir().map(|home| home.join(".config")))
            .unwrap_or_else(|| PathBuf::from(".config"));
        Self { base: parent.join("holodeck") }
    }

    pub fn mock(base: impl Into<PathBuf>) -> Self {
        Self { base: base.into() }
    }

    pub fn base(&self) -> &Path {
        &self.base
    }

    pub fn file(&self, file_name: &str) -> PathBuf {
        self.base.join(file_name)
    }
}
