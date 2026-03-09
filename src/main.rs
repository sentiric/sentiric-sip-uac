// sentiric-sip-uac/src/main.rs

use clap::Parser;
use std::process;
use tokio::sync::mpsc;
use std::time::Duration;
use tracing::{info, warn, error, Level};
use sentiric_telecom_client_sdk::{TelecomClient, UacEvent, CallState};

mod scenario;
use scenario::{load_scenario, ActionDef};

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Target IP Address (e.g., 34.122.40.122). Required if --scenario is not used.
    #[arg(index = 1)]
    target_ip: Option<String>,

    /// SIP Port
    #[arg(short, long, default_value_t = 5060)]
    port: u16,

    /// Destination User (Callee)
    #[arg(short, long, default_value = "service")]
    to: String,

    /// Source User (Caller)
    #[arg(short, long, default_value = "cli-uac")]
    from: String,

    /// Enable Headless Mode (Virtual DSP for Docker/CI)
    #[arg(long, default_value_t = false)]
    headless: bool,

    /// Enable Debug Logs (Show RMS levels and internal states)
    #[arg(long, default_value_t = false)]
    debug: bool,

    /// Load execution plan from a JSON scenario file
    #[arg(short, long)]
    scenario: Option<String>,
}

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let args = Args::parse();

    // Senaryo mu yoksa manuel IP mi?
    if args.target_ip.is_none() && args.scenario.is_none() {
        eprintln!("🛑 HATA: Lütfen bir hedef IP (TARGET_IP) veya bir senaryo dosyası (--scenario) belirtin.");
        process::exit(1);
    }

    let log_level = if args.debug { Level::DEBUG } else { Level::INFO };
    tracing_subscriber::fmt().with_max_level(log_level).without_time().init();

    // 1. KULLANIM MODUNU BELİRLE VE PARAMETRELERİ AYARLA
    let (target_ip, port, to, from, headless, actions) = if let Some(scenario_path) = args.scenario {
        info!("📂 Senaryo dosyası yükleniyor: {}", scenario_path);
        let sc = load_scenario(&scenario_path)?;
        info!("🤖 AKTİF SENARYO: {}", sc.name);
        (sc.target_ip, sc.port, sc.to, sc.from, sc.headless, Some(sc.actions))
    } else {
        (args.target_ip.unwrap(), args.port, args.to, args.from, args.headless, None)
    };

    info!("==================================================");
    info!("🤖 SENTIRIC AUTONOMOUS TEST BOT v2.5");
    info!("==================================================");
    info!("🎯 Target   : {}:{}", target_ip, port);
    info!("📞 Call     : {} -> {}", from, to);
    info!("👻 Headless : {}", headless);
    info!("--------------------------------------------------");

    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);

    info!("⚙️  Initializing Telecom Engine...");
    let client = TelecomClient::new(tx, headless);

    // 2. EVENT DİNLEYİCİ (Arka plan log ve state takibi)
    let event_handler = tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                UacEvent::Log(msg) => {
                    if !msg.contains("[SIP_PACKET") { info!("🔹 {}", msg); } 
                    else { tracing::debug!("{}", msg); }
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
                UacEvent::MediaActive => {
                    info!("🎙️  MEDIA ACTIVE: 2-Way Audio Flow Established!");
                }
                UacEvent::RtpStats { rx_cnt, tx_cnt } => {
                     if rx_cnt % 100 == 0 || tx_cnt % 100 == 0 {
                         info!("📊 RTP Stats: RX={} | TX={}", rx_cnt, tx_cnt);
                     }
                }
            }
        }
    });

    info!("🚀 Arama Başlatılıyor...");
    if let Err(e) = client.start_call(target_ip.clone(), port, to.clone(), from.clone()).await {
        error!("🔥 Arama başlatılamadı: {}", e);
        process::exit(1);
    }

    // 3. OTONOM SENARYO İŞLETİMİ VEYA MANUEL BEKLEME
    if let Some(actions) = actions {
        for action in actions {
            match action {
                ActionDef::Wait { ms } => {
                    info!("⏳ Senaryo: {}ms bekleniyor...", ms);
                    tokio::time::sleep(Duration::from_millis(ms)).await;
                },
                ActionDef::Dtmf { key } => {
                    info!("🎹 Senaryo: '{}' tuşuna basılıyor...", key);
                    let _ = client.send_dtmf(key).await;
                },
                ActionDef::Hangup => {
                    info!("🛑 Senaryo: Çağrı sonlandırılıyor (Hangup)...");
                    let _ = client.end_call().await;
                    tokio::time::sleep(Duration::from_millis(500)).await;
                    break;
                }
            }
        }
    } else {
        // Senaryo yoksa, kullanıcı manuel olarak Ctrl+C yapana kadar bekle
        tokio::select! {
            _ = tokio::signal::ctrl_c() => {
                warn!("🛑 User interrupted. Sending BYE...");
                let _ = client.end_call().await;
                tokio::time::sleep(Duration::from_millis(500)).await;
            }
            _ = event_handler => {}
        }
    }

    Ok(())
}