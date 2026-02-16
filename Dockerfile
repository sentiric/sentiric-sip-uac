# --- STAGE 1: Builder ---
FROM rust:1.93-slim-bookworm AS builder

# Gerekli derleme araçları
# [FIX]: protobuf-compiler eklendi (SDK bağımlılıkları için)
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    clang \
    protobuf-compiler \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/sentiric
COPY . .

WORKDIR /usr/src/sentiric/sentiric-sip-uac

# Build (Release)
RUN cargo build --release

# --- STAGE 2: Runtime ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /usr/src/sentiric/sentiric-sip-uac/target/release/sentiric-sip-uac /usr/local/bin/sentiric-sip-uac

ENTRYPOINT ["sentiric-sip-uac"]