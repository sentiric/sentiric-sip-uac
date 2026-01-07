FROM rust:1.79-slim-bookworm AS builder

RUN apt-get update && apt-get install -y build-essential cmake git clang && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src/sentiric
COPY . .

WORKDIR /usr/src/sentiric/sentiric-sip-uac
RUN cargo build --release

# --- Runtime ---
FROM debian:bookworm-slim
WORKDIR /app

COPY --from=builder /usr/src/sentiric/sentiric-sip-uac/target/release/sentiric-sip-uac /usr/local/bin/sentiric-sip-uac

# İstemci çalışınca direkt kapanmasın, komut beklesin diye sleep koyabiliriz
# Veya direkt çalıştırıp log basıp çıkabilir.
ENTRYPOINT ["sentiric-sip-uac"]