use std::sync::Arc;

use clap::Args;
use holodeck_core::models::SimulatorState;
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;

/// Set the simulator locale and language (BCP-47 tag). Requires reboot to
/// take effect.
#[derive(Args, Debug)]
pub struct LocaleArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// BCP-47 tag, e.g. en, en-US, pt-BR.
    pub tag: String,
}

impl LocaleArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "locale can only be set on booted simulators")
            .await?;
        client.set_locale(sim.id, &self.tag).await?;
        println!("Set {} locale to {}. Reboot the simulator for changes to take effect.", sim.name, self.tag);
        Ok(())
    }
}
