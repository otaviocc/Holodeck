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

    /// ISO 3166-1 region code applied to this launch only, e.g. BR.
    /// Independent of --language — combine both to test a language/region
    /// pairing (e.g. English UI with a Brazil region). Without --language,
    /// the simulator's current language is kept and only the region changes.
    #[arg(long)]
    pub region: Option<String>,
}

impl LaunchArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim =
            resolve_in_state(&service, &self.query, SimulatorState::Booted, "apps can only be launched on booted simulators")
                .await?;
        let language = self.language.as_deref().filter(|tag| !tag.is_empty());
        let region = self.region.as_deref().filter(|code| !code.is_empty());
        client.launch_app(sim.id, &self.bundle_id, language, region).await?;
        match (language, region) {
            (Some(language), Some(region)) => {
                println!("Launched {} on {} in {} ({}).", self.bundle_id, sim.name, language, region)
            }
            (Some(language), None) => println!("Launched {} on {} in {}.", self.bundle_id, sim.name, language),
            (None, Some(region)) => println!("Launched {} on {} in region {}.", self.bundle_id, sim.name, region),
            (None, None) => println!("Launched {} on {}.", self.bundle_id, sim.name),
        }
        Ok(())
    }
}
