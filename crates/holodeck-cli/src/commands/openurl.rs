use std::sync::Arc;

use clap::Args;
use holodeck_core::LiveSimctlClient;
use holodeck_core::models::SimulatorState;
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;

/// Open a URL or deep link on a booted simulator.
#[derive(Args, Debug)]
pub struct OpenUrlArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// URL to open (e.g. https://apple.com or myapp://deep/link).
    pub url: String,
}

impl OpenUrlArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        if self.url.is_empty() {
            anyhow::bail!("URL must not be empty.");
        }
        let service = SimulatorService::new(Arc::new(LiveSimctlClient::new()));
        let sim = resolve_in_state(
            &service,
            &self.query,
            SimulatorState::Booted,
            "URLs only open on booted simulators",
        )
        .await?;
        service.open_url(sim.id, &self.url).await?;
        println!("Opened {} on {}.", self.url, sim.name);
        Ok(())
    }
}
