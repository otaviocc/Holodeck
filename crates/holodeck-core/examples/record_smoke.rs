//! Manual smoke test that a SIGINT-stopped recording produces a *playable*
//! MP4 (plan §6.2 / §8) — not part of `cargo test` since it needs a booted
//! simulator and takes several real seconds.
//! Run with: cargo run -p holodeck-core --example record_smoke -- <udid>

use std::path::PathBuf;

use holodeck_simctl_core::models::VideoCodec;
use holodeck_simctl_core::{Recorder, simctl_client::record_video_command};
use uuid::Uuid;

#[tokio::main]
async fn main() {
    let udid: Uuid = std::env::args().nth(1).expect("pass a booted udid as argv[1]").parse().expect("not a uuid");
    let output = PathBuf::from("/tmp/holodeck-rs-smoke.mp4");
    let _ = std::fs::remove_file(&output);

    let (launch_path, args) = record_video_command(udid, &output, VideoCodec::H264);
    let recorder = Recorder::new();
    recorder.start(launch_path, &args).await.expect("start failed");
    println!("recording for 3s...");
    tokio::time::sleep(std::time::Duration::from_secs(3)).await;
    assert!(recorder.is_running().await, "recorder should still be running before stop");
    recorder.stop().await;
    assert!(!recorder.is_running().await, "recorder should have stopped");

    let metadata = std::fs::metadata(&output).expect("output file missing");
    println!("wrote {} bytes to {}", metadata.len(), output.display());
    assert!(metadata.len() > 0, "output file is empty");
    println!("OK — inspect playability manually with: open {}", output.display());
}
