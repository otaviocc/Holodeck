use std::sync::Arc;

use clap::{Args, Subcommand};
use holodeck_core::models::SimulatorState;
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;

/// Manage the simulator's keychain.
#[derive(Args, Debug)]
pub struct KeychainArgs {
    #[command(subcommand)]
    pub command: KeychainSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum KeychainSubcommand {
    /// Reset the simulator's keychain.
    Reset(ResetArgs),
}

#[derive(Args, Debug)]
pub struct ResetArgs {
    /// Simulator name or UDID.
    pub query: String,
}

impl KeychainArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        match &self.command {
            KeychainSubcommand::Reset(args) => args.run().await,
        }
    }
}

impl ResetArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "the simulator must be booted").await?;
        client.reset_keychain(sim.id).await?;
        println!("Reset keychain on {}.", sim.name);
        Ok(())
    }
}
