use std::path::{Path, PathBuf};

use chrono::{DateTime, Local};

use crate::models::ScreenshotType;

fn timestamp(date: DateTime<Local>) -> String {
    date.format("%Y%m%d-%H%M%S").to_string()
}

pub fn record(directory: &Path, date: DateTime<Local>) -> PathBuf {
    directory.join(format!("sim_record_{}.mp4", timestamp(date)))
}

pub fn screenshot(directory: &Path, screenshot_type: ScreenshotType, date: DateTime<Local>) -> PathBuf {
    directory.join(format!("sim_screenshot_{}.{}", timestamp(date), screenshot_type.raw_value()))
}

pub fn ensure_directory_exists(path: &Path) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::TimeZone;

    fn fixed_date() -> DateTime<Local> {
        Local.with_ymd_and_hms(2026, 5, 13, 12, 19, 4).unwrap()
    }

    #[test]
    fn record_path_has_expected_format() {
        let path = record(Path::new("/tmp"), fixed_date());
        assert_eq!(path, PathBuf::from("/tmp/sim_record_20260513-121904.mp4"));
    }

    #[test]
    fn screenshot_path_uses_extension_from_type() {
        let path = screenshot(Path::new("/tmp"), ScreenshotType::Jpeg, fixed_date());
        assert_eq!(path, PathBuf::from("/tmp/sim_screenshot_20260513-121904.jpeg"));
    }
}
