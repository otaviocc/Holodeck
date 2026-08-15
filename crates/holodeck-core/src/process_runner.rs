use async_trait::async_trait;

#[derive(Debug, Clone)]
pub struct ProcessResult {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub exit_code: i32,
}

/// Injectable process execution seam — the Rust analogue of Swift's
/// `ProcessRunning` protocol witness, kept so `SimctlClient` tests can pin
/// exact argv without spawning real processes.
#[async_trait]
pub trait ProcessRunning: Send + Sync {
    async fn run(&self, launch_path: &str, arguments: &[String]) -> std::io::Result<ProcessResult>;
}

/// `tokio::process::Command::output()` drains stdout and stderr concurrently
/// by construction, so the pipe-drain deadlock the Swift `ProcessRunner` had
/// to guard against (see CLAUDE.md) cannot happen here.
#[derive(Debug, Default, Clone, Copy)]
pub struct TokioProcessRunner;

#[async_trait]
impl ProcessRunning for TokioProcessRunner {
    async fn run(&self, launch_path: &str, arguments: &[String]) -> std::io::Result<ProcessResult> {
        let output = tokio::process::Command::new(launch_path).args(arguments).output().await?;
        Ok(ProcessResult { stdout: output.stdout, stderr: output.stderr, exit_code: output.status.code().unwrap_or(-1) })
    }
}
