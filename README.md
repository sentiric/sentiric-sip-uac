# Sentiric SIP UAC (User Agent Client)

Sentiric SIP Sunucularını (UAS) test etmek, yük testi uygulamak ve doğrulama yapmak için geliştirilmiş **Test İstemcisidir**.

Bir operatör (Softswitch) veya IP Telefon gibi davranarak sunucuya çağrı başlatır.

## 🎯 Amaç

*   **Doğrulama:** Sunucunun `INVITE`, `200 OK` ve `ACK` döngüsünü (3-Way Handshake) doğru tamamladığını test eder.
*   **Ses Testi:** Sunucunun gönderdiği RTP paketlerini karşılar ve kendisi de RTP gönderir.
*   **Operatör Simülasyonu:** Gerçek bir operatöre bağlanmadan önce yerel ağda (Localhost) geliştirme yapmayı sağlar.

## 🚀 Kullanım

Test edilecek sunucunun IP adresini parametre olarak verin.

```bash
# Localhost testi
cargo run --release -- 127.0.0.1

# Uzak sunucu testi
cargo run --release -- 192.168.1.100
```

## 📋 Test Senaryosu

Bu araç çalıştığında sırasıyla şunları yapar:
1.  **INVITE:** Hedef sunucuya çağrı başlatır (G.729/PCMA SDP ile).
2.  **Wait:** `100 Trying` ve `180 Ringing` (varsa) mesajlarını karşılar.
3.  **200 OK:** Sunucu cevap verdiğinde SDP'yi analiz eder.
4.  **ACK:** El sıkışmayı tamamlar.
5.  **RTP:** Belirlenen port üzerinden ses akışını (Dummy Stream) başlatır.

## 🔧 Teknik Detaylar

*   **Port:** 6060 (Çakışmayı önlemek için 5060 kullanmaz).
*   **User-Agent:** `Sentiric UAC Tester`
*   **Bağımlılıklar:** `sip-core` ve `rtp-core`.
