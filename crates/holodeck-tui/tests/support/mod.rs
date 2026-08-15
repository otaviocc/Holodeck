#![allow(dead_code)]

use holodeck_core::models::{DeviceType, Platform, Runtime, SemanticVersion, Simulator, SimulatorState};
use holodeck_tui::state::AppState;
use uuid::Uuid;

pub fn sim(name: &str, state: SimulatorState) -> Simulator {
    Simulator {
        id: Uuid::new_v4(),
        name: name.to_string(),
        runtime: Runtime::new(Platform::IOS, SemanticVersion::new(18, 0, 0), "iOS-18-0"),
        device_type: DeviceType::new("iPhone-17-Pro", "iPhone 17 Pro"),
        state,
        is_available: true,
        data_path: None,
        log_path: None,
    }
}

pub fn booted(name: &str) -> Simulator {
    sim(name, SimulatorState::Booted)
}

pub fn shutdown(name: &str) -> Simulator {
    sim(name, SimulatorState::Shutdown)
}

/// A default state with `sims` loaded and the first one selected, mirroring
/// the Swift test suites' typical fixture.
pub fn state_with(sims: Vec<Simulator>) -> AppState {
    AppState { simulators: sims, rows: 24, cols: 80, ..AppState::default() }
}
