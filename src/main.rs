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
        .without_time() 
        .init();

    // 2. Argüman Ayrıştırma
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
    info!("🚀 SENTIRIC SIP UAC v2.1 (Resilient)");
    info!("==========================================");
    info!("🎯 Target : {}:{}", target_ip, target_port);
    info!("📞 Call   : {} -> {}", from_user, to_user);
    info!("------------------------------------------");

    // 3. Kanal Kurulumu
    // _rx warning'ini engellemek için kullanıyoruz
    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);

    // 4. SDK Motorunu Başlat
    info!("⚙️  Initializing Telecom Engine...");
    let client = TelecomClient::new(tx);

    // 5. Olay Dinleyici
    let event_handler = tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                UacEvent::Log(msg) => {
                    println!("{}", msg); 
                }
                UacEvent::CallStateChanged(state) => {
                    info!("🔔 CALL STATE: {:?}", state);
                    if state == CallState::Terminated {
                        info!("🏁 Call Terminated. Exiting...");
                        process::exit(0);
                    }
                }
                UacEvent::Error(err) => {
                    error!("❌ SDK ERROR: {}", err);
                    process::exit(1);
                }
                // [FIX]: Eksik kollar eklendi
                UacEvent::MediaActive => {
                    info!("🎙️  MEDIA ACTIVE: 2-Way Audio Established!");
                }
                UacEvent::RtpStats { rx_cnt, tx_cnt } => {
                     // İstatistikleri çok sık basmamak için debug seviyesinde tutabiliriz
                     // veya belirli aralıklarla basabiliriz.
                     if rx_cnt % 50 == 0 {
                         info!("📊 RTP Stats: RX={} TX={}", rx_cnt, tx_cnt);
                     }
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

    // 7. Kapanış Sinyali Bekleme
    tokio::select! {
        _ = tokio::signal::ctrl_c() => {
            warn!("🛑 User interrupted. Sending BYE...");
            let _ = client.end_call().await;
            tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;
        }
        _ = event_handler => {}
    }

    Ok(())
}