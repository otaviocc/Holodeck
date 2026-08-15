use std::path::PathBuf;

use holodeck_core::models::{Appearance, DeviceType, InstalledApp, PrivacyAction, PrivacyPermission, Runtime, Simulator};
use uuid::Uuid;

use super::app_state::AppState;
use super::key::Key;

#[derive(Debug, Clone)]
pub enum AppEvent {
    Refreshed(Vec<Simulator>),
    RefreshFailed(String),
    Key(Key),
    Resized {
        rows: i64,
        cols: i64,
    },
    PollTick,
    OperationCompleted(Uuid),
    OperationFailed(Uuid, String),
    RecordingStarted(Uuid, PathBuf),
    RecordingStopped(Option<PathBuf>),
    RecordingFailed(String),
    ScreenshotSaved(PathBuf),
    ScreenshotFailed(String),
    AppearanceChanged(Uuid, Appearance),
    AppearanceFailed(String),
    TargetsLoaded {
        device_types: Vec<DeviceType>,
        runtimes: Vec<Runtime>,
    },
    TargetsFailed(String),
    SimulatorCreated(Uuid, String),
    SimulatorCreateFailed(String),
    AppsLoaded(Vec<InstalledApp>),
    AppsLoadFailed(String),
    PrivacyApplied {
        bundle_id: String,
    },
    PrivacyApplyFailed(String),
    UrlHistoryLoaded(Vec<String>),
    UrlOpened {
        url: String,
        history: Vec<String>,
    },
    UrlOpenFailed(String),
}

#[derive(Debug, Clone, PartialEq)]
pub enum SideEffect {
    Boot(Uuid),
    Shutdown(Uuid),
    Refresh,
    StartRecording(Uuid),
    StopRecording,
    CaptureScreenshot(Uuid),
    SetAppearance(Uuid, Appearance),
    EraseSimulator(Uuid),
    DeleteSimulator(Uuid),
    LoadTargets,
    CreateSimulator {
        name: String,
        device_type: DeviceType,
        runtime: Runtime,
    },
    FocusSimulator(Uuid),
    LoadInstalledApps(Uuid),
    ApplyPrivacy {
        udid: Uuid,
        action: PrivacyAction,
        permission: PrivacyPermission,
        bundle_id: String,
    },
    LoadUrlHistory,
    OpenUrl {
        udid: Uuid,
        url: String,
    },
}

#[derive(Debug, Clone, PartialEq)]
pub struct ReducerOutput {
    pub state: AppState,
    pub effects: Vec<SideEffect>,
}

impl ReducerOutput {
    pub fn new(state: AppState) -> Self {
        Self {
            state,
            effects: Vec::new(),
        }
    }

    pub fn with_effects(state: AppState, effects: Vec<SideEffect>) -> Self {
        Self { state, effects }
    }
}
