#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct InstalledApp {
    pub bundle_id: String,
    pub name: String,
    pub version: Option<String>,
    pub is_user_app: bool,
}

impl InstalledApp {
    pub fn new(bundle_id: impl Into<String>, name: impl Into<String>, version: Option<String>, is_user_app: bool) -> Self {
        Self {
            bundle_id: bundle_id.into(),
            name: name.into(),
            version,
            is_user_app,
        }
    }
}
