// rust/build.rs
fn main() {
    // Derleyiciye libc++_shared kütüphanesine dinamik olarak bağlanmak istediğimizi söyler
    println!("cargo:rustc-link-lib=c++_shared");
}