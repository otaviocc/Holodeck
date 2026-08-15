//! Pins the exact argv `LiveSimctlClient` shells out to for every operation —
//! the Rust analogue of the Swift suite's `SimctlClientTests`, and the best
//! available spec for this layer per the port plan.

use std::sync::{Arc, Mutex};

use async_trait::async_trait;
use holodeck_core::models::{Appearance, PrivacyAction, PrivacyPermission, ScreenshotType, StatusBarOverrides};
use holodeck_core::{LiveSimctlClient, ProcessResult, ProcessRunning, SimctlClient};
use uuid::Uuid;

type Call = (String, Vec<String>);

#[derive(Default, Clone)]
struct SharedStub {
    calls: Arc<Mutex<Vec<Call>>>,
}

#[async_trait]
impl ProcessRunning for SharedStub {
    async fn run(&self, launch_path: &str, arguments: &[String]) -> std::io::Result<ProcessResult> {
        self.calls.lock().unwrap().push((launch_path.to_string(), arguments.to_vec()));
        Ok(ProcessResult {
            stdout: Vec::new(),
            stderr: Vec::new(),
            exit_code: 0,
        })
    }
}

async fn run<F, Fut>(f: F) -> Vec<Call>
where
    F: FnOnce(Arc<LiveSimctlClient<SharedStub>>) -> Fut,
    Fut: std::future::Future<Output = ()>,
{
    let stub = SharedStub::default();
    let calls = stub.calls.clone();
    let client = Arc::new(LiveSimctlClient::with_runner(stub));
    f(client).await;
    calls.lock().unwrap().clone()
}

#[tokio::test]
async fn boot_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.boot(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec!["simctl".to_string(), "boot".to_string(), udid.to_string()]
        )]
    );
}

#[tokio::test]
async fn shutdown_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.shutdown(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec!["simctl".to_string(), "shutdown".to_string(), udid.to_string()]
        )]
    );
}

#[tokio::test]
async fn list_devices_available_only_argv() {
    let calls = run(|client| async move {
        // Stdout is empty, so decoding fails after the call — we only assert
        // the argv the client shelled out with.
        let _ = client.list_devices(false).await;
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "list".to_string(),
                "--json".to_string(),
                "devices".to_string(),
                "available".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn list_devices_include_unavailable_argv() {
    let calls = run(|client| async move {
        let _ = client.list_devices(true).await;
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "list".to_string(),
                "--json".to_string(),
                "devices".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn list_available_targets_argv() {
    let calls = run(|client| async move {
        let _ = client.list_available_targets().await;
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "list".to_string(),
                "--json".to_string(),
                "devicetypes".to_string(),
                "runtimes".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn screenshot_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client
            .screenshot(udid, std::path::Path::new("/tmp/out.png"), ScreenshotType::Png)
            .await
            .unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "io".to_string(),
                udid.to_string(),
                "screenshot".to_string(),
                "--type".to_string(),
                "png".to_string(),
                "/tmp/out.png".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn set_appearance_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.set_appearance(udid, Appearance::Dark).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "ui".to_string(),
                udid.to_string(),
                "appearance".to_string(),
                "dark".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn set_status_bar_rejects_empty_overrides_without_shelling_out() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        let result = client.set_status_bar(udid, &StatusBarOverrides::default()).await;
        assert!(result.is_err());
    })
    .await;
    assert!(calls.is_empty());
}

#[tokio::test]
async fn set_status_bar_argv() {
    let udid = Uuid::new_v4();
    let overrides = StatusBarOverrides {
        battery_level: Some(100),
        ..Default::default()
    };
    let calls = run(|client| async move {
        client.set_status_bar(udid, &overrides).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "status_bar".to_string(),
                udid.to_string(),
                "override".to_string(),
                "--batteryLevel".to_string(),
                "100".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn clear_status_bar_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.clear_status_bar(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "status_bar".to_string(),
                udid.to_string(),
                "clear".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn set_locale_fires_two_concurrent_spawns_rewriting_dash_to_underscore() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.set_locale(udid, "pt-BR").await.unwrap();
    })
    .await;
    assert_eq!(calls.len(), 2);
    assert!(
        calls
            .iter()
            .any(|(_, args)| args.contains(&"AppleLanguages".to_string()) && args.contains(&"pt-BR".to_string()))
    );
    assert!(
        calls
            .iter()
            .any(|(_, args)| args.contains(&"AppleLocale".to_string()) && args.contains(&"pt_BR".to_string()))
    );
}

#[tokio::test]
async fn create_argv_and_parses_uuid_from_trimmed_stdout() {
    #[derive(Clone)]
    struct FixedStdoutRunner(Uuid);
    #[async_trait]
    impl ProcessRunning for FixedStdoutRunner {
        async fn run(&self, _launch_path: &str, _arguments: &[String]) -> std::io::Result<ProcessResult> {
            Ok(ProcessResult {
                stdout: format!("  {}\n", self.0).into_bytes(),
                stderr: Vec::new(),
                exit_code: 0,
            })
        }
    }
    let created = Uuid::new_v4();
    let client = LiveSimctlClient::with_runner(FixedStdoutRunner(created));
    let result = client.create("Demo", "iPhone-17-Pro", "iOS-18-0").await.unwrap();
    assert_eq!(result, created);
}

#[tokio::test]
async fn create_errors_on_unparseable_stdout() {
    let calls = run(|client| async move {
        let result = client.create("Demo", "iPhone-17-Pro", "iOS-18-0").await;
        assert!(result.is_err());
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "create".to_string(),
                "Demo".to_string(),
                "iPhone-17-Pro".to_string(),
                "iOS-18-0".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn erase_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.erase(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec!["simctl".to_string(), "erase".to_string(), udid.to_string()]
        )]
    );
}

#[tokio::test]
async fn delete_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.delete(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec!["simctl".to_string(), "delete".to_string(), udid.to_string()]
        )]
    );
}

#[tokio::test]
async fn delete_unavailable_argv() {
    let calls = run(|client| async move {
        client.delete_unavailable().await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec!["simctl".to_string(), "delete".to_string(), "unavailable".to_string()]
        )]
    );
}

#[tokio::test]
async fn set_location_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.set_location(udid, 37.7749, -122.4194).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "location".to_string(),
                udid.to_string(),
                "set".to_string(),
                "37.7749,-122.4194".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn clear_location_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.clear_location(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "location".to_string(),
                udid.to_string(),
                "clear".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn privacy_omits_bundle_id_when_none() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client
            .privacy(udid, PrivacyAction::Reset, PrivacyPermission::All, None)
            .await
            .unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "privacy".to_string(),
                udid.to_string(),
                "reset".to_string(),
                "all".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn privacy_appends_bundle_id_when_present() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client
            .privacy(udid, PrivacyAction::Grant, PrivacyPermission::Photos, Some("com.example.App"))
            .await
            .unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "privacy".to_string(),
                udid.to_string(),
                "grant".to_string(),
                "photos".to_string(),
                "com.example.App".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn reset_keychain_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.reset_keychain(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "keychain".to_string(),
                udid.to_string(),
                "reset".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn open_url_argv() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.open_url(udid, "https://apple.com").await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/xcrun".to_string(),
            vec![
                "simctl".to_string(),
                "openurl".to_string(),
                udid.to_string(),
                "https://apple.com".to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn focus_simulator_app_shells_to_open_not_xcrun() {
    let udid = Uuid::new_v4();
    let calls = run(|client| async move {
        client.focus_simulator_app(udid).await.unwrap();
    })
    .await;
    assert_eq!(
        calls,
        vec![(
            "/usr/bin/open".to_string(),
            vec![
                "-a".to_string(),
                "Simulator".to_string(),
                "--args".to_string(),
                "-CurrentDeviceUDID".to_string(),
                udid.to_string()
            ]
        )]
    );
}

#[tokio::test]
async fn command_failure_surfaces_trimmed_stderr() {
    struct FailingRunner;
    #[async_trait]
    impl ProcessRunning for FailingRunner {
        async fn run(&self, _launch_path: &str, _arguments: &[String]) -> std::io::Result<ProcessResult> {
            Ok(ProcessResult {
                stdout: Vec::new(),
                stderr: b"  boom  \n".to_vec(),
                exit_code: 1,
            })
        }
    }
    let client = LiveSimctlClient::with_runner(FailingRunner);
    let err = client.boot(Uuid::new_v4()).await.unwrap_err();
    assert_eq!(err.to_string(), "boom");
}
