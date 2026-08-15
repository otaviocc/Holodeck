use std::path::{Path, PathBuf};

use holodeck_core::models::VideoCodec;
use holodeck_core::{Recorder, SimctlError, default_media_path, simctl_client::record_video_command};
use tokio::sync::Mutex;
use uuid::Uuid;

/// Orchestrates a single in-flight recording: ensures the output directory
/// exists, starts the `Recorder`, and remembers the output path so `stop()`
/// can hand it back exactly once (mirrors the Swift `RecordingService`'s
/// take-once `RecordingState` actor).
pub struct RecordingService {
    recorder: Recorder,
    current_output: Mutex<Option<PathBuf>>,
}

impl Default for RecordingService {
    fn default() -> Self {
        Self::new()
    }
}

impl RecordingService {
    pub fn new() -> Self {
        Self { recorder: Recorder::new(), current_output: Mutex::new(None) }
    }

    pub async fn is_recording(&self) -> bool {
        self.recorder.is_running().await
    }

    pub async fn start(&self, udid: Uuid, output: &Path, codec: VideoCodec) -> Result<(), SimctlError> {
        if self.is_recording().await {
            return Err(SimctlError::UnsupportedOperation { reason: "already recording".to_string() });
        }
        default_media_path::ensure_directory_exists(output)?;
        let (launch_path, args) = record_video_command(udid, output, codec);
        self.recorder.start(launch_path, &args).await?;
        *self.current_output.lock().await = Some(output.to_path_buf());
        Ok(())
    }

    /// Stops the recording and hands back the output path exactly once —
    /// a second call (or one with nothing in flight) returns `None`.
    pub async fn stop(&self) -> Option<PathBuf> {
        self.recorder.stop().await;
        self.current_output.lock().await.take()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn not_recording_initially() {
        let service = RecordingService::new();
        assert!(!service.is_recording().await);
    }

    #[tokio::test]
    async fn stop_without_start_returns_none() {
        let service = RecordingService::new();
        assert_eq!(service.stop().await, None);
    }

    #[tokio::test]
    async fn starting_twice_errors_already_recording() {
        let dir = tempfile::tempdir().unwrap();
        let service = RecordingService::new();
        let output = dir.path().join("out.mp4");
        // Use `sleep` as a stand-in long-running process instead of real
        // simctl, so this test doesn't depend on a booted simulator.
        service.recorder.start("/bin/sleep", &["5".to_string()]).await.unwrap();
        let err = service.start(Uuid::new_v4(), &output, VideoCodec::H264).await.unwrap_err();
        assert!(matches!(err, SimctlError::UnsupportedOperation { .. }));
        service.stop().await;
    }

    #[tokio::test]
    async fn stop_takes_output_path_exactly_once() {
        let dir = tempfile::tempdir().unwrap();
        let output = dir.path().join("out.mp4");
        let service = RecordingService::new();
        service.recorder.start("/bin/sleep", &["5".to_string()]).await.unwrap();
        *service.current_output.lock().await = Some(output.clone());
        assert_eq!(service.stop().await, Some(output));
        assert_eq!(service.stop().await, None);
    }
}
