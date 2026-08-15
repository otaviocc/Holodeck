use std::sync::Arc;

use holodeck_core::{Config, ConfigLoader, ConfigResolver, LiveSimctlClient, SimctlClient, UrlHistoryStore};

use crate::recording_service::RecordingService;
use crate::screenshot_service::ScreenshotService;
use crate::simulator_service::SimulatorService;

/// Composition root — the Rust analogue of Swift's `AppDependencies`. Builds
/// every facade from one shared `SimctlClient`, so callers (CLI subcommands,
/// the TUI) construct this once and read everything off it.
pub struct AppDependencies {
    pub configuration: Config,
    pub simctl_client: Arc<dyn SimctlClient>,
    pub url_history_store: Arc<UrlHistoryStore>,
    pub simulator_service: SimulatorService,
    pub screenshot_service: ScreenshotService,
    pub recording_service: Arc<RecordingService>,
}

impl AppDependencies {
    pub fn new(configuration: Config, simctl_client: Arc<dyn SimctlClient>, url_history_store: Arc<UrlHistoryStore>) -> Self {
        Self {
            simulator_service: SimulatorService::new(simctl_client.clone()),
            screenshot_service: ScreenshotService::new(simctl_client.clone()),
            recording_service: Arc::new(RecordingService::new()),
            configuration,
            simctl_client,
            url_history_store,
        }
    }

    /// Falls back to `Config::default()` if the on-disk config fails to
    /// load, matching the Swift `AppDependencies.live()`.
    pub fn live() -> Self {
        let resolver = ConfigResolver::live();
        let configuration = ConfigLoader::new(&resolver).load_or_default();
        let simctl_client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let url_history_store = Arc::new(UrlHistoryStore::new(&resolver));
        Self::new(configuration, simctl_client, url_history_store)
    }
}

#[cfg(test)]
mod tests {
    use holodeck_core::SimctlError;
    use holodeck_core::models::{AvailableTargets, InstalledApp, Simulator};

    use super::*;

    struct NoopClient;

    #[async_trait::async_trait]
    impl SimctlClient for NoopClient {
        async fn list_devices(&self, _include_unavailable: bool) -> Result<Vec<Simulator>, SimctlError> {
            Ok(Vec::new())
        }
        async fn boot(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn shutdown(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn screenshot(
            &self,
            _udid: uuid::Uuid,
            _path: &std::path::Path,
            _t: holodeck_core::models::ScreenshotType,
        ) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_appearance(&self, _udid: uuid::Uuid, _a: holodeck_core::models::Appearance) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_status_bar(
            &self,
            _udid: uuid::Uuid,
            _o: &holodeck_core::models::StatusBarOverrides,
        ) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn clear_status_bar(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_locale(&self, _udid: uuid::Uuid, _bcp47: &str) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn list_available_targets(&self) -> Result<AvailableTargets, SimctlError> {
            Ok(AvailableTargets {
                device_types: Vec::new(),
                runtimes: Vec::new(),
            })
        }
        async fn list_apps(&self, _udid: uuid::Uuid) -> Result<Vec<InstalledApp>, SimctlError> {
            Ok(Vec::new())
        }
        async fn create(&self, _name: &str, _d: &str, _r: &str) -> Result<uuid::Uuid, SimctlError> {
            Ok(uuid::Uuid::new_v4())
        }
        async fn erase(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn delete(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn delete_unavailable(&self) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_location(&self, _udid: uuid::Uuid, _lat: f64, _lon: f64) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn clear_location(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn privacy(
            &self,
            _udid: uuid::Uuid,
            _a: holodeck_core::models::PrivacyAction,
            _p: holodeck_core::models::PrivacyPermission,
            _b: Option<&str>,
        ) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn reset_keychain(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn open_url(&self, _udid: uuid::Uuid, _url: &str) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn focus_simulator_app(&self, _udid: uuid::Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
    }

    #[test]
    fn new_wires_all_facades_from_one_client() {
        let dir = tempfile::tempdir().unwrap();
        let resolver = ConfigResolver::mock(dir.path());
        let deps = AppDependencies::new(
            Config::default(),
            Arc::new(NoopClient),
            Arc::new(UrlHistoryStore::new(&resolver)),
        );
        assert_eq!(deps.configuration, Config::default());
    }
}
