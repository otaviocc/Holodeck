use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum SimulatorState {
    #[serde(rename = "Booted")]
    Booted,
    #[serde(rename = "Shutdown")]
    Shutdown,
    #[serde(rename = "Booting")]
    Booting,
    #[serde(rename = "Shutting Down")]
    ShuttingDown,
    #[serde(rename = "Creating")]
    Creating,
}

impl SimulatorState {
    pub fn raw_value(self) -> &'static str {
        match self {
            SimulatorState::Booted => "Booted",
            SimulatorState::Shutdown => "Shutdown",
            SimulatorState::Booting => "Booting",
            SimulatorState::ShuttingDown => "Shutting Down",
            SimulatorState::Creating => "Creating",
        }
    }

    pub fn from_raw_value(raw: &str) -> Option<Self> {
        match raw {
            "Booted" => Some(SimulatorState::Booted),
            "Shutdown" => Some(SimulatorState::Shutdown),
            "Booting" => Some(SimulatorState::Booting),
            "Shutting Down" => Some(SimulatorState::ShuttingDown),
            "Creating" => Some(SimulatorState::Creating),
            _ => None,
        }
    }
}
