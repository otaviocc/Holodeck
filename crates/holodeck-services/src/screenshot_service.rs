use std::path::Path;
use std::sync::Arc;

use holodeck_core::models::ScreenshotType;
use holodeck_core::{SimctlClient, SimctlError, default_media_path};
use uuid::Uuid;

/// Not a pure pass-through: ensures the output directory exists before
/// capturing, unlike the other one-line facades that were collapsed away.
#[derive(Clone)]
pub struct ScreenshotService {
    client: Arc<dyn SimctlClient>,
}

impl ScreenshotService {
    pub fn new(client: Arc<dyn SimctlClient>) -> Self {
        Self { client }
    }

    pub async fn capture(&self, udid: Uuid, output: &Path, screenshot_type: ScreenshotType) -> Result<(), SimctlError> {
        default_media_path::ensure_directory_exists(output)?;
        self.client.screenshot(udid, output, screenshot_type).await
    }
}
