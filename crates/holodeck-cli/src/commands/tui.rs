use clap::Args;
use holodeck_tui::HolodeckApp;

/// Launch the interactive simulator TUI.
#[derive(Args, Debug)]
pub struct TuiArgs {}

impl TuiArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        HolodeckApp::live().run().await?;
        Ok(())
    }
}
