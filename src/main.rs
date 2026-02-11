// sentiric-sip-uac/src/main.rs

use std::env;
use tokio::sync::mpsc;
use tracing::{info, warn, error, Level};
use sentiric_sip_uac_core::{UacClient, UacEvent};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 1. Logger Kurulumu (Terminale güzel çıktılar için)
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .init();

    // 2. CLI Argümanlarını Oku
    let args: Vec<String> = env::args().collect();
    
    // Varsayılan değerler
    let target_ip = args.get(1).map(|s| s.as_str()).unwrap_or("127.0.0.1").to_string();
    let target_port: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5060);
    let to_user = args.get(3).map(|s| s.as_str()).unwrap_or("9999").to_string();
    let from_user = args.get(4).map(|s| s.as_str()).unwrap_or("cli-tester").to_string();

    info!("--- 🚀 SENTIRIC SIP CLI SHELL v1.3.0 ---");
    info!("🎯 Target: {}:{}", target_ip, target_port);
    info!("📞 From: {} -> To: {}", from_user, to_user);

    // 3. Olay Kanalı Oluştur (Core -> Shell iletişimi için)
    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);

    // 4. Core Client'ı Başlat
    let client = UacClient::new(tx);

    // 5. Olay Dinleyici (Event Listener) - Ayrı bir task olarak çalışır
    let event_handler = tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                UacEvent::Log(msg) => info!("[CORE] {}", msg),
                UacEvent::Status(msg) => info!("🔔 STATUS: {}", msg),
                UacEvent::Error(err) => error!("❌ ERROR: {}", err),
                UacEvent::CallEnded => {
                    info!("🏁 Call sequence finished.");
                    break;
                }
            }
        }
    });

    // 6. Aramayı Başlat
    // Not: start_call kendi içinde loop barındırdığı için burası bekleyecektir (blocking).
    if let Err(e) = client.start_call(target_ip, target_port, to_user, from_user).await {
        error!("🔥 Critical Failure: {}", e);
    }

    // Task'ın temizlenmesini bekle
    let _ = event_handler.await;

    Ok(())
}