use clap::Args;

/// Launch the interactive simulator TUI.
#[derive(Args, Debug)]
pub struct TuiArgs {}

impl TuiArgs {
    pub async fn run(&self) -> anyhow::Result<()> {
        // Phases 4-5 of the port plan (holodeck-tui) aren't implemented yet.
        eprintln!("holodeck: the TUI hasn't been ported yet (see port plan phases 4-5). Try a subcommand — `holodeck --help`.");
        Ok(())
    }
}
