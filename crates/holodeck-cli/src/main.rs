mod commands;
mod confirm_prompt;
mod format;
mod resolve;
mod value_parsers;

use clap::{Parser, Subcommand};

use commands::appearance::AppearanceArgs;
use commands::apps::AppsArgs;
use commands::create::CreateArgs;
use commands::delete::DeleteArgs;
use commands::erase::EraseArgs;
use commands::keychain::KeychainArgs;
use commands::launch::LaunchArgs;
use commands::list::ListArgs;
use commands::locale::LocaleArgs;
use commands::location::LocationArgs;
use commands::openurl::OpenUrlArgs;
use commands::privacy::PrivacyArgs;
use commands::record::RecordArgs;
use commands::screenshot::ScreenshotArgs;
use commands::simple::{BootArgs, FocusArgs, ShutdownArgs};
use commands::statusbar::StatusBarArgs;
use commands::tui::TuiArgs;

#[derive(Parser, Debug)]
#[command(name = "holodeck", about = "iOS Simulator management TUI/CLI")]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// List available simulators.
    List(ListArgs),
    /// Boot a simulator by name or UDID.
    Boot(BootArgs),
    /// Shut down a simulator by name or UDID.
    Shutdown(ShutdownArgs),
    /// Record video from a booted simulator. Press Ctrl-C to stop cleanly.
    Record(RecordArgs),
    /// Capture a screenshot from a booted simulator.
    Screenshot(ScreenshotArgs),
    /// Set light or dark appearance on a booted simulator.
    Appearance(AppearanceArgs),
    /// Override or clear the simulator status bar.
    Statusbar(StatusBarArgs),
    /// Set the simulator locale and language.
    Locale(LocaleArgs),
    /// Create a new simulator by device type and runtime.
    Create(CreateArgs),
    /// Erase a simulator's content.
    Erase(EraseArgs),
    /// Delete a simulator, or all simulators with an unavailable runtime.
    Delete(DeleteArgs),
    /// Bring Simulator.app to the front, focused on the selected device.
    Focus(FocusArgs),
    /// Set or clear the simulator's simulated GPS location.
    Location(LocationArgs),
    /// Grant, revoke, or reset a privacy permission.
    Privacy(PrivacyArgs),
    /// Manage the simulator's keychain.
    Keychain(KeychainArgs),
    /// Inspect apps installed on a simulator.
    Apps(AppsArgs),
    /// Open a URL or deep link on a booted simulator.
    Openurl(OpenUrlArgs),
    /// Launch an installed app on a booted simulator.
    Launch(LaunchArgs),
    /// Start the interactive simulator TUI.
    Tui(TuiArgs),
}

#[tokio::main]
async fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Some(Commands::List(args)) => args.run().await,
        Some(Commands::Boot(args)) => args.run().await,
        Some(Commands::Shutdown(args)) => args.run().await,
        Some(Commands::Record(args)) => args.run().await,
        Some(Commands::Screenshot(args)) => args.run().await,
        Some(Commands::Appearance(args)) => args.run().await,
        Some(Commands::Statusbar(args)) => args.run().await,
        Some(Commands::Locale(args)) => args.run().await,
        Some(Commands::Create(args)) => args.run().await,
        Some(Commands::Erase(args)) => args.run().await,
        Some(Commands::Delete(args)) => args.run().await,
        Some(Commands::Focus(args)) => args.run().await,
        Some(Commands::Location(args)) => args.run().await,
        Some(Commands::Privacy(args)) => args.run().await,
        Some(Commands::Keychain(args)) => args.run().await,
        Some(Commands::Apps(args)) => args.run().await,
        Some(Commands::Openurl(args)) => args.run().await,
        Some(Commands::Launch(args)) => args.run().await,
        Some(Commands::Tui(args)) => args.run().await,
        // Bare `holodeck` defaults to the TUI.
        None => TuiArgs {}.run().await,
    };

    if let Err(err) = result {
        eprintln!("Error: {err}");
        std::process::exit(1);
    }
}
