use std::sync::Arc;

use holodeck_core::models::{AvailableTargets, DeviceType, InstalledApp, Runtime, Simulator};
use holodeck_core::{SimctlClient, SimctlError};
use unicase::UniCase;
use uuid::Uuid;

/// Thin facade over `SimctlClient` — the only real logic here is
/// `resolve(query)`'s exact/substring/ambiguous precedence, mirroring the
/// Swift `SimulatorService`. The other pass-through operations exist mainly
/// so callers (CLI, TUI) don't need to hold a `dyn SimctlClient` themselves.
#[derive(Clone)]
pub struct SimulatorService {
    client: Arc<dyn SimctlClient>,
}

impl SimulatorService {
    pub fn new(client: Arc<dyn SimctlClient>) -> Self {
        Self { client }
    }

    pub async fn list(&self, include_unavailable: bool) -> Result<Vec<Simulator>, SimctlError> {
        self.client.list_devices(include_unavailable).await
    }

    pub async fn boot(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.client.boot(udid).await
    }

    pub async fn shutdown(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.client.shutdown(udid).await
    }

    pub async fn available_targets(&self) -> Result<AvailableTargets, SimctlError> {
        self.client.list_available_targets().await
    }

    pub async fn list_apps(&self, udid: Uuid) -> Result<Vec<InstalledApp>, SimctlError> {
        self.client.list_apps(udid).await
    }

    pub async fn create(&self, name: &str, device_type: &DeviceType, runtime: &Runtime) -> Result<Uuid, SimctlError> {
        self.client.create(name, &device_type.identifier, &runtime.identifier).await
    }

    pub async fn erase(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.client.erase(udid).await
    }

    pub async fn delete(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.client.delete(udid).await
    }

    pub async fn delete_unavailable(&self) -> Result<(), SimctlError> {
        self.client.delete_unavailable().await
    }

    pub async fn focus(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.client.focus_simulator_app(udid).await
    }

    pub async fn open_url(&self, udid: Uuid, url: &str) -> Result<(), SimctlError> {
        self.client.open_url(udid, url).await
    }

    /// Resolves `query` against the (available-only) simulator list: exact
    /// UDID, then exact case-insensitive name match, then unique
    /// case-insensitive substring match. Ambiguous or absent matches error.
    pub async fn resolve(&self, query: &str) -> Result<Simulator, SimctlError> {
        let all = self.list(false).await?;

        if let Ok(uuid) = Uuid::parse_str(query)
            && let Some(matched) = all.iter().find(|sim| sim.id == uuid)
        {
            return Ok(matched.clone());
        }

        let needle = UniCase::new(query);
        let needle_lower = query.to_lowercase();
        let mut exact = Vec::new();
        let mut partial = Vec::new();
        for sim in &all {
            let name = UniCase::new(sim.name.as_str());
            if name == needle {
                exact.push(sim.clone());
            } else if sim.name.to_lowercase().contains(&needle_lower) {
                partial.push(sim.clone());
            }
        }

        if exact.len() == 1 {
            return Ok(exact.into_iter().next().unwrap());
        }
        if exact.len() > 1 {
            return Err(SimctlError::AmbiguousMatch { query: query.to_string(), candidates: exact });
        }
        if partial.len() == 1 {
            return Ok(partial.into_iter().next().unwrap());
        }
        if partial.is_empty() {
            return Err(SimctlError::SimulatorNotFound { query: query.to_string() });
        }
        Err(SimctlError::AmbiguousMatch { query: query.to_string(), candidates: partial })
    }
}

#[cfg(test)]
mod tests {
    use async_trait::async_trait;
    use holodeck_core::models::{DeviceType, Platform, Runtime, SemanticVersion, SimulatorState};

    use super::*;

    struct StubClient {
        simulators: Vec<Simulator>,
    }

    fn sim(name: &str) -> Simulator {
        Simulator {
            id: Uuid::new_v4(),
            name: name.to_string(),
            runtime: Runtime::new(Platform::IOS, SemanticVersion::new(18, 0, 0), "iOS-18-0"),
            device_type: DeviceType::new("iPhone-17-Pro", "iPhone 17 Pro"),
            state: SimulatorState::Shutdown,
            is_available: true,
            data_path: None,
            log_path: None,
        }
    }

    #[async_trait]
    impl SimctlClient for StubClient {
        async fn list_devices(&self, _include_unavailable: bool) -> Result<Vec<Simulator>, SimctlError> {
            Ok(self.simulators.clone())
        }
        async fn boot(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn shutdown(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn screenshot(
            &self,
            _udid: Uuid,
            _path: &std::path::Path,
            _t: holodeck_core::models::ScreenshotType,
        ) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_appearance(&self, _udid: Uuid, _a: holodeck_core::models::Appearance) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_status_bar(&self, _udid: Uuid, _o: &holodeck_core::models::StatusBarOverrides) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn clear_status_bar(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_locale(&self, _udid: Uuid, _bcp47: &str) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn list_available_targets(&self) -> Result<AvailableTargets, SimctlError> {
            Ok(AvailableTargets { device_types: Vec::new(), runtimes: Vec::new() })
        }
        async fn list_apps(&self, _udid: Uuid) -> Result<Vec<InstalledApp>, SimctlError> {
            Ok(Vec::new())
        }
        async fn create(&self, _name: &str, _d: &str, _r: &str) -> Result<Uuid, SimctlError> {
            Ok(Uuid::new_v4())
        }
        async fn erase(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn delete(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn delete_unavailable(&self) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn set_location(&self, _udid: Uuid, _lat: f64, _lon: f64) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn clear_location(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn privacy(
            &self,
            _udid: Uuid,
            _a: holodeck_core::models::PrivacyAction,
            _p: holodeck_core::models::PrivacyPermission,
            _b: Option<&str>,
        ) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn reset_keychain(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn open_url(&self, _udid: Uuid, _url: &str) -> Result<(), SimctlError> {
            Ok(())
        }
        async fn focus_simulator_app(&self, _udid: Uuid) -> Result<(), SimctlError> {
            Ok(())
        }
    }

    fn service(simulators: Vec<Simulator>) -> SimulatorService {
        SimulatorService::new(Arc::new(StubClient { simulators }))
    }

    #[tokio::test]
    async fn resolves_by_exact_uuid() {
        let target = sim("iPhone 17 Pro");
        let service = service(vec![target.clone(), sim("iPhone 12")]);
        let resolved = service.resolve(&target.id.to_string()).await.unwrap();
        assert_eq!(resolved.id, target.id);
    }

    #[tokio::test]
    async fn resolves_by_exact_case_insensitive_name() {
        let service = service(vec![sim("iPhone 17 Pro")]);
        let resolved = service.resolve("iphone 17 pro").await.unwrap();
        assert_eq!(resolved.name, "iPhone 17 Pro");
    }

    #[tokio::test]
    async fn multiple_exact_matches_are_ambiguous() {
        let service = service(vec![sim("Alpha"), sim("Alpha")]);
        let err = service.resolve("alpha").await.unwrap_err();
        assert!(matches!(err, SimctlError::AmbiguousMatch { .. }));
    }

    #[tokio::test]
    async fn resolves_by_unique_substring() {
        let service = service(vec![sim("iPhone 17 Pro"), sim("iPad Pro")]);
        let resolved = service.resolve("17").await.unwrap();
        assert_eq!(resolved.name, "iPhone 17 Pro");
    }

    #[tokio::test]
    async fn ambiguous_substring_matches_error() {
        let service = service(vec![sim("iPhone 17 Pro"), sim("iPhone 17")]);
        let err = service.resolve("17").await.unwrap_err();
        assert!(matches!(err, SimctlError::AmbiguousMatch { .. }));
    }

    #[tokio::test]
    async fn no_match_errors_not_found() {
        let service = service(vec![sim("iPhone 17 Pro")]);
        let err = service.resolve("nonexistent").await.unwrap_err();
        assert!(matches!(err, SimctlError::SimulatorNotFound { .. }));
    }
}
