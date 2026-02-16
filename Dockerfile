# --- STAGE 1: Builder ---
# Rust 1.93 (Latest Stable) - Edition 2024 desteği için
FROM rust:1.93-slim-bookworm AS builder

# [FIX]: Sistem bağımlılıkları güncellendi.
# - pkg-config: Kütüphane yollarını bulmak için şart.
# - libasound2-dev: ALSA (Ses) geliştirme başlıkları (SDK v2.0 gereksinimi).
# - protobuf-compiler: gRPC için.
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    clang \
    protobuf-compiler \
    pkg-config \
    libasound2-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/sentiric
COPY . .

WORKDIR /usr/src/sentiric/sentiric-sip-uac

# Build (Release)
RUN cargo build --release

# --- STAGE 2: Runtime ---
FROM debian:bookworm-slim

# [FIX]: Runtime için gerekli kütüphaneler.
# - libasound2: Derlenmiş binary'nin çalışırken ses sistemine erişmesi için.
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libasound2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /usr/src/sentiric/sentiric-sip-uac/target/release/sentiric-sip-uac /usr/local/bin/sentiric-sip-uac

ENTRYPOINT ["sentiric-sip-uac"]