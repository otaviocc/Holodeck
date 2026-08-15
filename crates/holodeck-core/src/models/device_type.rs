use super::simctl_identifiers::DEVICE_TYPE_PREFIX;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct DeviceType {
    pub identifier: String,
    pub name: String,
}

impl DeviceType {
    pub fn new(identifier: impl Into<String>, name: impl Into<String>) -> Self {
        Self {
            identifier: identifier.into(),
            name: name.into(),
        }
    }

    pub fn from_identifier(identifier: impl Into<String>) -> Self {
        let identifier = identifier.into();
        let name = Self::humanize(&identifier);
        Self { identifier, name }
    }

    fn humanize(identifier: &str) -> String {
        let tail = identifier.strip_prefix(DEVICE_TYPE_PREFIX).unwrap_or(identifier);
        tail.replace('-', " ")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn humanizes_identifier() {
        let device = DeviceType::from_identifier("com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro");
        assert_eq!(device.name, "iPhone 17 Pro");
    }

    #[test]
    fn leaves_identifier_without_prefix_untouched_besides_dashes() {
        let device = DeviceType::from_identifier("iPhone-17-Pro");
        assert_eq!(device.name, "iPhone 17 Pro");
    }
}
