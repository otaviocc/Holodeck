use std::sync::Arc;

use clap::Args;
use holodeck_core::LiveSimctlClient;
use holodeck_services::SimulatorService;

use crate::confirm_prompt::confirm;
use crate::format::udid;

/// Delete a simulator, or all simulators whose runtime is no longer
/// available.
#[derive(Args, Debug)]
pub struct DeleteArgs {
    /// Simulator name or UDID. Omit when using --unavailable.
    pub query: Option<String>,

    /// Delete all simulators whose runtime is unavailable.
    #[arg(long)]
    pub unavailable: bool,

    /// Skip the confirmation prompt.
    #[arg(short, long)]
    pub yes: bool,
}

impl DeleteArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = SimulatorService::new(Arc::new(LiveSimctlClient::new()));
        if self.unavailable {
            if !confirm("Delete all simulators with unavailable runtimes?", self.yes) {
                println!("Aborted.");
                return Ok(());
            }
            service.delete_unavailable().await?;
            println!("Deleted unavailable simulators.");
            return Ok(());
        }

        let Some(query) = &self.query else {
            anyhow::bail!("Provide a simulator name/UDID or --unavailable.");
        };
        let sim = service.resolve(query).await?;
        if !confirm(&format!("Delete {} ({})?", sim.name, udid(sim.id)), self.yes) {
            println!("Aborted.");
            return Ok(());
        }
        service.delete(sim.id).await?;
        println!("Deleted {}.", sim.name);
        Ok(())
    }
}
