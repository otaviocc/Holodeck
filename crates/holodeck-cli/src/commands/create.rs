use std::sync::Arc;

use clap::Args;
use holodeck_core::LiveSimctlClient;
use holodeck_core::models::{DeviceType, Runtime};
use holodeck_services::SimulatorService;

use crate::format::udid;

/// Create a new simulator by device type and runtime.
#[derive(Args, Debug)]
pub struct CreateArgs {
    /// Name for the new simulator.
    pub name: String,

    /// Device type (substring matched against the device type name, e.g.
    /// "iPhone 16 Pro").
    #[arg(long)]
    pub device: String,

    /// Runtime (substring matched against the runtime display name, e.g.
    /// "iOS 18.2").
    #[arg(long)]
    pub runtime: String,
}

/// Exact (case-insensitive) matches win outright; otherwise falls back to
/// substring matches. Mirrors the Swift `CreateCommand.bestMatches`.
fn best_matches<'a, T>(items: &'a [T], query: &str, label: impl Fn(&T) -> String) -> Vec<&'a T> {
    let needle = query.to_lowercase();
    let mut exact = Vec::new();
    let mut partial = Vec::new();
    for item in items {
        let name = label(item).to_lowercase();
        if name == needle {
            exact.push(item);
        } else if name.contains(&needle) {
            partial.push(item);
        }
    }
    if exact.is_empty() { partial } else { exact }
}

fn unique_or_throw<'a, T>(matches: Vec<&'a T>, label: &str, query: &str) -> anyhow::Result<&'a T> {
    if matches.is_empty() {
        anyhow::bail!("No {label} matches '{query}'.");
    }
    if matches.len() > 1 {
        anyhow::bail!("Multiple {label}s match '{query}'. Be more specific.");
    }
    Ok(matches[0])
}

impl CreateArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = SimulatorService::new(Arc::new(LiveSimctlClient::new()));
        let targets = service.available_targets().await?;

        let device_matches = best_matches(&targets.device_types, &self.device, |d: &DeviceType| d.name.clone());
        let device_type = unique_or_throw(device_matches, "device type", &self.device)?;

        let runtime_matches = best_matches(&targets.runtimes, &self.runtime, |r: &Runtime| r.display_name());
        let runtime = unique_or_throw(runtime_matches, "runtime", &self.runtime)?;

        let id = service.create(&self.name, device_type, runtime).await?;
        println!("Created {} ({}) — {} / {}", self.name, udid(id), device_type.name, runtime.display_name());
        Ok(())
    }
}
