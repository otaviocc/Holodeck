use holodeck_core::models::{Simulator, SimulatorState};
use holodeck_services::SimulatorService;

/// Resolves `query` to a simulator and errors unless it is in
/// `required_state`.
pub async fn resolve_in_state(
    service: &SimulatorService,
    query: &str,
    required_state: SimulatorState,
    purpose: &str,
) -> anyhow::Result<Simulator> {
    let sim = service.resolve(query).await?;
    if sim.state != required_state {
        anyhow::bail!("{} is {}; {}.", sim.name, sim.state.raw_value(), purpose);
    }
    Ok(sim)
}
