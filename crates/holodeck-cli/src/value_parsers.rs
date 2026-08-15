//! Lowercased-string-to-enum conversions for `clap` `value_parser`s. The
//! Rust analogue of Swift's `ExpressibleByArgument`/`LowercasedRawArgument`
//! conformances in `ArgumentParserSupport.swift`.
//!
//! These live in the CLI crate rather than as `clap::ValueEnum` impls on the
//! `holodeck-core` types because Rust's orphan rules forbid implementing a
//! foreign trait (`ValueEnum`, from `clap`) for a foreign type from a third
//! crate — free parser functions sidestep that without adding a `clap`
//! dependency to `holodeck-core`.

use holodeck_core::models::{Appearance, BatteryState, Platform, PrivacyAction, PrivacyPermission, ScreenshotType, VideoCodec};

pub fn parse_platform(raw: &str) -> Result<Platform, String> {
    match raw.to_lowercase().as_str() {
        "ios" => Ok(Platform::IOS),
        "watchos" => Ok(Platform::WatchOS),
        "tvos" => Ok(Platform::TvOS),
        "visionos" => Ok(Platform::VisionOS),
        other => Err(format!("invalid platform '{other}' (expected ios, watchos, tvos, visionos)")),
    }
}

pub fn parse_video_codec(raw: &str) -> Result<VideoCodec, String> {
    match raw.to_lowercase().as_str() {
        "h264" => Ok(VideoCodec::H264),
        "hevc" => Ok(VideoCodec::Hevc),
        other => Err(format!("invalid codec '{other}' (expected h264, hevc)")),
    }
}

pub fn parse_screenshot_type(raw: &str) -> Result<ScreenshotType, String> {
    match raw.to_lowercase().as_str() {
        "png" => Ok(ScreenshotType::Png),
        "jpeg" => Ok(ScreenshotType::Jpeg),
        "tiff" => Ok(ScreenshotType::Tiff),
        "bmp" => Ok(ScreenshotType::Bmp),
        other => Err(format!("invalid image type '{other}' (expected png, jpeg, tiff, bmp)")),
    }
}

pub fn parse_appearance(raw: &str) -> Result<Appearance, String> {
    match raw.to_lowercase().as_str() {
        "light" => Ok(Appearance::Light),
        "dark" => Ok(Appearance::Dark),
        other => Err(format!("invalid appearance '{other}' (expected light, dark)")),
    }
}

pub fn parse_battery_state(raw: &str) -> Result<BatteryState, String> {
    match raw.to_lowercase().as_str() {
        "charging" => Ok(BatteryState::Charging),
        "charged" => Ok(BatteryState::Charged),
        "discharging" => Ok(BatteryState::Discharging),
        other => Err(format!(
            "invalid battery state '{other}' (expected charging, charged, discharging)"
        )),
    }
}

pub fn parse_privacy_action(raw: &str) -> Result<PrivacyAction, String> {
    match raw.to_lowercase().as_str() {
        "grant" => Ok(PrivacyAction::Grant),
        "revoke" => Ok(PrivacyAction::Revoke),
        "reset" => Ok(PrivacyAction::Reset),
        other => Err(format!("invalid action '{other}' (expected grant, revoke, reset)")),
    }
}

pub fn parse_privacy_permission(raw: &str) -> Result<PrivacyPermission, String> {
    match raw.to_lowercase().as_str() {
        "all" => Ok(PrivacyPermission::All),
        "calendar" => Ok(PrivacyPermission::Calendar),
        "contacts-limited" => Ok(PrivacyPermission::ContactsLimited),
        "contacts" => Ok(PrivacyPermission::Contacts),
        "location" => Ok(PrivacyPermission::Location),
        "location-always" => Ok(PrivacyPermission::LocationAlways),
        "photos-add" => Ok(PrivacyPermission::PhotosAdd),
        "photos" => Ok(PrivacyPermission::Photos),
        "media-library" => Ok(PrivacyPermission::MediaLibrary),
        "microphone" => Ok(PrivacyPermission::Microphone),
        "motion" => Ok(PrivacyPermission::Motion),
        "reminders" => Ok(PrivacyPermission::Reminders),
        "siri" => Ok(PrivacyPermission::Siri),
        other => Err(format!(
            "invalid permission '{other}' (expected all, calendar, contacts, contacts-limited, location, location-always, photos, photos-add, media-library, microphone, motion, reminders, siri)"
        )),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn platform_parsing_is_case_insensitive() {
        assert_eq!(parse_platform("IOS").unwrap(), Platform::IOS);
        assert_eq!(parse_platform("VisionOS").unwrap(), Platform::VisionOS);
    }

    #[test]
    fn platform_rejects_xros_unlike_the_simctl_name_parser() {
        assert!(parse_platform("xros").is_err());
    }

    #[test]
    fn privacy_permission_parses_all_thirteen_values() {
        for raw in [
            "all",
            "calendar",
            "contacts-limited",
            "contacts",
            "location",
            "location-always",
            "photos-add",
            "photos",
            "media-library",
            "microphone",
            "motion",
            "reminders",
            "siri",
        ] {
            assert!(parse_privacy_permission(raw).is_ok(), "{raw} should parse");
        }
    }
}
