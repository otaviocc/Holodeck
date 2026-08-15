use serde::{Deserialize, Serialize};

use super::simctl_identifiers::RUNTIME_PREFIX;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Platform {
    #[serde(rename = "iOS")]
    IOS,
    #[serde(rename = "watchOS")]
    WatchOS,
    #[serde(rename = "tvOS")]
    TvOS,
    #[serde(rename = "visionOS")]
    VisionOS,
}

impl Platform {
    pub fn raw_value(self) -> &'static str {
        match self {
            Platform::IOS => "iOS",
            Platform::WatchOS => "watchOS",
            Platform::TvOS => "tvOS",
            Platform::VisionOS => "visionOS",
        }
    }

    pub fn from_runtime_identifier(runtime_identifier: &str) -> Option<Self> {
        let suffix = runtime_identifier.strip_prefix(RUNTIME_PREFIX)?;
        let dash = suffix.find('-')?;
        Self::from_simctl_name(&suffix[..dash])
    }

    pub(crate) fn from_simctl_name(simctl_name: &str) -> Option<Self> {
        match simctl_name.to_lowercase().as_str() {
            "ios" => Some(Platform::IOS),
            "watchos" => Some(Platform::WatchOS),
            "tvos" => Some(Platform::TvOS),
            "xros" | "visionos" => Some(Platform::VisionOS),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_runtime_identifier() {
        assert_eq!(Platform::from_runtime_identifier("com.apple.CoreSimulator.SimRuntime.iOS-18-0"), Some(Platform::IOS));
    }

    #[test]
    fn xros_and_visionos_both_map_to_vision_os() {
        assert_eq!(Platform::from_simctl_name("xros"), Some(Platform::VisionOS));
        assert_eq!(Platform::from_simctl_name("visionos"), Some(Platform::VisionOS));
    }

    #[test]
    fn rejects_unknown_prefix() {
        assert_eq!(Platform::from_runtime_identifier("not-a-runtime"), None);
    }
}
