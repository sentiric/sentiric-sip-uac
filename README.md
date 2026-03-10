# 📠 Sentiric SIP UAC (Autonomous Test Bot)

[![Status](https://img.shields.io/badge/status-active-success.svg)]()
[![Core](https://img.shields.io/badge/sdk-v0.3.39-orange.svg)]()
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)]()

**Sentiric SIP UAC**, sunucu tarafı SIP/RTP uygulamalarını (SBC, B2BUA, Media Server) stres, dayanıklılık ve mantık testlerine tabi tutmak için tasarlanmış, otonom bir komut satırı aracıdır.

JSON tabanlı **Senaryo Motoru** sayesinde, Race Condition (Yarış Durumu), Packet Flood, Timeout ve Memory Leak gibi kritik testleri otomatize eder.

## 🌟 Temel Özellikler

*   **Autonomous Scenario Engine:** JSON dosyalarından test adımlarını (`wait`, `dtmf`, `hangup`) okur ve insan müdahalesi olmadan çalıştırır.
*   **Virtual DSP (Headless Mode):** Ses kartı olmayan sunucularda (CI/CD, Docker) tam izolasyonla çalışır.
*   **Resilience Test Suite:** Hazır bash scriptleri ile sistemi uç senaryolarla (Edge Cases) döver.
*   **Telemetri:** Jitter analizi, milisaniye hassasiyetli state geçiş logları ve RTP paket sayacı.

## 🛠️ Kurulum

```bash
# Bağımlılıkları yükle (Debian/Ubuntu)
sudo apt install libasound2-dev protobuf-compiler

# Release modunda derle
cargo build --release
```

## 💻 Kullanım

### Parametreler

```text
Usage: sentiric-sip-uac [OPTIONS] [TARGET_IP]

Arguments:
  [TARGET_IP]  Hedef IP (Örn: 34.122.40.122). Senaryo modunda bile bu değer geçilirse, senaryodaki IP ezilir.

Options:
  -p, --port <PORT>      SIP Port [default: 5060]
  -t, --to <TO>          Destination User [default: service]
  -f, --from <FROM>      Source User [default: cli-uac]
      --headless         Enable Headless Mode (Virtual DSP)
      --debug            Enable Debug Logs (Shows SIP packets)
  -s, --scenario <FILE>  Test senaryosunu çalıştırır (JSON formatında)
  -h, --help             Print help
```

### 🛡️ Dayanıklılık Testini Başlatmak (Resilience Suite)

Sistemin kararlılığını test etmek için tüm zorlu senaryoları sırayla çalıştıran scripti kullanın. **DİKKAT: Gerçek SBC veya Proxy IP'nizi vermelisiniz!** `127.0.0.1` yazarsanız test sadece UAC'nin kendi timeout mekanizmasını test eder, sunucuyu test etmez.

```bash
# Örnek: GCP Edge SBC Sunucusuna stres testi yap
./scripts/resilience_suite.sh 34.122.40.122
```

Daha fazla detay için `docs/TESTING.md` dosyasına bakınız.

---
