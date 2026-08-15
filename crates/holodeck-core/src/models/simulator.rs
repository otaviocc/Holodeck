use std::path::PathBuf;

use uuid::Uuid;

use super::device_type::DeviceType;
use super::runtime::Runtime;
use super::simulator_state::SimulatorState;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Simulator {
    pub id: Uuid,
    pub name: String,
    pub runtime: Runtime,
    pub device_type: DeviceType,
    pub state: SimulatorState,
    pub is_available: bool,
    pub data_path: Option<PathBuf>,
    pub log_path: Option<PathBuf>,
}
