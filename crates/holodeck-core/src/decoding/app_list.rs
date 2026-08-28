use serde::Deserialize;
use unicase::UniCase;

use crate::models::InstalledApp;

#[derive(Debug, Deserialize)]
struct RawApp {
    #[serde(rename = "CFBundleIdentifier")]
    cf_bundle_identifier: Option<String>,
    #[serde(rename = "CFBundleDisplayName")]
    cf_bundle_display_name: Option<String>,
    #[serde(rename = "CFBundleName")]
    cf_bundle_name: Option<String>,
    #[serde(rename = "CFBundleShortVersionString")]
    cf_bundle_short_version_string: Option<String>,
    #[serde(rename = "CFBundleVersion")]
    cf_bundle_version: Option<String>,
    #[serde(rename = "ApplicationType")]
    application_type: Option<String>,
}

/// Decodes the app listing. `data` is expected to already be JSON — the raw
/// OpenStep/ASCII plist from `simctl listapps` piped through
/// `plutil -convert json -o - -` (see `SimctlClient::list_apps`).
pub fn decode(data: &[u8]) -> Result<Vec<InstalledApp>, serde_json::Error> {
    let raw: std::collections::HashMap<String, RawApp> = serde_json::from_slice(data)?;
    let mut apps: Vec<InstalledApp> = raw
        .into_values()
        .filter_map(|entry| {
            let bundle_id = entry.cf_bundle_identifier?;
            let name = entry.cf_bundle_display_name.or(entry.cf_bundle_name).unwrap_or_else(|| bundle_id.clone());
            let version = entry.cf_bundle_short_version_string.or(entry.cf_bundle_version);
            let is_user_app = entry.application_type.as_deref() == Some("User");
            Some(InstalledApp::new(bundle_id, name, version, is_user_app))
        })
        .collect();
    apps.sort_by(|lhs, rhs| {
        UniCase::new(&lhs.name).cmp(&UniCase::new(&rhs.name)).then_with(|| lhs.bundle_id.cmp(&rhs.bundle_id))
    });
    Ok(apps)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn decodes_and_sorts_case_insensitively_with_bundle_id_tiebreak() {
        let json = br#"{
            "com.example.b": {"CFBundleIdentifier": "com.example.b", "CFBundleDisplayName": "alpha", "ApplicationType": "User"},
            "com.example.a": {"CFBundleIdentifier": "com.example.a", "CFBundleDisplayName": "Alpha", "ApplicationType": "System"}
        }"#;
        let apps = decode(json).unwrap();
        assert_eq!(apps.len(), 2);
        assert_eq!(apps[0].bundle_id, "com.example.a");
        assert_eq!(apps[1].bundle_id, "com.example.b");
        assert!(!apps[0].is_user_app);
        assert!(apps[1].is_user_app);
    }

    #[test]
    fn falls_back_from_display_name_to_name_to_bundle_id() {
        let json = br#"{"com.example.a": {"CFBundleIdentifier": "com.example.a"}}"#;
        let apps = decode(json).unwrap();
        assert_eq!(apps[0].name, "com.example.a");
    }

    #[test]
    fn drops_entries_without_a_bundle_identifier() {
        let json = br#"{"x": {"CFBundleDisplayName": "no id"}}"#;
        let apps = decode(json).unwrap();
        assert!(apps.is_empty());
    }
}
