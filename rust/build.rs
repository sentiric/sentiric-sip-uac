// Dosya: rust/build.rs
use std::env;
use std::fs;
use std::path::Path;

fn main() {
    // İşletim sistemini tespit et
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();

    // Yalnızca Android için C++ shared library bağlamasını yap
    if target_os == "android" {
        println!("cargo:rustc-link-lib=c++_shared");
    }

    // [ARCH-COMPLIANCE] Dinamik Versiyon Okuma (Cargo.lock parse)
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap_or_default();
    let lock_path = Path::new(&manifest_dir).join("Cargo.lock");

    if let Ok(lock_content) = fs::read_to_string(lock_path) {
        println!("cargo:rustc-env=SDK_VERSION={}", extract_version(&lock_content, "sentiric-telecom-client-sdk"));
        println!("cargo:rustc-env=SIP_CORE_VERSION={}", extract_version(&lock_content, "sentiric-sip-core"));
        println!("cargo:rustc-env=RTP_CORE_VERSION={}", extract_version(&lock_content, "sentiric-rtp-core"));
    } else {
        println!("cargo:rustc-env=SDK_VERSION=Unknown");
        println!("cargo:rustc-env=SIP_CORE_VERSION=Unknown");
        println!("cargo:rustc-env=RTP_CORE_VERSION=Unknown");
    }

    // Cargo.lock değiştiğinde build.rs yeniden çalışsın
    println!("cargo:rerun-if-changed=Cargo.lock");
}

// Cargo.lock içinden belirtilen paketin tam versiyonunu ayıklayan yardımcı fonksiyon
fn extract_version(lock_content: &str, pkg_name: &str) -> String {
    let mut in_pkg = false;
    for line in lock_content.lines() {
        let line = line.trim();
        if line == "[[package]]" {
            in_pkg = false;
        } else if line.starts_with("name") && line.contains(pkg_name) {
            in_pkg = true;
        } else if in_pkg && line.starts_with("version") {
            if let Some(ver) = line.split('"').nth(1) {
                return ver.to_string();
            }
        }
    }
    "Unknown".to_string()
}