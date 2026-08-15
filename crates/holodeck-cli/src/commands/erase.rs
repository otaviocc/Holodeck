use std::sync::Arc;

use clap::Args;
use holodeck_core::LiveSimctlClient;
use holodeck_core::models::SimulatorState;
use holodeck_services::SimulatorService;

use crate::confirm_prompt::confirm;
use crate::resolve::resolve_in_state;

/// Erase a simulator's content. The simulator must be shut down.
#[derive(Args, Debug)]
pub struct EraseArgs {
    /// Simulator name or UDID. Omit when using --all.
    pub query: Option<String>,

    /// Erase all shut-down simulators.
    #[arg(long)]
    pub all: bool,

    /// Skip the confirmation prompt.
    #[arg(short, long)]
    pub yes: bool,
}

impl EraseArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = SimulatorService::new(Arc::new(LiveSimctlClient::new()));
        if self.all {
            let sims: Vec<_> = service
                .list(false)
                .await?
                .into_iter()
                .filter(|s| s.state == SimulatorState::Shutdown)
                .collect();
            if sims.is_empty() {
                println!("No shut-down simulators to erase.");
                return Ok(());
            }
            if !confirm(&format!("Erase {} shut-down simulator(s)?", sims.len()), self.yes) {
                println!("Aborted.");
                return Ok(());
            }
            let mut tasks = Vec::new();
            for sim in sims {
                let service = service.clone();
                tasks.push(tokio::spawn(async move { service.erase(sim.id).await.map(|_| sim.name) }));
            }
            for task in tasks {
                let name = task.await??;
                println!("Erased {name}.");
            }
            return Ok(());
        }

        let Some(query) = &self.query else {
            anyhow::bail!("Provide a simulator name/UDID or --all.");
        };
        let sim = resolve_in_state(&service, query, SimulatorState::Shutdown, "shut it down first").await?;
        if !confirm(&format!("Erase {}?", sim.name), self.yes) {
            println!("Aborted.");
            return Ok(());
        }
        service.erase(sim.id).await?;
        println!("Erased {}.", sim.name);
        Ok(())
    }
}
