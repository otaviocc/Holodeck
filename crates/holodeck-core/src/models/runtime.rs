use std::cmp::Ordering;

use super::platform::Platform;
use super::semantic_version::SemanticVersion;
use super::simctl_identifiers::RUNTIME_PREFIX;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Runtime {
    pub platform: Platform,
    pub version: SemanticVersion,
    pub identifier: String,
}

impl Runtime {
    pub fn new(platform: Platform, version: SemanticVersion, identifier: impl Into<String>) -> Self {
        Self {
            platform,
            version,
            identifier: identifier.into(),
        }
    }

    pub fn from_identifier(identifier: &str) -> Option<Self> {
        let suffix = identifier.strip_prefix(RUNTIME_PREFIX)?;
        let dash = suffix.find('-')?;
        let platform_name = &suffix[..dash];
        let version_part = suffix[dash + 1..].replace('-', ".");
        let platform = Platform::from_simctl_name(platform_name)?;
        let version = SemanticVersion::parse(&version_part)?;
        Some(Self {
            platform,
            version,
            identifier: identifier.to_string(),
        })
    }

    /// Apple sometimes ships point releases under the same identifier
    /// (e.g. iOS-26-4 hosts both 26.4 and 26.4.1). Prefer the explicit
    /// version string from `simctl list --json runtimes` when available.
    pub fn from_identifier_with_version(identifier: &str, version_string: Option<&str>) -> Option<Self> {
        let parsed = Self::from_identifier(identifier)?;
        let resolved_version = version_string.and_then(SemanticVersion::parse).unwrap_or(parsed.version);
        Some(Self {
            platform: parsed.platform,
            version: resolved_version,
            identifier: identifier.to_string(),
        })
    }

    pub fn display_name(&self) -> String {
        format!("{} {}", self.platform.raw_value(), self.version)
    }
}

impl PartialOrd for Runtime {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}

impl Ord for Runtime {
    fn cmp(&self, other: &Self) -> Ordering {
        self.platform
            .raw_value()
            .cmp(other.platform.raw_value())
            .then(self.version.cmp(&other.version))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_identifier() {
        let runtime = Runtime::from_identifier("com.apple.CoreSimulator.SimRuntime.iOS-18-0").unwrap();
        assert_eq!(runtime.platform, Platform::IOS);
        assert_eq!(runtime.version, SemanticVersion::new(18, 0, 0));
    }

    #[test]
    fn version_string_overrides_identifier_derived_version() {
        let runtime =
            Runtime::from_identifier_with_version("com.apple.CoreSimulator.SimRuntime.iOS-26-4", Some("26.4.1")).unwrap();
        assert_eq!(runtime.version, SemanticVersion::new(26, 4, 1));
    }

    #[test]
    fn falls_back_to_identifier_version_when_string_absent() {
        let runtime = Runtime::from_identifier_with_version("com.apple.CoreSimulator.SimRuntime.iOS-26-4", None).unwrap();
        assert_eq!(runtime.version, SemanticVersion::new(26, 4, 0));
    }

    #[test]
    fn display_name_combines_platform_and_version() {
        let runtime = Runtime::from_identifier("com.apple.CoreSimulator.SimRuntime.iOS-18-0").unwrap();
        assert_eq!(runtime.display_name(), "iOS 18.0");
    }
}
