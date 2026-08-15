use std::sync::Arc;

use clap::Args;
use holodeck_core::models::{Appearance, SimulatorState};
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;
use crate::value_parsers::parse_appearance;

/// Set light or dark appearance on a booted simulator.
#[derive(Args, Debug)]
pub struct AppearanceArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Appearance: light or dark.
    #[arg(value_parser = parse_appearance)]
    pub appearance: Appearance,
}

impl AppearanceArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim =
            resolve_in_state(&service, &self.query, SimulatorState::Booted, "appearance can only be set on booted simulators")
                .await?;
        client.set_appearance(sim.id, self.appearance).await?;
        println!("Set {} appearance to {}.", sim.name, self.appearance.raw_value());
        Ok(())
    }
}
