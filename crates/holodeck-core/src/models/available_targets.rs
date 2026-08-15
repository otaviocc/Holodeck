use super::device_type::DeviceType;
use super::runtime::Runtime;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AvailableTargets {
    pub device_types: Vec<DeviceType>,
    pub runtimes: Vec<Runtime>,
}
