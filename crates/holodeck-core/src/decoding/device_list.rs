use std::collections::HashMap;
use std::path::PathBuf;

use serde::Deserialize;
use uuid::Uuid;

use crate::models::{AvailableTargets, DeviceType, Runtime, Simulator, SimulatorState};

#[derive(Debug, Deserialize)]
struct RawList {
    devices: HashMap<String, Vec<RawDevice>>,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawDevice {
    udid: String,
    name: String,
    state: String,
    is_available: bool,
    device_type_identifier: Option<String>,
    data_path: Option<String>,
    log_path: Option<String>,
}

#[derive(Debug, Deserialize)]
struct RawTargets {
    devicetypes: Option<Vec<RawDeviceType>>,
    runtimes: Option<Vec<RawRuntime>>,
}

#[derive(Debug, Deserialize)]
struct RawDeviceType {
    identifier: String,
    name: String,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawRuntime {
    identifier: String,
    #[allow(dead_code)]
    name: String,
    version: Option<String>,
    is_available: Option<bool>,
}

/// Omits Apple TV simulators from the picker and from CLI substring
/// matches; the create flow pairs only with iOS/watchOS/visionOS runtimes.
const APPLE_TV_MARKER: &str = ".Apple-TV-";

pub fn decode_available_targets(data: &[u8]) -> Result<AvailableTargets, serde_json::Error> {
    let raw: RawTargets = serde_json::from_slice(data)?;
    let device_types = raw
        .devicetypes
        .unwrap_or_default()
        .into_iter()
        .filter(|d| !d.identifier.contains(APPLE_TV_MARKER))
        .map(|d| DeviceType::new(d.identifier, d.name))
        .collect();
    let runtimes = raw
        .runtimes
        .unwrap_or_default()
        .into_iter()
        .filter(|r| r.is_available.unwrap_or(true))
        .filter_map(|r| Runtime::from_identifier_with_version(&r.identifier, r.version.as_deref()))
        .collect();
    Ok(AvailableTargets { device_types, runtimes })
}

pub fn decode(data: &[u8]) -> Result<Vec<Simulator>, serde_json::Error> {
    let raw: RawList = serde_json::from_slice(data)?;
    let mut result = Vec::new();
    for (runtime_id, devices) in raw.devices {
        let Some(runtime) = Runtime::from_identifier(&runtime_id) else {
            continue;
        };
        for device in devices {
            let Ok(udid) = Uuid::parse_str(&device.udid) else {
                continue;
            };
            let Some(state) = SimulatorState::from_raw_value(&device.state) else {
                continue;
            };
            let device_type = DeviceType::from_identifier(device.device_type_identifier.unwrap_or_default());
            result.push(Simulator {
                id: udid,
                name: device.name,
                runtime: runtime.clone(),
                device_type,
                state,
                is_available: device.is_available,
                data_path: device.data_path.map(PathBuf::from),
                log_path: device.log_path.map(PathBuf::from),
            });
        }
    }
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = include_str!("../../tests/fixtures/simctl-list-fixture.json");

    #[test]
    fn decodes_fixture_devices() {
        let sims = decode(FIXTURE.as_bytes()).unwrap();
        assert!(!sims.is_empty());
    }

    #[test]
    fn skips_devices_with_unparseable_runtime() {
        let json = br#"{"devices":{"not-a-runtime":[{"udid":"11111111-1111-1111-1111-111111111111","name":"x","state":"Booted","isAvailable":true}]}}"#;
        let sims = decode(json).unwrap();
        assert!(sims.is_empty());
    }

    #[test]
    fn skips_devices_with_unparseable_udid() {
        let json = br#"{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"not-a-uuid","name":"x","state":"Booted","isAvailable":true}]}}"#;
        let sims = decode(json).unwrap();
        assert!(sims.is_empty());
    }

    #[test]
    fn filters_apple_tv_device_types() {
        let json = br#"{"devicetypes":[{"identifier":"com.apple.CoreSimulator.SimDeviceType.Apple-TV-4K","name":"Apple TV 4K"},{"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro","name":"iPhone 17 Pro"}],"runtimes":[]}"#;
        let targets = decode_available_targets(json).unwrap();
        assert_eq!(targets.device_types.len(), 1);
        assert_eq!(targets.device_types[0].name, "iPhone 17 Pro");
    }

    #[test]
    fn filters_unavailable_runtimes() {
        let json = br#"{"devicetypes":[],"runtimes":[{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-18-0","name":"iOS 18.0","version":"18.0","isAvailable":false}]}"#;
        let targets = decode_available_targets(json).unwrap();
        assert!(targets.runtimes.is_empty());
    }
}
