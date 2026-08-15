use std::sync::Arc;

use clap::{Args, Subcommand};
use holodeck_core::models::SimulatorState;
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;

/// Set or clear the simulator's simulated GPS location.
#[derive(Args, Debug)]
pub struct LocationArgs {
    #[command(subcommand)]
    pub command: LocationSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum LocationSubcommand {
    /// Set the simulated GPS location.
    Set(SetArgs),
    /// Clear the simulated GPS location.
    Clear(ClearArgs),
}

#[derive(Args, Debug)]
pub struct SetArgs {
    /// Simulator name or UDID.
    pub query: String,
    /// Latitude (e.g. 37.7749).
    pub latitude: f64,
    /// Longitude (e.g. -122.4194).
    pub longitude: f64,
}

#[derive(Args, Debug)]
pub struct ClearArgs {
    /// Simulator name or UDID.
    pub query: String,
}

impl LocationArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        match &self.command {
            LocationSubcommand::Set(args) => args.run().await,
            LocationSubcommand::Clear(args) => args.run().await,
        }
    }
}

impl SetArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "the simulator must be booted").await?;
        client.set_location(sim.id, self.latitude, self.longitude).await?;
        println!("Set {} location to {},{}.", sim.name, self.latitude, self.longitude);
        Ok(())
    }
}

impl ClearArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "the simulator must be booted").await?;
        client.clear_location(sim.id).await?;
        println!("Cleared location on {}.", sim.name);
        Ok(())
    }
}
