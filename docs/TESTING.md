#### A. Thread Pool Testi (Resource Leak Check)
Sunucuyu zorlayacağız ve thread sayısının patlamadığını göreceğiz.

1.  **Sunucuyu Başlat:** `cargo run --release`
2.  **Yük Testi Başlat (SIPp ile):**
    Eğer `sipp` yüklü değilse Docker ile çalıştır:
    ```bash
    # 10 saniye boyunca saniyede 100 çağrı (Total 1000)
    docker run --network host --rm snuffegull/sipp -sn uac -r 100 -rp 1000 -m 1000 -d 100 127.0.0.1:5060
    ```
3.  **İzleme (Başka bir terminalde):**
    ```bash
    # PID'i bul
    pgrep sentiric-sip-ua
    # Thread sayısını izle (NLWP kolonu thread sayısıdır)
    top -H -p $(pgrep sentiric-sip-ua)
    ```
    *Beklenen:* Thread sayısı sabit kalmalı (Örneğin `available_parallelism` 8 ise yaklaşık 32-35 civarı sabitlenmeli). Asla 1000'e çıkmamalı.

#### B. Timing & Jitter Testi
RTP paketlerinin zamanlamasının donanımsal saat (monotonic clock) ile ne kadar uyumlu olduğunu ölçeriz.

1.  **Capture Başlat:**
    ```bash
    sudo tcpdump -i any udp portrange 10000-20000 -w rtp_test.pcap
    ```
2.  **UAC ile Çağrı Yap:** Sistemi 30 saniye konuştur.
3.  **Analiz (Wireshark):**
    *   `rtp_test.pcap` dosyasını Wireshark ile aç.
    *   Menü: **Telephony -> RTP -> Stream Analysis**.
    *   **Max Delta:** 20ms civarında olmalı (Örn: 19.8ms - 20.2ms arası mükemmeldir).
    *   **Mean Jitter:** < 5ms olmalı. Eğer > 20ms ise ses "robotik" çıkar.

#### C. Symmetric RTP (NAT) Testi
Bu test için sunucu ve istemcinin **farklı makinelerde** (veya biri Docker içinde, biri hostta) olması gerekir.

1.  Sunucuyu başlat.
2.  UAC (İstemci) kodunda `local_port`'u değiştirip gönderdiği porttan farklı bir porttan dinlemesini simüle edebiliriz (veya gerçek bir softphone kullanabiliriz).
3.  Sunucu loglarında şu satırı görmelisin:
    > `🔄 Symmetric RTP Latch: Hedef güncellendi 192.168.1.X:PORT -> 192.168.1.X:YENI_PORT`
    Bu log çıkıyorsa, sunucu NAT arkasındaki cihazın gerçek portunu öğrenmiş ve oraya dönmüş demektir.

---
