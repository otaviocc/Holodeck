use std::sync::Arc;

use clap::Args;
use holodeck_core::LiveSimctlClient;
use holodeck_core::models::SimulatorState;
use holodeck_services::SimulatorService;

use crate::format::udid;

fn service() -> SimulatorService {
    SimulatorService::new(Arc::new(LiveSimctlClient::new()))
}

/// Boot a simulator by name or UDID.
#[derive(Args, Debug)]
pub struct BootArgs {
    /// Simulator name or UDID.
    pub query: String,
}

impl BootArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = service();
        let sim = service.resolve(&self.query).await?;
        if sim.state == SimulatorState::Booted {
            println!("{} is already booted.", sim.name);
            return Ok(());
        }
        service.boot(sim.id).await?;
        println!("Booted {} ({}).", sim.name, udid(sim.id));
        Ok(())
    }
}

/// Shut down a simulator by name or UDID.
#[derive(Args, Debug)]
pub struct ShutdownArgs {
    /// Simulator name or UDID.
    pub query: String,
}

impl ShutdownArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = service();
        let sim = service.resolve(&self.query).await?;
        if sim.state == SimulatorState::Shutdown {
            println!("{} is already shut down.", sim.name);
            return Ok(());
        }
        service.shutdown(sim.id).await?;
        println!("Shut down {} ({}).", sim.name, udid(sim.id));
        Ok(())
    }
}

/// Bring Simulator.app to the front, focused on the selected device.
#[derive(Args, Debug)]
pub struct FocusArgs {
    /// Simulator name or UDID.
    pub query: String,
}

impl FocusArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = service();
        let sim = service.resolve(&self.query).await?;
        service.focus(sim.id).await?;
        println!("Focused {} ({}).", sim.name, udid(sim.id));
        Ok(())
    }
}
