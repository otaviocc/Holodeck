//! Manual smoke test against the real `xcrun simctl` on this machine —
//! not part of `cargo test` since it depends on real simulator state.
//! Run with: cargo run -p holodeck-core --example smoke

use holodeck_core::{LiveSimctlClient, SimctlClient};

#[tokio::main]
async fn main() {
    let client = LiveSimctlClient::new();

    println!("== list_devices(available=true) ==");
    let sims = client.list_devices(true).await.expect("list_devices failed");
    for sim in &sims {
        println!(
            "{} {} [{}] {}",
            sim.name,
            sim.runtime.display_name(),
            sim.state.raw_value(),
            sim.id
        );
    }

    println!("\n== list_available_targets ==");
    let targets = client.list_available_targets().await.expect("list_available_targets failed");
    println!(
        "{} device types, {} runtimes",
        targets.device_types.len(),
        targets.runtimes.len()
    );

    if let Some(booted) = sims.iter().find(|s| s.state.raw_value() == "Booted") {
        println!("\n== list_apps on booted {} ==", booted.name);
        match client.list_apps(booted.id).await {
            Ok(apps) => {
                println!("{} apps decoded via plutil-json bridge", apps.len());
                for app in apps.iter().take(5) {
                    println!("  {} ({}) user={}", app.name, app.bundle_id, app.is_user_app);
                }
            }
            Err(err) => println!("list_apps failed: {err}"),
        }
    } else {
        println!("\nno booted simulator — skipping list_apps");
    }
}
