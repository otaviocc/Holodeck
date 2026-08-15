use holodeck_core::models::{Simulator, SimulatorState};
use holodeck_services::SimulatorService;

/// Resolves `query` then asserts it's in `required_state`, mirroring the
/// Swift `SimulatorService.resolveInState(_:_:purpose:)` helper shared by
/// most subcommands.
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
