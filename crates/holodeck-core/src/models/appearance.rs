#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Appearance {
    Light,
    Dark,
}

impl Appearance {
    pub fn raw_value(self) -> &'static str {
        match self {
            Appearance::Light => "light",
            Appearance::Dark => "dark",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BatteryState {
    Charging,
    Charged,
    Discharging,
}

impl BatteryState {
    pub fn raw_value(self) -> &'static str {
        match self {
            BatteryState::Charging => "charging",
            BatteryState::Charged => "charged",
            BatteryState::Discharging => "discharging",
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct StatusBarOverrides {
    pub time: Option<String>,
    pub battery_state: Option<BatteryState>,
    pub battery_level: Option<i64>,
    pub wifi_bars: Option<i64>,
    pub cellular_bars: Option<i64>,
    pub operator_name: Option<String>,
}

impl StatusBarOverrides {
    pub fn is_empty(&self) -> bool {
        self.time.is_none()
            && self.battery_state.is_none()
            && self.battery_level.is_none()
            && self.wifi_bars.is_none()
            && self.cellular_bars.is_none()
            && self.operator_name.is_none()
    }

    pub fn simctl_arguments(&self) -> Vec<String> {
        let mut args = Vec::new();
        if let Some(time) = &self.time {
            args.push("--time".to_string());
            args.push(time.clone());
        }
        if let Some(state) = self.battery_state {
            args.push("--batteryState".to_string());
            args.push(state.raw_value().to_string());
        }
        if let Some(level) = self.battery_level {
            args.push("--batteryLevel".to_string());
            args.push(level.to_string());
        }
        if let Some(bars) = self.wifi_bars {
            args.push("--wifiBars".to_string());
            args.push(bars.to_string());
        }
        if let Some(bars) = self.cellular_bars {
            args.push("--cellularBars".to_string());
            args.push(bars.to_string());
        }
        if let Some(name) = &self.operator_name {
            args.push("--operatorName".to_string());
            args.push(name.clone());
        }
        args
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_overrides_report_empty() {
        assert!(StatusBarOverrides::default().is_empty());
    }

    #[test]
    fn builds_simctl_arguments_in_order() {
        let overrides = StatusBarOverrides {
            time: Some("9:41".to_string()),
            battery_level: Some(100),
            ..Default::default()
        };
        assert_eq!(overrides.simctl_arguments(), vec!["--time", "9:41", "--batteryLevel", "100"]);
    }
}
