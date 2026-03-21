// rust/src/api/simple.rs

use sentiric_telecom_client_sdk::{UacEvent, CallState, ClientCommand}; 
use crate::frb_generated::StreamSink;
use log::{info, LevelFilter};
use android_logger::Config;
use tokio::sync::mpsc;
use std::sync::Mutex;
use lazy_static::lazy_static;

// Flutter'dan her an "Durdur" komutu gönderebilmek için Global Sender.
lazy_static! {
    static ref CMD_TX: Mutex<Option<mpsc::Sender<ClientCommand>>> = Mutex::new(None);
}

#[cfg(target_os = "android")]
#[no_mangle]
pub extern "system" fn JNI_OnLoad(vm: jni::JavaVM, _res: *mut std::ffi::c_void) -> jni::sys::jint {
    let vm = vm.get_java_vm_pointer() as *mut std::ffi::c_void;
    unsafe {
        ndk_context::initialize_android_context(vm, std::ptr::null_mut());
    }
    jni::sys::JNI_VERSION_1_6
}

pub fn init_logger() {
    // [MİMARİ DÜZELTME]: Kodek Şizofrenisini Engelleyen Kilit.
    // Asterisk ve diğer sistemlerle %100 uyumluluk için PCMU zorunlu kılındı.
    std::env::set_var("PREFERRED_AUDIO_CODEC", "PCMU");

    android_logger::init_once(
        Config::default()
            .with_max_level(LevelFilter::Info)
            .with_tag("SENTIRIC-MOBILE"),
    );
    log::info!("✅ Logger Initialized via SDK v2.0 with STRICT PCMU codec.");
}

/// Çağrıyı aniden kesmek için Flutter tarafından çağrılır.
pub async fn end_sip_call() -> anyhow::Result<()> {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        info!("🛑 Flutter UI requested call termination. Sending BYE...");
        let _ = tx.send(ClientCommand::EndCall).await;
    } else {
        info!("⚠️ No active call to terminate.");
    }
    Ok(())
}

pub async fn start_sip_call(
    target_ip: String,
    target_port: u16,
    to_user: String,
    from_user: String,
    sink: StreamSink<String>, 
) -> anyhow::Result<()> {
    
    info!("🚀 Dialing: {} -> {}:{}", from_user, target_ip, target_port);
    let _ = sink.add(format!("Log(\"🚀 Starting Engine for {}:{}...\")", target_ip, target_port));

    let (event_tx, mut event_rx) = mpsc::channel::<UacEvent>(100);
    let (cmd_tx, cmd_rx) = mpsc::channel::<ClientCommand>(32);
    
    // Global referansı güncelle (Dışarıdan kapatabilmek için)
    *CMD_TX.lock().unwrap() = Some(cmd_tx.clone());

    // Motoru manuel başlatıyoruz (TelecomClient::new yerine Engine'i direkt kurarak komut kanalını kontrol edeceğiz)
    tokio::spawn(async move {
        let mut engine = sentiric_telecom_client_sdk::engine::SipEngine::new(event_tx, cmd_rx, false).await;
        engine.run().await;
    });

    let stream_sink = sink.clone(); 

    tokio::spawn(async move {
        while let Some(event) = event_rx.recv().await {
            let msg = format!("{:?}", event);
            info!("[SDK-EVENT] {}", msg);
            
            if stream_sink.add(msg).is_err() {
                break;
            }

            if let UacEvent::CallStateChanged(CallState::Terminated) = event {
                // Çağrı bittiğinde global kanalı temizle
                *CMD_TX.lock().unwrap() = None;
                break;
            }
        }
    });

    // Başlatma Komutunu Gönder
    if cmd_tx.send(ClientCommand::StartCall { target_ip, target_port, to_user, from_user }).await.is_err() {
        let err_msg = "Error(\"Init Failed: Engine unreachable\")".to_string();
        info!("❌ {}", err_msg);
        let _ = sink.add(err_msg);
        return Err(anyhow::anyhow!("Engine unreachable"));
    }
    
    Ok(())
}

pub async fn update_audio_settings(mic_gain: f32, speaker_gain: f32, enable_aec: bool) {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx.send(ClientCommand::UpdateSettings {
            mic_gain,
            speaker_gain,
            enable_aec,
        }).await;
    }
}

/// Aktif çağrıya in-band RTP DTMF tonu gönderir.
pub async fn send_sip_dtmf(key: String) {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        if let Some(c) = key.chars().next() {
            let _ = tx.send(ClientCommand::SendDtmf { key: c }).await;
            log::info!("🎹 UI Requested DTMF: {}", c);
        }
    } else {
        log::warn!("⚠️ No active call to send DTMF.");
    }
}

// YENİ: UI'dan gelen Mute komutunu SDK'ya ileten köprü fonksiyonu
pub async fn set_mute(muted: bool) {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx.send(ClientCommand::SetMute { muted }).await;
        log::info!("🎤 UI Requested MUTE state: {}", muted);
    } else {
        log::warn!("⚠️ No active call to mute.");
    }
}