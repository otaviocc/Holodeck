use std::path::PathBuf;

use serde::{Deserialize, Serialize};

use crate::config_resolver::ConfigResolver;
use crate::models::{Platform, ScreenshotType, ThemeName, VideoCodec};

fn default_screenshots_directory() -> String {
    "~/Desktop".to_string()
}

fn default_poll_interval_seconds() -> f64 {
    2.0
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Config {
    #[serde(default)]
    pub default_platform: Option<Platform>,
    #[serde(default = "default_screenshots_directory")]
    pub screenshots_directory: String,
    #[serde(default)]
    pub video_codec: VideoCodec,
    #[serde(default)]
    pub screenshot_type: ScreenshotType,
    #[serde(default = "default_poll_interval_seconds")]
    pub poll_interval_seconds: f64,
    #[serde(default)]
    pub theme: ThemeName,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            default_platform: None,
            screenshots_directory: default_screenshots_directory(),
            video_codec: VideoCodec::default(),
            screenshot_type: ScreenshotType::default(),
            poll_interval_seconds: default_poll_interval_seconds(),
            theme: ThemeName::default(),
        }
    }
}

impl Config {
    pub fn resolved_screenshots_directory(&self) -> PathBuf {
        PathBuf::from(shellexpand::tilde(&self.screenshots_directory).into_owned())
    }
}

const CONFIG_FILE_NAME: &str = "config.json";

pub struct ConfigLoader {
    path: PathBuf,
}

impl ConfigLoader {
    pub fn new(resolver: &ConfigResolver) -> Self {
        Self { path: resolver.file(CONFIG_FILE_NAME) }
    }

    pub fn load(&self) -> Result<Config, ConfigLoadError> {
        let data = match std::fs::read(&self.path) {
            Ok(data) => data,
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => return Ok(Config::default()),
            Err(err) => return Err(ConfigLoadError::Io(err)),
        };
        serde_json::from_slice(&data).map_err(ConfigLoadError::Json)
    }

    pub fn load_or_default(&self) -> Config {
        self.load().unwrap_or_default()
    }
}

#[derive(Debug, thiserror::Error)]
pub enum ConfigLoadError {
    #[error(transparent)]
    Io(std::io::Error),
    #[error(transparent)]
    Json(serde_json::Error),
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn missing_file_returns_default() {
        let dir = tempfile::tempdir().unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        let config = ConfigLoader::new(&resolver).load().unwrap();
        assert_eq!(config, Config::default());
    }

    #[test]
    fn missing_fields_fall_back_to_defaults() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join(CONFIG_FILE_NAME), r#"{"videoCodec":"hevc"}"#).unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        let config = ConfigLoader::new(&resolver).load().unwrap();
        assert_eq!(config.video_codec, VideoCodec::Hevc);
        assert_eq!(config.screenshots_directory, "~/Desktop");
    }

    #[test]
    fn malformed_json_errors() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join(CONFIG_FILE_NAME), "not json").unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        assert!(ConfigLoader::new(&resolver).load().is_err());
    }

    #[test]
    fn load_or_default_swallows_errors() {
        let dir = tempfile::tempdir().unwrap();
        std::fs::write(dir.path().join(CONFIG_FILE_NAME), "not json").unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        assert_eq!(ConfigLoader::new(&resolver).load_or_default(), Config::default());
    }

    #[test]
    fn resolves_tilde_in_screenshots_directory() {
        let config = Config::default();
        assert!(!config.resolved_screenshots_directory().to_string_lossy().contains('~'));
    }

    #[test]
    fn theme_defaults_to_default_plus_and_can_be_overridden() {
        let dir = tempfile::tempdir().unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        let default_config = ConfigLoader::new(&resolver).load().unwrap();
        assert_eq!(default_config.theme, ThemeName::DefaultPlus);

        std::fs::write(dir.path().join(CONFIG_FILE_NAME), r#"{"theme":"ansi"}"#).unwrap();
        let overridden = ConfigLoader::new(&resolver).load().unwrap();
        assert_eq!(overridden.theme, ThemeName::Ansi);
    }

    #[test]
    fn every_theme_name_loads_from_config_under_its_raw_value() {
        for name in ThemeName::ALL {
            let dir = tempfile::tempdir().unwrap();
            let resolver = ConfigResolver::mock(dir.path());
            let json = format!(r#"{{"theme":"{}"}}"#, name.raw_value());
            std::fs::write(dir.path().join(CONFIG_FILE_NAME), &json).unwrap();
            let loaded = ConfigLoader::new(&resolver).load().unwrap();
            assert_eq!(loaded.theme, name, "{json} should load as {name:?}");
        }
    }
}
