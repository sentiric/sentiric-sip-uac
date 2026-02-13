// sentiric-sip-uac/src/main.rs

use std::env;
use tokio::sync::mpsc;
use tracing::{info, error, Level};
// YENİ SDK İMPORTLARI
use sentiric_telecom_client_sdk::{TelecomClient, UacEvent, CallState};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 1. Logger Kurulumu
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

    info!("--- 🚀 SENTIRIC SIP CLI SHELL v2.0 (SDK Integration) ---");
    info!("🎯 Target: {}:{}", target_ip, target_port);
    info!("📞 From: {} -> To: {}", from_user, to_user);

    // 3. Olay Kanalı Oluştur (SDK -> Shell)
    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);

    // 4. Yeni SDK Client'ı Başlat (TelecomClient)
    let client = TelecomClient::new(tx);

    // 5. Olay Dinleyici (Event Listener)
    let event_handler = tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                UacEvent::Log(msg) => info!("[SDK] {}", msg),
                UacEvent::CallStateChanged(state) => {
                    info!("🔔 STATUS CHANGED: {:?}", state);
                    if state == CallState::Terminated {
                        info!("🏁 Call sequence finished.");
                        // Normalde burada break yapabiliriz ama logları kaçırmamak için biraz bekleyebiliriz.
                        // Şimdilik CLI mantığı gereği terminated olunca çıkıyoruz.
                        std::process::exit(0); 
                    }
                },
                UacEvent::Error(err) => error!("❌ ERROR: {}", err),
            }
        }
    });

    // 6. Aramayı Başlat
    if let Err(e) = client.start_call(target_ip, target_port, to_user, from_user).await {
        error!("🔥 Critical Failure: {}", e);
        std::process::exit(1);
    }

    // CLI'ı açık tutmak için sonsuz döngü veya sinyal bekleme
    // SDK arka planda çalıştığı için main thread'i bloklamamız lazım.
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            info!("🛑 Stopping call...");
            let _ = client.end_call().await;
        }
        _ = event_handler => {
            info!("Event handler exited.");
        }
    }

    Ok(())
}