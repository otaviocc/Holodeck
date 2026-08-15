use tokio::process::Child;
use tokio::sync::Mutex;

/// Owns the long-running child process. Sending SIGINT — not SIGKILL — is
/// required for `simctl io recordVideo` to finalize a valid MP4; Rust's
/// `Child::kill()` only sends SIGKILL, so this shells out to `libc::kill`
/// directly (see plan §6.2 / §3a).
#[derive(Default)]
pub struct Recorder {
    child: Mutex<Option<Child>>,
}

impl Recorder {
    pub fn new() -> Self {
        Self { child: Mutex::new(None) }
    }

    pub async fn is_running(&self) -> bool {
        let mut guard = self.child.lock().await;
        match guard.as_mut() {
            Some(child) => matches!(child.try_wait(), Ok(None)),
            None => false,
        }
    }

    /// Idempotent: a second `start()` while already recording is a no-op,
    /// matching the Swift `RecorderActor.start`.
    pub async fn start(&self, launch_path: &str, arguments: &[String]) -> std::io::Result<()> {
        let mut guard = self.child.lock().await;
        if let Some(child) = guard.as_mut()
            && matches!(child.try_wait(), Ok(None))
        {
            return Ok(());
        }
        let child = tokio::process::Command::new(launch_path)
            .args(arguments)
            .stdout(std::process::Stdio::null())
            .stderr(std::process::Stdio::null())
            .spawn()?;
        *guard = Some(child);
        Ok(())
    }

    pub async fn stop(&self) {
        let mut guard = self.child.lock().await;
        let Some(mut child) = guard.take() else {
            return;
        };
        if let Some(pid) = child.id() {
            // SAFETY: `pid` is the child we just spawned and still hold; SIGINT
            // is what lets `simctl io recordVideo` finalize a valid MP4.
            unsafe {
                libc::kill(pid as libc::pid_t, libc::SIGINT);
            }
        }
        let _ = child.wait().await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn not_running_before_start() {
        let recorder = Recorder::new();
        assert!(!recorder.is_running().await);
    }

    #[tokio::test]
    async fn tracks_running_state_across_start_and_stop() {
        let recorder = Recorder::new();
        recorder.start("/bin/sleep", &["5".to_string()]).await.unwrap();
        assert!(recorder.is_running().await);
        recorder.stop().await;
        assert!(!recorder.is_running().await);
    }

    #[tokio::test]
    async fn start_is_idempotent_while_already_running() {
        let recorder = Recorder::new();
        recorder.start("/bin/sleep", &["5".to_string()]).await.unwrap();
        recorder.start("/bin/sleep", &["5".to_string()]).await.unwrap();
        recorder.stop().await;
    }
}
