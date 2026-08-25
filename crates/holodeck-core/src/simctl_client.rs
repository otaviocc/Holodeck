use std::path::Path;

use async_trait::async_trait;
use uuid::Uuid;

use crate::decoding::{app_list, device_list};
use crate::error::SimctlError;
use crate::models::{
    Appearance, AvailableTargets, InstalledApp, PrivacyAction, PrivacyPermission, ScreenshotType, Simulator, StatusBarOverrides,
    VideoCodec,
};
use crate::process_runner::{ProcessRunning, TokioProcessRunner};

/// The 21-operation `xcrun simctl` surface. The Rust analogue of Swift's
/// `SimctlClient` protocol witness: a trait rather than a struct-of-closures,
/// since Rust traits give the same live/mock seam without closure-capture
/// boilerplate.
#[async_trait]
pub trait SimctlClient: Send + Sync {
    async fn list_devices(&self, include_unavailable: bool) -> Result<Vec<Simulator>, SimctlError>;
    async fn boot(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn shutdown(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn screenshot(&self, udid: Uuid, path: &Path, screenshot_type: ScreenshotType) -> Result<(), SimctlError>;
    async fn set_appearance(&self, udid: Uuid, appearance: Appearance) -> Result<(), SimctlError>;
    async fn set_status_bar(&self, udid: Uuid, overrides: &StatusBarOverrides) -> Result<(), SimctlError>;
    async fn clear_status_bar(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn set_locale(&self, udid: Uuid, bcp47: &str) -> Result<(), SimctlError>;
    async fn list_available_targets(&self) -> Result<AvailableTargets, SimctlError>;
    async fn list_apps(&self, udid: Uuid) -> Result<Vec<InstalledApp>, SimctlError>;
    async fn create(&self, name: &str, device_type_identifier: &str, runtime_identifier: &str) -> Result<Uuid, SimctlError>;
    async fn erase(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn delete(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn delete_unavailable(&self) -> Result<(), SimctlError>;
    async fn set_location(&self, udid: Uuid, latitude: f64, longitude: f64) -> Result<(), SimctlError>;
    async fn clear_location(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn privacy(
        &self,
        udid: Uuid,
        action: PrivacyAction,
        permission: PrivacyPermission,
        bundle_id: Option<&str>,
    ) -> Result<(), SimctlError>;
    async fn reset_keychain(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn open_url(&self, udid: Uuid, url: &str) -> Result<(), SimctlError>;
    async fn focus_simulator_app(&self, udid: Uuid) -> Result<(), SimctlError>;
    async fn launch_app(
        &self,
        udid: Uuid,
        bundle_id: &str,
        language: Option<&str>,
        region: Option<&str>,
    ) -> Result<(), SimctlError>;
}

/// Builds the argv for `simctl io <udid> recordVideo`. Only constructs the
/// command — spawning and owning the child process is `Recorder`'s job,
/// because the SIGINT-to-finalize semantics live there.
pub fn record_video_command(udid: Uuid, output: &Path, codec: VideoCodec) -> (&'static str, Vec<String>) {
    (
        "/usr/bin/xcrun",
        vec![
            "simctl".to_string(),
            "io".to_string(),
            udid.to_string(),
            "recordVideo".to_string(),
            "--codec".to_string(),
            codec.raw_value().to_string(),
            output.to_string_lossy().into_owned(),
        ],
    )
}

pub struct LiveSimctlClient<R: ProcessRunning = TokioProcessRunner> {
    runner: R,
}

impl LiveSimctlClient<TokioProcessRunner> {
    pub fn new() -> Self {
        Self { runner: TokioProcessRunner }
    }
}

impl Default for LiveSimctlClient<TokioProcessRunner> {
    fn default() -> Self {
        Self::new()
    }
}

impl<R: ProcessRunning> LiveSimctlClient<R> {
    pub fn with_runner(runner: R) -> Self {
        Self { runner }
    }

    async fn run_process(&self, launch_path: &str, label: &str, arguments: Vec<String>) -> Result<Vec<u8>, SimctlError> {
        let result = self.runner.run(launch_path, &arguments).await.map_err(|err| SimctlError::CommandFailed {
            command: format!("{label} {}", arguments.join(" ")),
            exit_code: -1,
            stderr: err.to_string(),
        })?;
        if result.exit_code != 0 {
            return Err(SimctlError::CommandFailed {
                command: format!("{label} {}", arguments.join(" ")),
                exit_code: result.exit_code,
                stderr: String::from_utf8_lossy(&result.stderr).into_owned(),
            });
        }
        Ok(result.stdout)
    }

    async fn run_simctl(&self, subcommand: Vec<String>) -> Result<Vec<u8>, SimctlError> {
        let mut args = vec!["simctl".to_string()];
        args.extend(subcommand);
        self.run_process("/usr/bin/xcrun", "xcrun", args).await
    }
}

#[async_trait]
impl<R: ProcessRunning> SimctlClient for LiveSimctlClient<R> {
    async fn list_devices(&self, include_unavailable: bool) -> Result<Vec<Simulator>, SimctlError> {
        let mut args = vec!["list".to_string(), "--json".to_string(), "devices".to_string()];
        if !include_unavailable {
            args.push("available".to_string());
        }
        let stdout = self.run_simctl(args).await?;
        device_list::decode(&stdout).map_err(|err| SimctlError::DecodingFailed { underlying: Box::new(err) })
    }

    async fn boot(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["boot".to_string(), udid.to_string()]).await?;
        Ok(())
    }

    async fn shutdown(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["shutdown".to_string(), udid.to_string()]).await?;
        Ok(())
    }

    async fn screenshot(&self, udid: Uuid, path: &Path, screenshot_type: ScreenshotType) -> Result<(), SimctlError> {
        self.run_simctl(vec![
            "io".to_string(),
            udid.to_string(),
            "screenshot".to_string(),
            "--type".to_string(),
            screenshot_type.raw_value().to_string(),
            path.to_string_lossy().into_owned(),
        ])
        .await?;
        Ok(())
    }

    async fn set_appearance(&self, udid: Uuid, appearance: Appearance) -> Result<(), SimctlError> {
        self.run_simctl(vec!["ui".to_string(), udid.to_string(), "appearance".to_string(), appearance.raw_value().to_string()])
            .await?;
        Ok(())
    }

    async fn set_status_bar(&self, udid: Uuid, overrides: &StatusBarOverrides) -> Result<(), SimctlError> {
        if overrides.is_empty() {
            return Err(SimctlError::UnsupportedOperation { reason: "no status bar overrides provided".to_string() });
        }
        let mut args = vec!["status_bar".to_string(), udid.to_string(), "override".to_string()];
        args.extend(overrides.simctl_arguments());
        self.run_simctl(args).await?;
        Ok(())
    }

    async fn clear_status_bar(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["status_bar".to_string(), udid.to_string(), "clear".to_string()]).await?;
        Ok(())
    }

    async fn set_locale(&self, udid: Uuid, bcp47: &str) -> Result<(), SimctlError> {
        let apple_locale = bcp47.replace('-', "_");
        // Run sequentially, not concurrently: if AppleLocale fails after
        // AppleLanguages already succeeded, the error must say so explicitly
        // so the caller knows the simulator is left with a half-applied,
        // inconsistent locale/language pairing rather than a clean failure.
        self.run_simctl(vec![
            "spawn".to_string(),
            udid.to_string(),
            "defaults".to_string(),
            "write".to_string(),
            "-g".to_string(),
            "AppleLanguages".to_string(),
            "-array".to_string(),
            bcp47.to_string(),
        ])
        .await
        .map_err(|err| SimctlError::UnsupportedOperation {
            reason: format!("failed to set AppleLanguages (AppleLocale not attempted): {err}"),
        })?;
        self.run_simctl(vec![
            "spawn".to_string(),
            udid.to_string(),
            "defaults".to_string(),
            "write".to_string(),
            "-g".to_string(),
            "AppleLocale".to_string(),
            "-string".to_string(),
            apple_locale,
        ])
        .await
        .map_err(|err| SimctlError::UnsupportedOperation {
            reason: format!("AppleLanguages was set, but AppleLocale failed, leaving an inconsistent locale: {err}"),
        })?;
        Ok(())
    }

    async fn list_available_targets(&self) -> Result<AvailableTargets, SimctlError> {
        let stdout = self
            .run_simctl(vec!["list".to_string(), "--json".to_string(), "devicetypes".to_string(), "runtimes".to_string()])
            .await?;
        device_list::decode_available_targets(&stdout).map_err(|err| SimctlError::DecodingFailed { underlying: Box::new(err) })
    }

    async fn list_apps(&self, udid: Uuid) -> Result<Vec<InstalledApp>, SimctlError> {
        let plist = self.run_simctl(vec!["listapps".to_string(), udid.to_string()]).await?;
        let json = self.plist_to_json(plist).await?;
        app_list::decode(&json).map_err(|err| SimctlError::DecodingFailed { underlying: Box::new(err) })
    }

    async fn create(&self, name: &str, device_type_identifier: &str, runtime_identifier: &str) -> Result<Uuid, SimctlError> {
        let stdout = self
            .run_simctl(vec![
                "create".to_string(),
                name.to_string(),
                device_type_identifier.to_string(),
                runtime_identifier.to_string(),
            ])
            .await?;
        let trimmed = String::from_utf8_lossy(&stdout).trim().to_string();
        Uuid::parse_str(&trimmed)
            .map_err(|_| SimctlError::UnsupportedOperation { reason: format!("create returned unexpected output: {trimmed}") })
    }

    async fn erase(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["erase".to_string(), udid.to_string()]).await?;
        Ok(())
    }

    async fn delete(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["delete".to_string(), udid.to_string()]).await?;
        Ok(())
    }

    async fn delete_unavailable(&self) -> Result<(), SimctlError> {
        self.run_simctl(vec!["delete".to_string(), "unavailable".to_string()]).await?;
        Ok(())
    }

    async fn set_location(&self, udid: Uuid, latitude: f64, longitude: f64) -> Result<(), SimctlError> {
        self.run_simctl(vec!["location".to_string(), udid.to_string(), "set".to_string(), format!("{latitude},{longitude}")])
            .await?;
        Ok(())
    }

    async fn clear_location(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["location".to_string(), udid.to_string(), "clear".to_string()]).await?;
        Ok(())
    }

    async fn privacy(
        &self,
        udid: Uuid,
        action: PrivacyAction,
        permission: PrivacyPermission,
        bundle_id: Option<&str>,
    ) -> Result<(), SimctlError> {
        let mut args =
            vec!["privacy".to_string(), udid.to_string(), action.raw_value().to_string(), permission.raw_value().to_string()];
        if let Some(bundle_id) = bundle_id {
            args.push(bundle_id.to_string());
        }
        self.run_simctl(args).await?;
        Ok(())
    }

    async fn reset_keychain(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_simctl(vec!["keychain".to_string(), udid.to_string(), "reset".to_string()]).await?;
        Ok(())
    }

    async fn open_url(&self, udid: Uuid, url: &str) -> Result<(), SimctlError> {
        self.run_simctl(vec!["openurl".to_string(), udid.to_string(), url.to_string()]).await?;
        Ok(())
    }

    async fn launch_app(
        &self,
        udid: Uuid,
        bundle_id: &str,
        language: Option<&str>,
        region: Option<&str>,
    ) -> Result<(), SimctlError> {
        let mut args =
            vec!["launch".to_string(), "--terminate-running-process".to_string(), udid.to_string(), bundle_id.to_string()];
        if let Some(language) = language {
            args.push("-AppleLanguages".to_string());
            args.push(format!("({language})"));
        }
        match (language, region) {
            (_, Some(region)) => {
                // An explicit region always wins over whatever region the
                // language tag implies. Without an explicit language, fall
                // back to the simulator's own current language so we don't
                // silently force English on a device already set up
                // otherwise.
                let language_subtag = match language {
                    Some(language) => language.split(['-', '_']).next().unwrap_or(language).to_string(),
                    None => self.current_language_subtag(udid).await,
                };
                args.push("-AppleLocale".to_string());
                args.push(format!("{language_subtag}_{region}"));
            }
            (Some(language), None) => {
                // No region override: locale mirrors the language tag's own
                // region, same as before this override existed.
                args.push("-AppleLocale".to_string());
                args.push(language.replace('-', "_"));
            }
            (None, None) => {}
        }
        self.run_simctl(args).await?;
        Ok(())
    }

    async fn focus_simulator_app(&self, udid: Uuid) -> Result<(), SimctlError> {
        self.run_process(
            "/usr/bin/open",
            "open",
            vec![
                "-a".to_string(),
                "Simulator".to_string(),
                "--args".to_string(),
                "-CurrentDeviceUDID".to_string(),
                udid.to_string(),
            ],
        )
        .await?;
        Ok(())
    }
}

impl<R: ProcessRunning> LiveSimctlClient<R> {
    /// `simctl listapps` emits an OpenStep/ASCII property list, which no
    /// pure-Rust crate parses (the `plist` crate reads XML/binary only).
    /// Piping through `plutil -convert json -o - -` avoids hand-writing an
    /// ASCII-plist parser.
    async fn plist_to_json(&self, plist: Vec<u8>) -> Result<Vec<u8>, SimctlError> {
        use tokio::io::AsyncWriteExt;
        let mut child = tokio::process::Command::new("/usr/bin/plutil")
            .args(["-convert", "json", "-o", "-", "-"])
            .stdin(std::process::Stdio::piped())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn()
            .map_err(SimctlError::Io)?;
        child.stdin.take().expect("piped stdin").write_all(&plist).await.map_err(SimctlError::Io)?;
        let output = child.wait_with_output().await.map_err(SimctlError::Io)?;
        if !output.status.success() {
            return Err(SimctlError::CommandFailed {
                command: "plutil -convert json -o - -".to_string(),
                exit_code: output.status.code().unwrap_or(-1),
                stderr: String::from_utf8_lossy(&output.stderr).into_owned(),
            });
        }
        Ok(output.stdout)
    }

    /// Best-effort read of the simulator's current primary language, used
    /// only to pick a language subtag for a region-only launch override.
    /// Never fails the launch: an unset default (a fresh simulator exits
    /// non-zero here) or any other read/parse hiccup falls back to `en`
    /// rather than surfacing an error for what is just a locale-tag default.
    async fn current_language_subtag(&self, udid: Uuid) -> String {
        let Ok(stdout) = self
            .run_simctl(vec![
                "spawn".to_string(),
                udid.to_string(),
                "defaults".to_string(),
                "read".to_string(),
                "-g".to_string(),
                "AppleLanguages".to_string(),
            ])
            .await
        else {
            return "en".to_string();
        };
        parse_first_language_subtag(&stdout).unwrap_or_else(|| "en".to_string())
    }
}

/// `defaults read -g AppleLanguages` prints an old-style plist array
/// fragment, e.g. `(\n    "pt-BR",\n    en\n)`. Pulls out the first entry's
/// language subtag (the part before `-`/`_`), tolerating both the quoted
/// (`"pt-BR"`) and bare (`en`) forms `defaults` uses depending on whether the
/// tag contains characters needing quotes.
fn parse_first_language_subtag(stdout: &[u8]) -> Option<String> {
    let text = String::from_utf8_lossy(stdout);
    let inner = text.split_once('(')?.1.split_once(')')?.0;
    let first = inner.split(',').next()?.trim().trim_matches('"');
    if first.is_empty() {
        return None;
    }
    Some(first.split(['-', '_']).next().unwrap_or(first).to_string())
}
