// sentiric-sip-mobile-uac/rust/src/api/simple.rs

use sentiric_telecom_client_sdk::{TelecomClient, UacEvent, CallState};
use crate::frb_generated::StreamSink;
use log::{info, LevelFilter};
use android_logger::Config;
use tokio::sync::mpsc;

/// Uygulama ilk açıldığında Rust loglarını Android sistemine bağlar.
pub fn init_logger() {
    android_logger::init_once(
        Config::default()
            .with_max_level(LevelFilter::Info)
            .with_tag("SENTIRIC-MOBILE"),
    );
    info!("✅ Mobile Logger Initialized via SDK v2.0");
}

/// SIP çağrısını başlatır ve olayları Flutter UI'a anlık olarak stream eder.
pub async fn start_sip_call(
    target_ip: String,
    target_port: u16,
    to_user: String,
    from_user: String,
    sink: StreamSink<String>, 
) -> anyhow::Result<()> {
    
    // 1. Loglama (Başlangıç)
    info!("🚀 Mobile Dialing: {} -> {}:{}", from_user, target_ip, target_port);
    let _ = sink.add(format!("Log(\"🚀 Starting Engine for {}:{}...\")", target_ip, target_port));

    // 2. Kanal Kurulumu (SDK -> Flutter Bridge)
    let (tx, mut rx) = mpsc::channel::<UacEvent>(100);
    
    // 3. SDK Motorunu Başlat
    // [KRİTİK GÜNCELLEME]: Headless = false (Mobil cihazda donanım var)
    let client = TelecomClient::new(tx, false);

    // 4. Olay Dinleme Döngüsü (Event Loop)
    let stream_sink = sink.clone(); 

    tokio::spawn(async move {
        while let Some(event) = rx.recv().await {
            // Rust Enum -> Debug String dönüşümü (Örn: CallStateChanged(Connected))
            let msg = format!("{:?}", event);
            
            // Android Logcat'e bas
            info!("[SDK-EVENT] {}", msg);
            
            // Flutter UI'a gönder (Klonlanmış sink üzerinden)
            if stream_sink.add(msg).is_err() {
                info!("⚠️ Flutter stream closed, stopping listener.");
                break;
            }

            // Eğer çağrı bittiyse loop'u sonlandırabiliriz.
            if let UacEvent::CallStateChanged(CallState::Terminated) = event {
                // Opsiyonel: Stream'i kapatmak için break;
            }
        }
    });

    // 5. Çağrıyı Başlat (Asenkron)
    // Hata olursa hemen yakalayıp Flutter'a bildiriyoruz.
    if let Err(e) = client.start_call(target_ip, target_port, to_user, from_user).await {
        let err_msg = format!("Error(\"Init Failed: {}\")", e);
        info!("❌ {}", err_msg);
        let _ = sink.add(err_msg);
        return Err(e);
    }
    
    Ok(())
}