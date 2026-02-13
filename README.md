# 📞 Sentiric SIP UAC (CLI)

Sentiric platformunu test etmek için geliştirilmiş, komut satırı tabanlı, **Stateful** bir SIP istemcisidir.

Gücünü `sentiric-telecom-client-sdk` motorundan alır.

## 🚀 Özellikler

*   **RFC 3261 Uyumu:** `INVITE`, `200 OK`, `ACK`, `BYE` akışını tam yönetir.
*   **Auto-ACK:** Sunucudan `200 OK` geldiğinde otomatik olarak `ACK` gönderir.
*   **RTP Latching:** SDP içindeki IP/Port bilgisini analiz eder ve medyayı doğru hedefe kilitler.
*   **Retransmission:** UDP paket kayıplarına karşı tekrar gönderim (Timer A) yapar.
*   **Derinlemesine Loglama:** Giden ve gelen tüm SIP paketlerini konsola basar.

## 🛠️ Kurulum ve Derleme

```bash
# Release modunda derle (Performans için)
cargo build --release
```

## 💻 Kullanım

Aracı çalıştırmak için hedef IP adresi zorunludur. Diğer parametreler opsiyoneldir.

```bash
# Temel Kullanım (Varsayılan: Port 5060, Hedef: service, Kaynak: cli-uac)
./target/release/sentiric-sip-uac <HEDEF_IP>

# Tam Kullanım
./target/release/sentiric-sip-uac <HEDEF_IP> <PORT> <ARANAN_NO> <ARAYAN_NO>
```

### Örnekler

**1. SBC'ye Doğrudan Arama (Echo Test):**
```bash
# 9999 numarası genellikle Echo Testidir.
cargo run --release -- 34.122.40.122 5060 9999 my-tester
```

**2. B2BUA Üzerinden Arama:**
```bash
cargo run --release -- 10.0.0.5 5060 1001 admin
```

## 🔍 Beklenen Çıktı

Başarılı bir testte şunları görmelisiniz:

1.  `📤 OUTGOING INVITE`: Oluşturulan SIP paketi.
2.  `📥 INCOMING PACKET`: Sunucudan gelen `100 Trying` ve `180 Ringing`.
3.  `🔔 CALL STATE: Connected`: `200 OK` alındı.
4.  `--> AUTO-ACK Sent`: El sıkışma tamamlandı.
5.  `⌨️ [DTMF]`: (Eğer tuşlama yaparsanız)

---
