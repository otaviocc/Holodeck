use std::future::Future;
use std::time::Duration;

use chrono::Local;
use holodeck_core::{SimctlError, default_media_path};
use holodeck_services::AppDependencies;
use ratatui::DefaultTerminal;
use ratatui::crossterm::event::{self, Event};
use tokio::sync::mpsc::{UnboundedSender, unbounded_channel};
use uuid::Uuid;

use crate::input::map_key_event;
use crate::state::{self, AppEvent, AppState, SideEffect};
use crate::theme::Theme;
use crate::view;

pub struct HolodeckApp {
    dependencies: AppDependencies,
}

impl HolodeckApp {
    pub fn new(dependencies: AppDependencies) -> Self {
        Self { dependencies }
    }

    pub fn live() -> Self {
        Self::new(AppDependencies::live())
    }

    pub async fn run(&self) -> std::io::Result<()> {
        let mut terminal = ratatui::init();
        let result = self.run_loop(&mut terminal).await;
        ratatui::restore();
        if self.dependencies.recording_service.is_recording().await {
            let _ = self.dependencies.recording_service.stop().await;
        }
        result
    }

    async fn run_loop(&self, terminal: &mut DefaultTerminal) -> std::io::Result<()> {
        let (tx, mut rx) = unbounded_channel::<AppEvent>();

        let input_tx = tx.clone();
        std::thread::spawn(move || input_loop(input_tx));

        let poll_interval = Duration::from_secs_f64(self.dependencies.configuration.poll_interval_seconds.max(0.1));
        let poll_tx = tx.clone();
        let poll_task = tokio::spawn(async move {
            let mut ticker = tokio::time::interval(poll_interval);
            ticker.tick().await; // first tick fires immediately; the initial Refresh below already covers it
            loop {
                ticker.tick().await;
                if poll_tx.send(AppEvent::PollTick).is_err() {
                    break;
                }
            }
        });

        let size = terminal.size()?;
        let mut state = AppState {
            rows: i64::from(size.height),
            cols: i64::from(size.width),
            ..AppState::default()
        };
        // Resolved once at launch, like the Swift TUI's other config reads
        // (`pollIntervalSeconds`) — a theme change requires a restart.
        let theme = Theme::from_name(self.dependencies.configuration.theme);

        self.dispatch(SideEffect::Refresh, tx.clone());
        self.dispatch(SideEffect::LoadUrlHistory, tx.clone());

        terminal.draw(|frame| view::render(frame, &state, &theme))?;
        let mut last_rendered = state.clone();

        while let Some(event) = rx.recv().await {
            let output = state::reduce(&state, event);
            state = output.state;
            for effect in output.effects {
                self.dispatch(effect, tx.clone());
            }
            if state != last_rendered {
                terminal.draw(|frame| view::render(frame, &state, &theme))?;
                last_rendered = state.clone();
            }
            if state.is_quitting {
                break;
            }
        }

        poll_task.abort();
        Ok(())
    }

    fn dispatch(&self, effect: SideEffect, tx: UnboundedSender<AppEvent>) {
        let deps = &self.dependencies;
        match effect {
            SideEffect::Boot(id) => spawn_per_simulator(tx, id, {
                let service = deps.simulator_service.clone();
                move |id| async move { service.boot(id).await }
            }),
            SideEffect::Shutdown(id) => spawn_per_simulator(tx, id, {
                let service = deps.simulator_service.clone();
                move |id| async move { service.shutdown(id).await }
            }),
            SideEffect::EraseSimulator(id) => spawn_per_simulator(tx, id, {
                let service = deps.simulator_service.clone();
                move |id| async move { service.erase(id).await }
            }),
            SideEffect::DeleteSimulator(id) => spawn_per_simulator(tx, id, {
                let service = deps.simulator_service.clone();
                move |id| async move { service.delete(id).await }
            }),

            SideEffect::Refresh => {
                let service = deps.simulator_service.clone();
                spawn(
                    tx,
                    async move { service.list(false).await },
                    AppEvent::Refreshed,
                    AppEvent::RefreshFailed,
                );
            }

            SideEffect::StartRecording(id) => {
                let recording_service = deps.recording_service.clone();
                let output = default_media_path::record(&deps.configuration.resolved_screenshots_directory(), Local::now());
                let codec = deps.configuration.video_codec;
                let output_for_event = output.clone();
                tokio::spawn(async move {
                    match recording_service.start(id, &output, codec).await {
                        Ok(()) => {
                            let _ = tx.send(AppEvent::RecordingStarted(id, output_for_event));
                        }
                        Err(err) => {
                            let _ = tx.send(AppEvent::RecordingFailed(err.to_string()));
                        }
                    }
                });
            }

            SideEffect::StopRecording => {
                let recording_service = deps.recording_service.clone();
                tokio::spawn(async move {
                    let path = recording_service.stop().await;
                    let _ = tx.send(AppEvent::RecordingStopped(path));
                });
            }

            SideEffect::CaptureScreenshot(id) => {
                let screenshot_service = deps.screenshot_service.clone();
                let screenshot_type = deps.configuration.screenshot_type;
                let output = default_media_path::screenshot(
                    &deps.configuration.resolved_screenshots_directory(),
                    screenshot_type,
                    Local::now(),
                );
                let output_for_event = output.clone();
                tokio::spawn(async move {
                    match screenshot_service.capture(id, &output, screenshot_type).await {
                        Ok(()) => {
                            let _ = tx.send(AppEvent::ScreenshotSaved(output_for_event));
                        }
                        Err(err) => {
                            let _ = tx.send(AppEvent::ScreenshotFailed(err.to_string()));
                        }
                    }
                });
            }

            SideEffect::SetAppearance(id, appearance) => {
                let client = deps.simctl_client.clone();
                tokio::spawn(async move {
                    match client.set_appearance(id, appearance).await {
                        Ok(()) => {
                            let _ = tx.send(AppEvent::AppearanceChanged(id, appearance));
                        }
                        Err(err) => {
                            let _ = tx.send(AppEvent::AppearanceFailed(err.to_string()));
                        }
                    }
                });
            }

            SideEffect::LoadTargets => {
                let service = deps.simulator_service.clone();
                spawn(
                    tx,
                    async move { service.available_targets().await },
                    |targets| AppEvent::TargetsLoaded {
                        device_types: targets.device_types,
                        runtimes: targets.runtimes,
                    },
                    AppEvent::TargetsFailed,
                );
            }

            SideEffect::CreateSimulator {
                name,
                device_type,
                runtime,
            } => {
                let service = deps.simulator_service.clone();
                let name_for_event = name.clone();
                tokio::spawn(async move {
                    match service.create(&name, &device_type, &runtime).await {
                        Ok(id) => {
                            let _ = tx.send(AppEvent::SimulatorCreated(id, name_for_event));
                        }
                        Err(err) => {
                            let _ = tx.send(AppEvent::SimulatorCreateFailed(err.to_string()));
                        }
                    }
                });
            }

            SideEffect::FocusSimulator(id) => {
                let service = deps.simulator_service.clone();
                tokio::spawn(async move {
                    let _ = service.focus(id).await;
                });
            }

            SideEffect::LoadInstalledApps(id) => {
                let service = deps.simulator_service.clone();
                spawn(
                    tx,
                    async move { service.list_apps(id).await },
                    AppEvent::AppsLoaded,
                    AppEvent::AppsLoadFailed,
                );
            }

            SideEffect::ApplyPrivacy {
                udid,
                action,
                permission,
                bundle_id,
            } => {
                let client = deps.simctl_client.clone();
                let bundle_id_for_event = bundle_id.clone();
                tokio::spawn(async move {
                    match client.privacy(udid, action, permission, Some(&bundle_id)).await {
                        Ok(()) => {
                            let _ = tx.send(AppEvent::PrivacyApplied {
                                bundle_id: bundle_id_for_event,
                            });
                        }
                        Err(err) => {
                            let _ = tx.send(AppEvent::PrivacyApplyFailed(err.to_string()));
                        }
                    }
                });
            }

            SideEffect::LoadUrlHistory => {
                let store = deps.url_history_store.clone();
                tokio::spawn(async move {
                    let _ = tx.send(AppEvent::UrlHistoryLoaded(store.load()));
                });
            }

            SideEffect::OpenUrl { udid, url } => {
                let client = deps.simctl_client.clone();
                let store = deps.url_history_store.clone();
                tokio::spawn(async move {
                    match client.open_url(udid, &url).await {
                        Ok(()) => {
                            let history = store.record(&url).unwrap_or_else(|_| store.load());
                            let _ = tx.send(AppEvent::UrlOpened { url, history });
                        }
                        Err(err) => {
                            let _ = tx.send(AppEvent::UrlOpenFailed(err.to_string()));
                        }
                    }
                });
            }
        }
    }
}

/// One generic spawner replacing the ~18 near-identical `AppSpawn` helper
/// functions in the Swift original.
fn spawn<Fut, T>(
    tx: UnboundedSender<AppEvent>,
    work: Fut,
    on_ok: impl FnOnce(T) -> AppEvent + Send + 'static,
    on_err: impl FnOnce(String) -> AppEvent + Send + 'static,
) where
    Fut: Future<Output = Result<T, SimctlError>> + Send + 'static,
    T: Send + 'static,
{
    tokio::spawn(async move {
        match work.await {
            Ok(value) => {
                let _ = tx.send(on_ok(value));
            }
            Err(err) => {
                let _ = tx.send(on_err(err.to_string()));
            }
        }
    });
}

fn spawn_per_simulator<F, Fut>(tx: UnboundedSender<AppEvent>, id: Uuid, work: F)
where
    F: FnOnce(Uuid) -> Fut + Send + 'static,
    Fut: Future<Output = Result<(), SimctlError>> + Send + 'static,
{
    tokio::spawn(async move {
        match work(id).await {
            Ok(()) => {
                let _ = tx.send(AppEvent::OperationCompleted(id));
            }
            Err(err) => {
                let _ = tx.send(AppEvent::OperationFailed(id, err.to_string()));
            }
        }
    });
}

/// Blocking input loop, run on a plain OS thread rather than a tokio task
/// since `crossterm::event::{poll, read}` are blocking calls. Sending on an
/// `UnboundedSender` from outside the tokio runtime is fine — it's a plain
/// non-blocking queue push.
fn input_loop(tx: UnboundedSender<AppEvent>) {
    loop {
        let ready = match event::poll(Duration::from_millis(100)) {
            Ok(ready) => ready,
            Err(_) => return,
        };
        if !ready {
            continue;
        }
        let Ok(ev) = event::read() else { return };
        let mapped = match ev {
            Event::Key(key_event) => map_key_event(key_event).map(AppEvent::Key),
            Event::Resize(cols, rows) => Some(AppEvent::Resized {
                rows: i64::from(rows),
                cols: i64::from(cols),
            }),
            _ => None,
        };
        if let Some(event) = mapped
            && tx.send(event).is_err()
        {
            return;
        }
    }
}
