use std::sync::Arc;

use clap::Args;
use holodeck_core::models::{PrivacyAction, PrivacyPermission, SimulatorState};
use holodeck_core::{LiveSimctlClient, SimctlClient};
use holodeck_services::SimulatorService;

use crate::resolve::resolve_in_state;
use crate::value_parsers::{parse_privacy_action, parse_privacy_permission};

/// Grant, revoke, or reset a privacy permission for a bundle ID.
#[derive(Args, Debug)]
pub struct PrivacyArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Action: grant, revoke, reset.
    #[arg(value_parser = parse_privacy_action)]
    pub action: PrivacyAction,

    /// Permission: all, calendar, contacts, contacts-limited, location,
    /// location-always, photos, photos-add, media-library, microphone,
    /// motion, reminders, siri.
    #[arg(value_parser = parse_privacy_permission)]
    pub permission: PrivacyPermission,

    /// Bundle identifier (required for grant/revoke; optional for reset).
    pub bundle_id: Option<String>,
}

impl PrivacyArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        if self.action != PrivacyAction::Reset && self.bundle_id.is_none() {
            anyhow::bail!("{} requires a bundle identifier.", self.action.raw_value());
        }
        let client: Arc<dyn SimctlClient> = Arc::new(LiveSimctlClient::new());
        let service = SimulatorService::new(client.clone());
        let sim = resolve_in_state(&service, &self.query, SimulatorState::Booted, "the simulator must be booted").await?;
        client
            .privacy(sim.id, self.action, self.permission, self.bundle_id.as_deref())
            .await?;
        let target = self.bundle_id.as_ref().map(|b| format!(" for {b}")).unwrap_or_default();
        let action_capitalized = capitalize(self.action.raw_value());
        println!(
            "{} {}{} on {}.",
            action_capitalized,
            self.permission.raw_value(),
            target,
            sim.name
        );
        Ok(())
    }
}

fn capitalize(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
        None => String::new(),
    }
}
