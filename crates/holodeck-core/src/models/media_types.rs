use serde::{Deserialize, Serialize};

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum VideoCodec {
    #[default]
    H264,
    Hevc,
}

impl VideoCodec {
    pub fn raw_value(self) -> &'static str {
        match self {
            VideoCodec::H264 => "h264",
            VideoCodec::Hevc => "hevc",
        }
    }
}

#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum ScreenshotType {
    #[default]
    Png,
    Jpeg,
    Tiff,
    Bmp,
}

impl ScreenshotType {
    pub fn raw_value(self) -> &'static str {
        match self {
            ScreenshotType::Png => "png",
            ScreenshotType::Jpeg => "jpeg",
            ScreenshotType::Tiff => "tiff",
            ScreenshotType::Bmp => "bmp",
        }
    }
}
