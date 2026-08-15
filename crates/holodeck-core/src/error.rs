use crate::models::{Simulator, SimulatorState};

#[derive(Debug, thiserror::Error)]
pub enum SimctlError {
    #[error("Xcode not found")]
    XcodeNotFound,

    #[error("not found: {query}")]
    SimulatorNotFound { query: String },

    #[error("ambiguous: {query}")]
    AmbiguousMatch { query: String, candidates: Vec<Simulator> },

    #[error("already {}", state.raw_value())]
    AlreadyInState { state: SimulatorState },

    #[error("{}", command_failed_description(stderr))]
    CommandFailed {
        command: String,
        exit_code: i32,
        stderr: String,
    },

    #[error("decode failed")]
    DecodingFailed {
        #[source]
        underlying: Box<dyn std::error::Error + Send + Sync>,
    },

    #[error("{reason}")]
    UnsupportedOperation { reason: String },

    #[error(transparent)]
    Io(#[from] std::io::Error),
}

fn command_failed_description(stderr: &str) -> String {
    let trimmed = stderr.trim();
    if trimmed.is_empty() {
        "command failed".to_string()
    } else {
        trimmed.to_string()
    }
}
