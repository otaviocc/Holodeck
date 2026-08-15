use clap::Args;
use holodeck_core::models::{Platform, Simulator};
use holodeck_services::AppDependencies;
use serde::Serialize;

use crate::format::udid;
use crate::value_parsers::parse_platform;

/// List available simulators.
#[derive(Args, Debug)]
pub struct ListArgs {
    /// Filter by platform: ios, watchos, tvos, visionos. Defaults to value
    /// from ~/.config/holodeck/config.json.
    #[arg(long, value_parser = parse_platform)]
    pub platform: Option<Platform>,

    /// Emit JSON instead of a table.
    #[arg(long)]
    pub json: bool,
}

#[derive(Serialize)]
struct Out {
    #[serde(rename = "deviceType")]
    device_type: String,
    #[serde(rename = "isAvailable")]
    is_available: bool,
    name: String,
    runtime: String,
    state: String,
    udid: String,
}

impl ListArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let dependencies = AppDependencies::live();
        let mut simulators = dependencies.simulator_service.list(false).await?;
        let effective_platform = self.platform.or(dependencies.configuration.default_platform);
        if let Some(filter) = effective_platform {
            simulators.retain(|sim| sim.runtime.platform == filter);
        }
        if self.json {
            print_json(&simulators)?;
        } else {
            print_table(&simulators);
        }
        Ok(())
    }
}

fn print_json(simulators: &[Simulator]) -> anyhow::Result<()> {
    let out: Vec<Out> = simulators
        .iter()
        .map(|sim| Out {
            device_type: sim.device_type.name.clone(),
            is_available: sim.is_available,
            name: sim.name.clone(),
            runtime: sim.runtime.display_name(),
            state: sim.state.raw_value().to_string(),
            udid: udid(sim.id),
        })
        .collect();
    println!("{}", serde_json::to_string_pretty(&out)?);
    Ok(())
}

fn print_table(simulators: &[Simulator]) {
    let mut sorted: Vec<&Simulator> = simulators.iter().collect();
    sorted.sort_by(|lhs, rhs| rhs.runtime.cmp(&lhs.runtime).then_with(|| lhs.name.cmp(&rhs.name)));

    let headers = ("RUNTIME", "NAME", "STATE", "UDID");
    let runtime_w = sorted.iter().map(|s| s.runtime.display_name().len()).max().unwrap_or(0).max(headers.0.len());
    let name_w = sorted.iter().map(|s| s.name.len()).max().unwrap_or(0).max(headers.1.len());
    let state_w = sorted.iter().map(|s| s.state.raw_value().len()).max().unwrap_or(0).max(headers.2.len());

    let row = |runtime: &str, name: &str, state: &str, udid: &str| {
        format!("{runtime:runtime_w$}  {name:name_w$}  {state:state_w$}  {udid}")
    };

    println!("{}", row(headers.0, headers.1, headers.2, headers.3));
    for sim in sorted {
        println!("{}", row(&sim.runtime.display_name(), &sim.name, sim.state.raw_value(), &udid(sim.id)));
    }
}
