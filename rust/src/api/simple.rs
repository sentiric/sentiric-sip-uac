// Dosya: sentiric-sip-uac/rust/src/api/simple.rs

// SUTS v4.0 (JSON Loglama) kuralı Backend Mikroservisleri (Agent, Workflow, B2BUA vb.) için zorunludur. Ancak UAC bir Edge Client (Mobil Uygulama) olduğu için bu kuraldan muaftır. Mobil geliştirmede standart logcat düz metni (plain text) esastır.

// Android ekosisteminde, yerel (native) logların adb logcat'e düşebilmesi için Rust tarafında kullandığımız android_logger kütüphanesi SADECE standart log kütüphanesini dinler. Biz araya SUTS v4.0 standartlarını uydurmak için tracing kütüphanesini soktuğumuzda, android_logger bunu anlayamadı ve tüm loglar sessizce uzay boşluğuna (void) atıldı. Uygulamanın çalışmasında bir sorun yok, arka planda çağrı atıyor ama ekrana ve terminale hiçbir şey yazdırmıyor.

// [ARCH-COMPLIANCE] Mobil cihazlar için 'tracing' yerine standart 'log' kütüphanesine dönüldü.
use crate::frb_generated::StreamSink;
use lazy_static::lazy_static;
use log::info;
use sentiric_telecom_client_sdk::{ClientCommand, UacEvent};
use std::sync::Mutex;
use tokio::sync::mpsc;

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

#[cfg(target_os = "android")]
pub fn init_logger() {
    std::env::set_var("PREFERRED_AUDIO_CODEC", "PCMA"); // PCMU -> PCMA olarak değiştirildi
    android_logger::init_once(
        android_logger::Config::default()
            .with_max_level(log::LevelFilter::Info)
            .with_tag("SENTIRIC-MOBILE"),
    );
    log::info!("✅ Android Logger Initialized via SDK");
}

#[cfg(not(target_os = "android"))]
pub fn init_logger() {
    std::env::set_var("PREFERRED_AUDIO_CODEC", "PCMA"); // PCMU -> PCMA olarak değiştirildi
    let _ = env_logger::builder()
        .filter_level(log::LevelFilter::Info)
        .try_init();
    log::info!("✅ Desktop/Linux Logger Initialized via SDK");
}

pub async fn start_engine(sink: StreamSink<String>) -> anyhow::Result<()> {
    let mut cmd_tx_guard = CMD_TX.lock().unwrap();
    if cmd_tx_guard.is_some() {
        return Ok(());
    }

    let (event_tx, mut event_rx) = mpsc::channel::<UacEvent>(100);
    let (cmd_tx, cmd_rx) = mpsc::channel::<ClientCommand>(32);

    *cmd_tx_guard = Some(cmd_tx);

    tokio::spawn(async move {
        let mut engine =
            sentiric_telecom_client_sdk::engine::SipEngine::new(event_tx, cmd_rx, false).await;
        engine.run().await;
    });

    let stream_sink = sink.clone();

    // [YENİ]: SDK ve Core versiyonlarını Debug Console'a bas
    let _ = stream_sink.add(format!(
        "Log(\"🚀 Booting Sentiric Engine (Native v{} | SDK v0.4.15 | SIP v1.5.6 | RTP v1.6.2)\")",
        env!("CARGO_PKG_VERSION")
    ));    

    tokio::spawn(async move {
        while let Some(event) = event_rx.recv().await {
            let msg = format!("{:?}", event);
            // Eski haline getirildi
            info!("[SDK-EVENT] {}", msg);
            let _ = stream_sink.add(msg);
        }
    });

    Ok(())
}

pub async fn register_sip_account(
    target_ip: String,
    target_port: u16,
    user: String,
    password: String,
) -> anyhow::Result<()> {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx
            .send(ClientCommand::Register {
                target_ip,
                target_port,
                user,
                password,
            })
            .await;
    }
    Ok(())
}

pub async fn start_sip_call(
    target_ip: String,
    target_port: u16,
    to_user: String,
    from_user: String,
) -> anyhow::Result<()> {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx
            .send(ClientCommand::StartCall {
                target_ip,
                target_port,
                to_user,
                from_user,
            })
            .await;
    }
    Ok(())
}

pub async fn accept_inbound_call() -> anyhow::Result<()> {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx.send(ClientCommand::AcceptCall).await;
    }
    Ok(())
}

pub async fn reject_inbound_call() -> anyhow::Result<()> {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx.send(ClientCommand::RejectCall).await;
    }
    Ok(())
}

pub async fn end_sip_call() -> anyhow::Result<()> {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx.send(ClientCommand::EndCall).await;
    }
    Ok(())
}

pub async fn update_audio_settings(mic_gain: f32, speaker_gain: f32, enable_aec: bool) {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx
            .send(ClientCommand::UpdateSettings {
                mic_gain,
                speaker_gain,
                enable_aec,
            })
            .await;
    }
}

pub async fn send_sip_dtmf(key: String) {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        if let Some(c) = key.chars().next() {
            let _ = tx.send(ClientCommand::SendDtmf { key: c }).await;
        }
    }
}

pub async fn set_mute(muted: bool) {
    let tx_opt = CMD_TX.lock().unwrap().clone();
    if let Some(tx) = tx_opt {
        let _ = tx.send(ClientCommand::SetMute { muted }).await;
    }
}
