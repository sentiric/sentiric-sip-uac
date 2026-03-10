# Sentiric SIP UAC - Test ve Doğrulama Rehberi

Bu belge, Sentiric altyapısının (SBC, Proxy, B2BUA, Media) sınırlarını zorlamak ve çökme durumlarını (Edge Cases) tespit etmek için UAC botunun nasıl kullanılacağını tanımlar.

---

## 1. Otonom Dayanıklılık Testi (Resilience Suite)

Sistemi manuel test etmek yerine, JSON tabanlı senaryo motorunu kullanan otomatik test setini çalıştırın.

### Nasıl Çalıştırılır?
Hedef olarak **Platformun Dışa Açık IP'sini (SBC)** vermeniz zorunludur.

```bash
cd sentiric-sip-uac
chmod +x scripts/resilience_suite.sh

# Gerçek testi başlat (Kendi public IP'nizi yazın)
./scripts/resilience_suite.sh 34.122.40.122
```

### Test Vektörleri ve Beklenen Sonuçlar

Test seti şu 4 kritik senaryoyu sırayla işletir:

#### Vektör 1: Immediate Hangup (Race Condition Test)
*   **Ne Yapar:** Arama başlatır (INVITE atar) ve 50ms içinde, sunucu daha doğru düzgün işlemi bağlamadan CANCEL/BYE atar.
*   **Neyi Test Eder:** B2BUA ve Media servislerinin bu iptal sinyalini düzgün yakalayıp yakalamadığı.
*   **Başarı Kriteri:** Sunucu tarafında Orchestrator loglarında (veya Media Service loglarında) asılı/unutulmuş bir RTP portu bırakılmamalı, `Panic` veya çökme olmamalıdır.

#### Vektör 2: Rapid DTMF (State Machine Stress)
*   **Ne Yapar:** 100ms aralıklarla çok hızlı şekilde in-band DTMF paketleri (Payload 101) fırlatır.
*   **Neyi Test Eder:** Media Service'in Pacer (zamanlayıcı) ve Decoder motorunun kısa süreli kesintilerde (interrupt) kilitlenip kilitlenmediği.
*   **Başarı Kriteri:** Ses akışı (RTP) kopmamalı, DTMF'ler yoksayılsa bile motor çalışmaya devam etmelidir.

#### Vektör 3: Ghost Call (Inactivity Timeout)
*   **Ne Yapar:** Arama açılır ve bot 45 saniye boyunca hiçbir RTP paketi göndermeden sessiz kalır (Sadece bekler).
*   **Neyi Test Eder:** Media Service'in "Dead Call" (Ölü Çağrı) yakalama yeteneği.
*   **Başarı Kriteri:** Kullanıcı (UAC) kapatmamasına rağmen, Media Service yaklaşık 30. saniyede trafiğin durduğunu anlayıp `RTP_TIMEOUT` hatası fırlatmalı ve çağrıyı **kendi kendine** sonlandırmalıdır.

#### Vektör 4: Long Call (Memory Leak & Jitter Test)
*   **Ne Yapar:** 60 saniye boyunca (uzatılabilir) sürekli paket gönderir.
*   **Neyi Test Eder:** RAM tüketiminin stabil kalıp kalmadığı (Memory Leak) ve Jitter Buffer'ın kaymaları onarıp onaramadığı.
*   **Başarı Kriteri:** Oynatma bitiminde ses dosyası başarıyla S3/Disk'e kaydedilmiş olmalı ve Orchestrator UI üzerinde Media Service'in RAM tüketiminde devasa bir artış grafiği izlenmemelidir.

---

## 2. Sorun Giderme (Troubleshooting)

Eğer test sırasında UAC terminalinde `Connection Timeout!` görüyorsanız:
1.  Verdiğiniz IP adresi yanlıştır (Platform orada dinlemiyor olabilir).
2.  Platformun SBC/Edge güvenlik duvarı (Firewall) 5060 UDP portuna izin vermiyordur.
3.  Altyapı çalışmıyordur (`make status` ile kontrol edin).

---
