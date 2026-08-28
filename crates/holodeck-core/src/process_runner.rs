use async_trait::async_trait;

#[derive(Debug, Clone)]
pub struct ProcessResult {
    pub stdout: Vec<u8>,
    pub stderr: Vec<u8>,
    pub exit_code: i32,
}

/// Injectable process execution seam. Implementations run a launch path with
/// an argument list and return its captured output.
#[async_trait]
pub trait ProcessRunning: Send + Sync {
    async fn run(&self, launch_path: &str, arguments: &[String]) -> std::io::Result<ProcessResult>;
}

/// Runs processes with `tokio::process::Command::output()`, which drains
/// stdout and stderr concurrently.
#[derive(Debug, Default, Clone, Copy)]
pub struct TokioProcessRunner;

#[async_trait]
impl ProcessRunning for TokioProcessRunner {
    async fn run(&self, launch_path: &str, arguments: &[String]) -> std::io::Result<ProcessResult> {
        let output = tokio::process::Command::new(launch_path).args(arguments).output().await?;
        Ok(ProcessResult { stdout: output.stdout, stderr: output.stderr, exit_code: output.status.code().unwrap_or(-1) })
    }
}
