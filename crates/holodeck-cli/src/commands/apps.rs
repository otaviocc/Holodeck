use std::sync::Arc;

use clap::{Args, Subcommand};
use holodeck_core::LiveSimctlClient;
use holodeck_core::models::{InstalledApp, SimulatorState};
use holodeck_services::SimulatorService;
use serde::Serialize;

use crate::resolve::resolve_in_state;

/// Inspect apps installed on a simulator.
#[derive(Args, Debug)]
pub struct AppsArgs {
    #[command(subcommand)]
    pub command: AppsSubcommand,
}

#[derive(Subcommand, Debug)]
pub enum AppsSubcommand {
    /// List apps installed on a booted simulator.
    List(ListArgs),
}

#[derive(Args, Debug)]
pub struct ListArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Include system apps (default: user apps only).
    #[arg(long)]
    pub system: bool,

    /// Emit JSON instead of a table.
    #[arg(long)]
    pub json: bool,
}

#[derive(Serialize)]
struct Out {
    #[serde(rename = "bundleID")]
    bundle_id: String,
    #[serde(rename = "isUserApp")]
    is_user_app: bool,
    name: String,
    version: Option<String>,
}

impl AppsArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        match &self.command {
            AppsSubcommand::List(args) => args.run().await,
        }
    }
}

impl ListArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let service = SimulatorService::new(Arc::new(LiveSimctlClient::new()));
        let sim =
            resolve_in_state(&service, &self.query, SimulatorState::Booted, "listapps only works on booted simulators").await?;
        let mut apps = service.list_apps(sim.id).await?;
        if !self.system {
            apps.retain(|app| app.is_user_app);
        }
        if self.json {
            print_json(&apps)?;
        } else {
            print_table(&apps);
        }
        Ok(())
    }
}

fn print_json(apps: &[InstalledApp]) -> anyhow::Result<()> {
    let out: Vec<Out> = apps
        .iter()
        .map(|app| Out {
            bundle_id: app.bundle_id.clone(),
            is_user_app: app.is_user_app,
            name: app.name.clone(),
            version: app.version.clone(),
        })
        .collect();
    println!("{}", serde_json::to_string_pretty(&out)?);
    Ok(())
}

fn print_table(apps: &[InstalledApp]) {
    let headers = ("NAME", "BUNDLE ID", "VERSION", "TYPE");
    let name_w = apps.iter().map(|a| a.name.len()).max().unwrap_or(0).max(headers.0.len());
    let bundle_w = apps.iter().map(|a| a.bundle_id.len()).max().unwrap_or(0).max(headers.1.len());
    let version_w = apps.iter().filter_map(|a| a.version.as_ref()).map(|v| v.len()).max().unwrap_or(0).max(headers.2.len());

    let row = |name: &str, bundle: &str, version: &str, kind: &str| {
        format!("{name:name_w$}  {bundle:bundle_w$}  {version:version_w$}  {kind}")
    };

    println!("{}", row(headers.0, headers.1, headers.2, headers.3));
    for app in apps {
        println!(
            "{}",
            row(
                &app.name,
                &app.bundle_id,
                app.version.as_deref().unwrap_or("\u{2014}"),
                if app.is_user_app { "user" } else { "system" }
            )
        );
    }
}
