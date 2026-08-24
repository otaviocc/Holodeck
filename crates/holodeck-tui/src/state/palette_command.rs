use holodeck_core::models::{Simulator, SimulatorState};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PaletteCommand {
    Appearance,
    Boot,
    Delete,
    Erase,
    Focus,
    Inspect,
    Launch,
    New,
    Open,
    Privacy,
    Record,
    Screenshot,
    Shutdown,
}

impl PaletteCommand {
    const CASES: [PaletteCommand; 13] = [
        PaletteCommand::Appearance,
        PaletteCommand::Boot,
        PaletteCommand::Delete,
        PaletteCommand::Erase,
        PaletteCommand::Focus,
        PaletteCommand::Inspect,
        PaletteCommand::Launch,
        PaletteCommand::New,
        PaletteCommand::Open,
        PaletteCommand::Privacy,
        PaletteCommand::Record,
        PaletteCommand::Screenshot,
        PaletteCommand::Shutdown,
    ];

    /// Alphabetical ordering, used for deterministic ghost-autocomplete
    /// matching. All display names happen to already sort this way, so this
    /// is just `CASES` — kept as a function to mirror the Swift `all` and to
    /// stay correct if a display name ever changes.
    pub fn all() -> Vec<PaletteCommand> {
        let mut all = Self::CASES.to_vec();
        all.sort_by_key(|c| c.display_name());
        all
    }

    pub fn display_name(self) -> &'static str {
        match self {
            PaletteCommand::Appearance => "appearance",
            PaletteCommand::Boot => "boot",
            PaletteCommand::Delete => "delete",
            PaletteCommand::Erase => "erase",
            PaletteCommand::Focus => "focus",
            PaletteCommand::Inspect => "inspect",
            PaletteCommand::Launch => "launch",
            PaletteCommand::New => "new",
            PaletteCommand::Open => "open",
            PaletteCommand::Privacy => "privacy",
            PaletteCommand::Record => "record",
            PaletteCommand::Screenshot => "screenshot",
            PaletteCommand::Shutdown => "shutdown",
        }
    }

    pub fn description(self) -> &'static str {
        match self {
            PaletteCommand::Appearance => "Switch the booted simulator between light and dark",
            PaletteCommand::Boot => "Boot the selected simulator",
            PaletteCommand::Delete => "Delete the selected simulator",
            PaletteCommand::Erase => "Erase the selected (shutdown) simulator",
            PaletteCommand::Focus => "Bring Simulator.app to the front for the selection",
            PaletteCommand::Inspect => "Open the inspector for the selected simulator",
            PaletteCommand::Launch => "Launch an installed app on the booted simulator",
            PaletteCommand::New => "Create a new simulator (wizard)",
            PaletteCommand::Open => "Open a URL or deep link on the booted simulator",
            PaletteCommand::Privacy => "Grant or revoke privacy permissions for an app",
            PaletteCommand::Record => "Start screen recording on the booted simulator",
            PaletteCommand::Screenshot => "Capture a screenshot of the booted simulator",
            PaletteCommand::Shutdown => "Shut down the selected simulator",
        }
    }

    pub fn is_applicable(self, simulator: Option<&Simulator>, is_recording: bool) -> bool {
        match self {
            PaletteCommand::New => true,
            PaletteCommand::Focus | PaletteCommand::Inspect | PaletteCommand::Delete => simulator.is_some(),
            PaletteCommand::Boot => simulator.is_some_and(|s| s.state == SimulatorState::Shutdown),
            PaletteCommand::Shutdown => simulator.is_some_and(|s| s.state == SimulatorState::Booted),
            PaletteCommand::Erase => simulator.is_some_and(|s| s.state == SimulatorState::Shutdown),
            PaletteCommand::Record => simulator.is_some_and(|s| s.state == SimulatorState::Booted) && !is_recording,
            PaletteCommand::Screenshot
            | PaletteCommand::Appearance
            | PaletteCommand::Open
            | PaletteCommand::Privacy
            | PaletteCommand::Launch => simulator.is_some_and(|s| s.state == SimulatorState::Booted),
        }
    }

    /// Case-insensitive prefix match. An empty prefix matches every command.
    pub fn matches(self, prefix: &str) -> bool {
        if prefix.is_empty() {
            return true;
        }
        self.display_name().to_lowercase().starts_with(&prefix.to_lowercase())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_is_sorted_alphabetically_by_display_name() {
        let names: Vec<&str> = PaletteCommand::all().into_iter().map(PaletteCommand::display_name).collect();
        let mut sorted = names.clone();
        sorted.sort();
        assert_eq!(names, sorted);
    }

    #[test]
    fn empty_prefix_matches_everything() {
        assert!(PaletteCommand::Boot.matches(""));
    }

    #[test]
    fn prefix_match_is_case_insensitive() {
        assert!(PaletteCommand::Boot.matches("BO"));
        assert!(!PaletteCommand::Boot.matches("xyz"));
    }
}
