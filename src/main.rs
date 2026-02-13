// sentiric-sip-uac/src/main.rs

use std::env;
use std::process;
use tokio::sync::mpsc;
use tracing::{info, warn, error, Level};
// SDK Importları
use sentiric_telecom_client_sdk::{TelecomClient, UacEvent, CallState};

fn print_usage(program_name: &str) {
    println!("Usage: {} <TARGET_IP> [TARGET_PORT] [TO_USER] [FROM_USER]", program_name);
    println!("Example:");
    println!("  {} 34.122.40.122 5060 9999 cli-tester", program_name);
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    // 1. Logger Kurulumu
    tracing_subscriber::fmt()
        .with_max_level(Level::INFO)
        .without_time() // CLI'da daha temiz görünüm için zamanı gizle (Zaten SDK loglarında olabilir)
        .init();

    // 2. Argüman Ayrıştırma (Hardcode Önleme)
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        error!("❌ Missing arguments.");
        print_usage(&args[0]);
        process::exit(1);
    }

    let target_ip = args[1].clone();
    let target_port: u16 = args.get(2).and_then(|s| s.parse().ok()).unwrap_or(5060);
    let to_user = args.get(3).cloned().unwrap_or_else(|| "service".to_string());
    let from_user = args.get(4).cloned().unwrap_or_else(|| "cli-uac".to_string());

    info!("==========================================");
    info!("🚀 SENTIRIC SIP UAC v2.0 (Active)");
    info!("==========================================");
    info!("🎯 Target : {}:{}", target_ip, target_port);
    info!("📞 Call   : {} -> {}", from_user, to_user);
    info!("------------------------------------------");

    // 3. Kanal Kurulumu (SDK -> CLI)
    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);

    // 4. SDK Motorunu Başlat
    info!("⚙️  Initializing Telecom Engine...");
    let client = TelecomClient::new(tx);

    // 5. Olay Dinleyici (Background Task)
    let event_handler = tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                // SDK'dan gelen detaylı loglar (SIP Paketleri dahil)
                UacEvent::Log(msg) => {
                    println!("{}", msg); // Tracing yerine direkt stdout'a bas (Log kirliliğini önlemek için)
                }
                // Çağrı Durum Değişiklikleri
                UacEvent::CallStateChanged(state) => {
                    info!("🔔 CALL STATE: {:?}", state);
                    if state == CallState::Terminated {
                        info!("🏁 Call Terminated. Exiting...");
                        process::exit(0);
                    }
                }
                // Kritik Hatalar
                UacEvent::Error(err) => {
                    error!("❌ SDK ERROR: {}", err);
                    process::exit(1);
                }
            }
        }
    });

    // 6. Aramayı Başlat
    info!("🚀 Dialing...");
    if let Err(e) = client.start_call(target_ip, target_port, to_user, from_user).await {
        error!("🔥 Failed to start call: {}", e);
        process::exit(1);
    }

    // 7. Kapanış Sinyali Bekleme (Ctrl+C)
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            warn!("🛑 User interrupted. Sending BYE...");
            let _ = client.end_call().await;
            // BYE gönderimi için kısa bir süre bekle
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        }
        _ = event_handler => {
            // Event loop biterse çık
        }
    }

    Ok(())
}