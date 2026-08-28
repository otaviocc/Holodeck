use holodeck_core::models::{
    DeviceType, InstalledApp, LanguageOption, PrivacyAction, PrivacyPermission, RegionOption, Runtime, Simulator,
};
use uuid::Uuid;

use super::text_input::TextField;

/// Intent behind an in-flight simctl operation. Lets the reducer reconcile
/// `pending_operations` against an arriving `Refreshed` listing — if the sim
/// already reached the target state we can drop the pending entry even when
/// the spawned task has not yet returned (a known macOS quirk where `xcrun
/// simctl shutdown` can block for many seconds after the simulator is
/// already shut down).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PendingOperation {
    Boot,
    Shutdown,
    Erase,
    Delete,
}

#[derive(Debug, Clone, PartialEq)]
pub enum Modal {
    /// Selected index: 0 = Light, 1 = Dark.
    Appearance(i64),
    /// Selected index: 0 = Yes, 1 = No.
    ConfirmErase(Uuid, i64),
    /// Selected index: 0 = Yes, 1 = No.
    ConfirmDelete(Uuid, i64),
    CreateWizard(CreateWizard),
    PrivacyWizard(PrivacyWizard),
    LaunchApp(LaunchAppPrompt),
    Inspector(Uuid),
    OpenUrl(OpenUrlPrompt),
    CommandPalette(CommandPalette),
    Help,
}

impl Modal {
    /// Some modals reference a specific simulator by UDID. If that sim
    /// disappears between the modal opening and the next refresh, the
    /// reducer drops the modal.
    pub fn referenced_simulator(&self) -> Option<Uuid> {
        match self {
            Modal::ConfirmErase(id, _) | Modal::ConfirmDelete(id, _) | Modal::Inspector(id) => Some(*id),
            Modal::OpenUrl(prompt) => Some(prompt.simulator_id),
            Modal::LaunchApp(prompt) => Some(prompt.simulator_id),
            Modal::CommandPalette(palette) => palette.simulator_id,
            Modal::Appearance(_) | Modal::CreateWizard(_) | Modal::PrivacyWizard(_) | Modal::Help => None,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct CommandPalette {
    /// Simulator selected when the palette was opened. `None` when no sim was
    /// selected (only the `new` command is applicable). Used so a refresh
    /// that drops the underlying sim auto-dismisses the palette before it
    /// can run a command against the wrong target.
    pub simulator_id: Option<Uuid>,
    pub query: TextField,
}

#[derive(Debug, Clone, PartialEq)]
pub struct OpenUrlPrompt {
    pub simulator_id: Uuid,
    pub url: TextField,
    pub history_index: i64,
    pub is_submitting: bool,
    pub error: Option<String>,
}

impl OpenUrlPrompt {
    pub fn new(simulator_id: Uuid) -> Self {
        Self { simulator_id, url: TextField::new(), history_index: -1, is_submitting: false, error: None }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrivacyWizardStep {
    LoadingApps,
    PickApp,
    PickAction,
    PickPermission,
    Submitting,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PrivacyWizard {
    pub simulator_id: Uuid,
    pub step: PrivacyWizardStep,
    pub all_apps: Vec<InstalledApp>,
    pub app_index: i64,
    pub app_scroll_offset: i64,
    pub action_index: i64,
    pub permission_index: i64,
    pub show_system: bool,
    pub error: Option<String>,
}

impl PrivacyWizard {
    pub fn new(simulator_id: Uuid) -> Self {
        Self {
            simulator_id,
            step: PrivacyWizardStep::LoadingApps,
            all_apps: Vec::new(),
            app_index: 0,
            app_scroll_offset: 0,
            action_index: 0,
            permission_index: 0,
            show_system: false,
            error: None,
        }
    }

    /// Only the app list scrolls. PrivacyAction/PrivacyPermission lists fit
    /// any viewport and the view auto-centers their focus at render time.
    pub fn app_viewport(rows: i64) -> i64 {
        (rows - 5).max(3)
    }

    pub fn apps(&self) -> Vec<&InstalledApp> {
        self.all_apps.iter().filter(|app| self.show_system || app.is_user_app).collect()
    }

    pub fn selected_app(&self) -> Option<&InstalledApp> {
        let list = self.apps();
        usize::try_from(self.app_index).ok().and_then(|i| list.get(i).copied())
    }

    pub fn selected_action(&self) -> Option<PrivacyAction> {
        usize::try_from(self.action_index).ok().and_then(|i| PrivacyAction::ALL.get(i).copied())
    }

    pub fn selected_permission(&self) -> Option<PrivacyPermission> {
        usize::try_from(self.permission_index).ok().and_then(|i| PrivacyPermission::ALL.get(i).copied())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum LaunchAppStep {
    LoadingApps,
    PickApp,
    PickLanguage,
    PickRegion,
    Submitting,
}

#[derive(Debug, Clone, PartialEq)]
pub struct LaunchAppPrompt {
    pub simulator_id: Uuid,
    pub step: LaunchAppStep,
    pub all_apps: Vec<InstalledApp>,
    pub app_index: i64,
    pub app_scroll_offset: i64,
    pub show_system: bool,
    /// Language attached while chaining through `PickLanguage` into
    /// `PickRegion` (see `launch_app_reducer`). `None` when the region
    /// picker was reached directly (a region-only launch), which also
    /// distinguishes what `Esc` means once inside `PickRegion`.
    pub chosen_language: Option<&'static LanguageOption>,
    pub language_index: i64,
    pub language_scroll_offset: i64,
    pub language_filter: TextField,
    pub is_language_filter_focused: bool,
    pub region_index: i64,
    pub region_scroll_offset: i64,
    pub region_filter: TextField,
    pub is_region_filter_focused: bool,
    pub error: Option<String>,
}

impl LaunchAppPrompt {
    pub fn new(simulator_id: Uuid) -> Self {
        Self {
            simulator_id,
            step: LaunchAppStep::LoadingApps,
            all_apps: Vec::new(),
            app_index: 0,
            app_scroll_offset: 0,
            show_system: false,
            chosen_language: None,
            language_index: 0,
            language_scroll_offset: 0,
            language_filter: TextField::new(),
            is_language_filter_focused: false,
            region_index: 0,
            region_scroll_offset: 0,
            region_filter: TextField::new(),
            is_region_filter_focused: false,
            error: None,
        }
    }

    pub fn app_viewport(rows: i64) -> i64 {
        (rows - 5).max(3)
    }

    /// The language filter is a conditional banner (visible once focused or
    /// once something has been typed) — mirrors
    /// `CreateWizard::device_type_viewport`'s filter-banner accounting, and
    /// the reducer's scroll math and the view's layout must agree on it.
    pub fn language_viewport(&self, rows: i64) -> i64 {
        let banner = i64::from(self.is_language_filter_focused || !self.language_filter.is_empty());
        (Self::app_viewport(rows) - banner).max(1)
    }

    /// Same accounting as `language_viewport`, for the region filter banner.
    pub fn region_viewport(&self, rows: i64) -> i64 {
        let banner = i64::from(self.is_region_filter_focused || !self.region_filter.is_empty());
        (Self::app_viewport(rows) - banner).max(1)
    }

    pub fn apps(&self) -> Vec<&InstalledApp> {
        self.all_apps.iter().filter(|app| self.show_system || app.is_user_app).collect()
    }

    pub fn selected_app(&self) -> Option<&InstalledApp> {
        let list = self.apps();
        usize::try_from(self.app_index).ok().and_then(|i| list.get(i).copied())
    }

    pub fn visible_languages(&self) -> Vec<&'static LanguageOption> {
        if self.language_filter.is_empty() {
            return LanguageOption::ALL.iter().collect();
        }
        let needle = self.language_filter.to_lowercase();
        LanguageOption::ALL.iter().filter(|l| l.display_name.to_lowercase().contains(&needle)).collect()
    }

    pub fn selected_language(&self) -> Option<&'static LanguageOption> {
        let list = self.visible_languages();
        usize::try_from(self.language_index).ok().and_then(|i| list.get(i).copied())
    }

    pub fn visible_regions(&self) -> Vec<&'static RegionOption> {
        if self.region_filter.is_empty() {
            return RegionOption::ALL.iter().collect();
        }
        let needle = self.region_filter.to_lowercase();
        RegionOption::ALL.iter().filter(|r| r.display_name.to_lowercase().contains(&needle)).collect()
    }

    pub fn selected_region(&self) -> Option<&'static RegionOption> {
        let list = self.visible_regions();
        usize::try_from(self.region_index).ok().and_then(|i| list.get(i).copied())
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum CreateWizardStep {
    #[default]
    Loading,
    PickDeviceType,
    PickRuntime,
    Confirm,
    Submitting,
}

#[derive(Debug, Clone, PartialEq, Default)]
pub struct CreateWizard {
    pub step: CreateWizardStep,
    pub device_types: Vec<DeviceType>,
    pub runtimes: Vec<Runtime>,
    pub device_type_index: i64,
    pub device_type_scroll_offset: i64,
    pub runtime_index: i64,
    pub runtime_scroll_offset: i64,
    pub device_type_filter: TextField,
    pub is_device_type_filter_focused: bool,
    pub error: Option<String>,
}

impl CreateWizard {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn viewport(rows: i64) -> i64 {
        (rows - 5).max(3)
    }

    /// Device-type list viewport accounting for the filter banner (one row).
    /// The reducer's scroll math and the view's row clamp must agree on this
    /// number — otherwise the selected row can sit just off the bottom edge.
    pub fn device_type_viewport(&self, rows: i64) -> i64 {
        let banner = if self.is_device_type_filter_focused || !self.device_type_filter.is_empty() { 1 } else { 0 };
        (Self::viewport(rows) - banner).max(1)
    }

    pub fn visible_device_types(&self) -> Vec<&DeviceType> {
        if self.device_type_filter.is_empty() {
            return self.device_types.iter().collect();
        }
        let needle = self.device_type_filter.to_lowercase();
        self.device_types.iter().filter(|d| d.name.to_lowercase().contains(&needle)).collect()
    }

    pub fn selected_device_type(&self) -> Option<&DeviceType> {
        let list = self.visible_device_types();
        usize::try_from(self.device_type_index).ok().and_then(|i| list.get(i).copied())
    }

    pub fn selected_runtime(&self) -> Option<&Runtime> {
        usize::try_from(self.runtime_index).ok().and_then(|i| self.runtimes.get(i))
    }

    pub fn default_name(&self) -> String {
        match (self.selected_device_type(), self.selected_runtime()) {
            (Some(device_type), Some(runtime)) => format!("{} ({})", device_type.name, runtime.display_name()),
            _ => "Simulator".to_string(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct AppState {
    pub simulators: Vec<Simulator>,
    pub selected_index: i64,
    pub main_scroll_offset: i64,
    pub filter_query: TextField,
    pub is_filter_focused: bool,
    pub status_message: Option<String>,
    pub last_error: Option<String>,
    pub pending_operations: std::collections::HashMap<Uuid, PendingOperation>,
    pub is_quitting: bool,
    pub rows: i64,
    pub cols: i64,
    pub recording_device_id: Option<Uuid>,
    pub recording_path: Option<std::path::PathBuf>,
    pub modal: Option<Modal>,
    pub url_history: Vec<String>,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            simulators: Vec::new(),
            selected_index: 0,
            main_scroll_offset: 0,
            filter_query: TextField::new(),
            is_filter_focused: false,
            status_message: None,
            last_error: None,
            pending_operations: std::collections::HashMap::new(),
            is_quitting: false,
            rows: 24,
            cols: 80,
            recording_device_id: None,
            recording_path: None,
            modal: None,
            url_history: Vec::new(),
        }
    }
}

impl AppState {
    pub fn is_recording(&self) -> bool {
        self.recording_device_id.is_some()
    }

    pub fn visible_simulators(&self) -> Vec<&Simulator> {
        if self.filter_query.is_empty() {
            return self.simulators.iter().collect();
        }
        let needle = self.filter_query.to_lowercase();
        self.simulators.iter().filter(|sim| sim.name.to_lowercase().contains(&needle)).collect()
    }

    pub fn selected_simulator(&self) -> Option<&Simulator> {
        // Skip the filter rebuild on the unfiltered path — selected_index
        // already indexes directly into `simulators`.
        if self.filter_query.is_empty() {
            return usize::try_from(self.selected_index).ok().and_then(|i| self.simulators.get(i));
        }
        let list = self.visible_simulators();
        usize::try_from(self.selected_index).ok().and_then(|i| list.get(i).copied())
    }

    /// Conservative count of simulator rows that fit. The view walks the list
    /// from `main_scroll_offset` and stops when body height is exhausted; the
    /// 2-line headroom leaves room for runtime-group headers without exact
    /// counting.
    ///
    /// All modals except `Appearance`, `ConfirmErase`, and `ConfirmDelete` are
    /// rendered as floating popup overlays on top of the simulator list, so
    /// they do not consume any banner rows in the main layout.
    pub fn main_list_viewport(&self) -> i64 {
        let banner = i64::from(self.is_recording());
        (self.rows - 4 - banner - 2).max(1)
    }

    /// Scroll-on-edge offset for a windowed list. Returns the new top-visible
    /// index given the current offset, the focused index, and the viewport.
    pub fn scroll(offset: i64, index: i64, viewport: i64) -> i64 {
        if index < offset {
            return index;
        }
        if index >= offset + viewport {
            return index - viewport + 1;
        }
        offset
    }

    pub fn sort(mut simulators: Vec<Simulator>) -> Vec<Simulator> {
        simulators.sort_by(|lhs, rhs| rhs.runtime.cmp(&lhs.runtime).then_with(|| lhs.name.cmp(&rhs.name)));
        simulators
    }
}
