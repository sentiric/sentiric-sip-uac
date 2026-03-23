.PHONY: setup generate sync-sdk build-android run-android deploy-device clean-android clean-linux clean-all build-linux run-linux

# ==============================================================================
# SENTIRIC SIP UAC - ORCHESTRATION MAKEFILE (v3.0 - Multi-Platform)
# ==============================================================================

# 1. İlk kurulum (SDK'lar ve araçlar için)
setup:
	@echo "--- 🛠️ Gerekli araçlar kuruluyor... ---"
	flutter pub get
	cargo install flutter_rust_bridge_codegen --version 2.11.1
	cargo install cargo-ndk

# 2. SDK Senkronizasyonu (KRİTİK ADIM)
sync-sdk:
	@echo "--- 🔄 Telecom SDK Senkronize Ediliyor (Cargo Update)... ---"
	cd rust && cargo update -p sentiric-telecom-client-sdk
	@echo "✅ SDK Güncellendi."

# 3. Köprü Kodlarını Üret (Sadece Generate!)
generate:
	@echo "--- 🌉 Rust/Dart köprü kodları üretiliyor... ---"
	flutter_rust_bridge_codegen generate
	
# 4. Android için Derleme
build-android:
	@echo "--- 🦀 Rust çekirdeği Android için derleniyor... ---"
	cd rust && cargo ndk -t arm64-v8a -t armeabi-v7a -o ../android/app/src/main/jniLibs build --release
	
	@echo "🔍 C++ Shared Library aranıyor ve kopyalanıyor..."
	@mkdir -p android/app/src/main/jniLibs/arm64-v8a
	@find $$(echo $$ANDROID_HOME)/ndk -name "libc++_shared.so" | grep "aarch64" | head -n 1 | xargs -I {} cp {} android/app/src/main/jniLibs/arm64-v8a/
	@echo "✅ ARM64 libc++_shared.so kopyalandı."
	@mkdir -p android/app/src/main/jniLibs/armeabi-v7a
	@find $$(echo $$ANDROID_HOME)/ndk -name "libc++_shared.so" | grep "arm-linux-androideabi" | head -n 1 | xargs -I {} cp {} android/app/src/main/jniLibs/armeabi-v7a/
	@echo "✅ ARMv7 libc++_shared.so kopyalandı."

# 5. Linux için Derleme
build-linux:
	@echo "--- 🐧 Linux Desktop için derleniyor... ---"
	# Önce Rust kütüphanemizi Linux için derleyelim
	cd rust && cargo build --release
	# Sonra Flutter'ı derleyelim
	flutter build linux --release
	# Derlenen libuac.so dosyasını, uygulamanın çalışacağı lib/ klasörüne kopyalayalım
	@mkdir -p build/linux/x64/release/bundle/lib/
	@cp rust/target/release/libuac.so build/linux/x64/release/bundle/lib/

# 6. Temizlik Hedefleri
clean-android:
	@echo "--- 🧹 Android artıkları temizleniyor... ---"
	rm -rf android/app/src/main/jniLibs/*

clean-linux:
	@echo "--- 🧹 Linux artıkları temizleniyor... ---"
	rm -rf build/linux

clean-all: clean-android clean-linux
	@echo "--- 🧹 Tüm Flutter & Rust önbelleği temizleniyor... ---"
	flutter clean
	rm -rf rust/target

# 7. Cihazlara Yükleme ve Çalıştırma (Debug)
run-android: clean-android sync-sdk generate build-android
	@echo "--- 🚀 Android'de Çalıştırılıyor (Debug)... ---"
	flutter run -d android

run-linux: clean-linux sync-sdk generate
	@echo "--- 🦀 Rust çekirdeği Linux (Debug) için derleniyor... ---"
	cd rust && cargo build
	@echo "--- 🚀 Linux Desktop'ta Çalıştırılıyor (Debug)... ---"
	# Flutter run komutu çalışmadan hemen önce kütüphaneyi yerleştiriyoruz
	# Flutter'ın aradığı varsayılan yer LD_LIBRARY_PATH veya mevcut çalışma dizinidir
	# Biz çalıştırılabilir dosyanın yanına (veya sistemin bulabileceği bir yere) koyacağız
	@mkdir -p build/linux/x64/debug/bundle/lib/
	@cp rust/target/debug/libuac.so build/linux/x64/debug/bundle/lib/ 2>/dev/null || true
	# LD_LIBRARY_PATH ile kütüphanenin yerini belirterek Flutter'ı başlatıyoruz
	LD_LIBRARY_PATH=$$(pwd)/rust/target/debug:$$LD_LIBRARY_PATH flutter run -d linux

# 8. Üretim (Release) Dağıtımı
deploy-device: clean-android sync-sdk generate build-android
	@echo "--- 🚀 Android'e Yükleniyor (Release)... ---"
	flutter run --release -d android