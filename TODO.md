# 🗺️ Sentiric Sip UAC - Yol Haritası

## 🟢 Faz 1: MVP & Stabilite (TAMAMLANDI v1.1.0)
- [x] SIP Kayıt ve Arama Başlatma/Sonlandırma.
- [x] RTP Ses Akışı (G.711 PCMU).
- [x] Android `AudioManager` entegrasyonu (VoIP Modu).
- [x] Self-Healing Audio (Kopma koruması).
- [x] Digital Gain (Ses seviyesi iyileştirmesi).

## 🟡 Faz 2: Ses Kalitesi & DSP (Backlog)
Bu faz, uygulamanın son kullanıcı ürününe (Consumer Product) dönüştürülmesi durumunda gereklidir.
- [ ] **Yankı Engelleyici (AEC):** Rust tarafına `WebRTC APM` veya `SpeexDSP` entegrasyonu.
- [ ] **Gürültü Bastırma (NS):** Arka plan gürültüsü için AI destekli veya algoritmik filtreleme.
- [ ] **Adaptive Jitter Buffer:** Ağ dalgalanmalarına karşı dinamik tampon yönetimi.

## 🔴 Faz 3: İleri Özellikler (Future)
- [ ] **DTMF Klavye:** IVR sistemleri için tuşlama desteği.
- [ ] **Push Notifications:** Uygulama kapalıyken arama alma (FCM).
- [ ] **Call History:** Arama kayıtlarının yerel veritabanında (SQLite/Drift) saklanması.
- [ ] **Codec Seçimi:** OPUS ve G.722 desteği.


---
