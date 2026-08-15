use std::path::PathBuf;

use clap::Args;
use holodeck_core::default_media_path;
use holodeck_core::models::{SimulatorState, VideoCodec};
use holodeck_services::AppDependencies;

use crate::resolve::resolve_in_state;
use crate::value_parsers::parse_video_codec;

/// Record video from a booted simulator. Press Ctrl-C to stop cleanly.
#[derive(Args, Debug)]
pub struct RecordArgs {
    /// Simulator name or UDID.
    pub query: String,

    /// Output file path (default: ~/Desktop/sim_record_<ts>.mp4).
    #[arg(short, long)]
    pub output: Option<String>,

    /// Video codec: h264 or hevc. Defaults to value from
    /// ~/.config/holodeck/config.json.
    #[arg(long, value_parser = parse_video_codec)]
    pub codec: Option<VideoCodec>,
}

impl RecordArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        let dependencies = AppDependencies::live();
        let codec = self.codec.unwrap_or(dependencies.configuration.video_codec);
        let sim = resolve_in_state(
            &dependencies.simulator_service,
            &self.query,
            SimulatorState::Booted,
            "only booted simulators can be recorded",
        )
        .await?;

        let out_path = match &self.output {
            Some(path) => PathBuf::from(shellexpand::tilde(path).into_owned()),
            None => default_media_path::record(
                &dependencies.configuration.resolved_screenshots_directory(),
                chrono::Local::now(),
            ),
        };

        dependencies.recording_service.start(sim.id, &out_path, codec).await?;
        eprintln!("Recording to {} — press Ctrl-C to stop.", out_path.display());

        tokio::signal::ctrl_c().await?;

        eprintln!("\nFinalizing…");
        let _ = dependencies.recording_service.stop().await;
        println!("{}", out_path.display());
        Ok(())
    }
}
