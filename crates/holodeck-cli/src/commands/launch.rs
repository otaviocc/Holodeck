use std::sync::Arc;

use clap::Args;
use holodeck_core::models::SimulatorState;
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;

/// Launch an installed app on a booted simulator.
#[derive(Args, Debug)]
pub struct LaunchArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Bundle identifier of the app to launch.
    pub bundle_id: String,

    /// BCP-47 tag to force for this launch only, e.g. pt-BR. Does not persist
    /// past this launch.
    #[arg(long)]
    pub language: Option<String>,
}

impl LaunchArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim =
            resolve_in_state(&service, &self.query, SimulatorState::Booted, "apps can only be launched on booted simulators")
                .await?;
        let language = self.language.as_deref().filter(|tag| !tag.is_empty());
        client.launch_app(sim.id, &self.bundle_id, language).await?;
        match language {
            Some(tag) => println!("Launched {} on {} in {}.", self.bundle_id, sim.name, tag),
            None => println!("Launched {} on {}.", self.bundle_id, sim.name),
        }
        Ok(())
    }
}
