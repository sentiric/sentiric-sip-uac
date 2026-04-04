// Dosya: rust/build.rs
fn main() {
    // İşletim sistemini tespit et
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();

    // Yalnızca Android için C++ shared library bağlamasını yap
    if target_os == "android" {
        println!("cargo:rustc-link-lib=c++_shared");
    }
}
