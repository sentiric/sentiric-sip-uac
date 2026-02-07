// sentiric-sip-uac/src/main.rs
mod client;

use client::Client;
use std::env;
use tracing::{info, Level};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    let args: Vec<String> = env::args().collect();
    
    // Parametreler: [target_ip] [target_port] [to_user] [from_user]
    let target_ip = args.get(1).map(|s| s.as_str()).unwrap_or("127.0.0.1");
    let target_port: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5060);
    let to_user = args.get(3).map(|s| s.as_str()).unwrap_or("9999");
    let from_user = args.get(4).map(|s| s.as_str()).unwrap_or("905548777858");

    info!("--- 🚀 SENTIRIC SIP UAC v1.15.0 TESTER ---");
    info!("🎯 Target: {}:{}", target_ip, target_port);
    info!("📞 From: {} -> To: {}", from_user, to_user);

    let client = Client::new(target_ip, target_port).await?;
    client.start_call(to_user, from_user).await?;

    Ok(())
}