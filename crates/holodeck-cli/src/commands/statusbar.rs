use std::sync::Arc;

use clap::{Args, Subcommand};
use holodeck_core::models::{BatteryState, SimulatorState, StatusBarOverrides};
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;
use crate::value_parsers::parse_battery_state;

/// Override or clear the simulator status bar. Overrides only persist while
/// the simulator runs.
#[derive(Args, Debug)]
pub struct StatusBarArgs {
    #[command(subcommand)]
    pub command: StatusBarSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum StatusBarSubcommand {
    /// Set one or more status bar fields on a booted simulator.
    Override(OverrideArgs),
    /// Clear status bar overrides.
    Clear(ClearArgs),
}

#[derive(Args, Debug)]
pub struct OverrideArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Time string, e.g. 9:41.
    #[arg(long)]
    pub time: Option<String>,

    /// Battery state: charging, charged, discharging.
    #[arg(long, value_parser = parse_battery_state)]
    pub battery_state: Option<BatteryState>,

    /// Battery level (0-100).
    #[arg(long)]
    pub battery_level: Option<i64>,

    /// Wi-Fi bars (0-3).
    #[arg(long)]
    pub wifi_bars: Option<i64>,

    /// Cellular bars (0-4).
    #[arg(long)]
    pub cellular_bars: Option<i64>,

    /// Operator name.
    #[arg(long)]
    pub operator_name: Option<String>,
}

#[derive(Args, Debug)]
pub struct ClearArgs {
    /// Simulator name or UDID.
    pub query: String,
}

impl StatusBarArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        match &self.command {
            StatusBarSubcommand::Override(args) => args.run().await,
            StatusBarSubcommand::Clear(args) => args.run().await,
        }
    }
}

impl OverrideArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let overrides = StatusBarOverrides {
            time: self.time.clone(),
            battery_state: self.battery_state,
            battery_level: self.battery_level,
            wifi_bars: self.wifi_bars,
            cellular_bars: self.cellular_bars,
            operator_name: self.operator_name.clone(),
        };
        if overrides.is_empty() {
            anyhow::bail!("Provide at least one --option to override.");
        }
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "the simulator must be booted").await?;
        client.set_status_bar(sim.id, &overrides).await?;
        println!("Applied status bar overrides to {}.", sim.name);
        Ok(())
    }
}

impl ClearArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "the simulator must be booted").await?;
        client.clear_status_bar(sim.id).await?;
        println!("Cleared status bar overrides on {}.", sim.name);
        Ok(())
    }
}
