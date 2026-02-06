// sentiric-sip-uac/src/main.rs
mod client;

use client::Client;
use std::env;
use tracing::{info, Level};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // Loglama ayarı
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    let args: Vec<String> = env::args().collect();
    let target_ip = args.get(1).map(|s| s.as_str()).unwrap_or("127.0.0.1");
    let target_port: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5060);
    let to_user = args.get(3).map(|s| s.as_str()).unwrap_or("902124548590");

    info!("--- 🚀 SENTIRIC SIP UAC PRECISION TESTER ---");
    info!("🎯 Hedef: {}:{}", target_ip, target_port);
    info!("📞 Aranan: {}", to_user);

    let client = Client::new(target_ip, target_port).await?;
    client.start_call(to_user).await?;

    Ok(())
}