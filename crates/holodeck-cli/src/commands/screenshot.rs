use std::path::PathBuf;

use clap::Args;
use holodeck_core::default_media_path;
use holodeck_core::models::{ScreenshotType, SimulatorState};
use holodeck_services::AppDependencies;

use crate::resolve::resolve_in_state;
use crate::value_parsers::parse_screenshot_type;

/// Capture a screenshot from a booted simulator.
#[derive(Args, Debug)]
pub struct ScreenshotArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Output file path (default: ~/Desktop/sim_screenshot_<ts>.<ext>).
    #[arg(short, long)]
    pub output: Option<String>,

    /// Image type: png, jpeg, tiff, bmp. Defaults to value from
    /// ~/.config/holodeck/config.json.
    #[arg(long, value_parser = parse_screenshot_type)]
    pub r#type: Option<ScreenshotType>,
}

impl ScreenshotArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let dependencies = AppDependencies::live();
        let image_type = self.r#type.unwrap_or(dependencies.configuration.screenshot_type);
        let sim = resolve_in_state(
            &dependencies.simulator_service,
            &self.query,
            SimulatorState::Booted,
            "only booted simulators can be captured",
        )
        .await?;

        let out_path = match &self.output {
            Some(path) => PathBuf::from(shellexpand::tilde(path).into_owned()),
            None => default_media_path::screenshot(
                &dependencies.configuration.resolved_screenshots_directory(),
                image_type,
                chrono::Local::now(),
            ),
        };

        dependencies.screenshot_service.capture(sim.id, &out_path, image_type).await?;
        println!("{}", out_path.display());
        Ok(())
    }
}
