#!/bin/bash
# ==============================================================================
# SENTIRIC SIP UAC - RESILIENCE & CHAOS TEST SUITE v2.0
# Sistemin dayanıklılığını uç senaryolarla test eder ve Bug'ları ispatlar.
# ==============================================================================

set -e

TARGET_IP=${1}
UAC_BIN="./target/release/sentiric-sip-uac"

if [ -z "$TARGET_IP" ]; then
    echo "🛑 HATA: Lütfen hedef sunucu IP'sini girin."
    echo "Kullanım: ./scripts/resilience_suite.sh <TARGET_IP>"
    exit 1
fi

echo "🛡️ SENTIRIC CHAOS TEST SUITE BAŞLATILIYOR..."
echo "🎯 Hedef: $TARGET_IP"
echo "------------------------------------------------"

if [ ! -f "$UAC_BIN" ]; then
    echo "⚠️ Binary bulunamadı. Derleniyor..."
    cargo build --release
fi

# ------------------------------------------------------------------
# TEST 1: THE ZOMBIE MAKER (Aç-Kapa Race Condition Testi)
# ------------------------------------------------------------------
echo -e "\n🔥 VEKTÖR 1: ZOMBIE MAKER (Hızlı Aç-Kapa Sızdırma Testi)"
echo "Bu test arka arkaya 15 kez yarım çağrı başlatıp aniden kesecek."
echo "Eğer B2BUA/Media Service port sızdırıyorsa, birazdan sistem kilitlenecek."

for i in {1..15}
do
   echo -n "   💀 Saldırı $i/15... "
   # Çıktıyı gizle, sadece çalıştır (hızlı olması için)
   $UAC_BIN $TARGET_IP --scenario scenarios/01_immediate_hangup.json > /dev/null 2>&1 || true
   echo "Tamam."
   sleep 0.5
done
echo "✅ Zombie Maker Bitti."
sleep 3

# ------------------------------------------------------------------
# TEST 2: HEALTH CHECK (Sistem Yaşıyor Mu?)
# ------------------------------------------------------------------
echo -e "\n🩺 VEKTÖR 2: SAĞLIK KONTROLÜ (Sistem Kilitlendi mi?)"
echo "Şimdi normal, uslu bir çağrı yapıyoruz..."

# 5 saniyelik temiz bir bekleme ve kapatma senaryosu yaratalım geçici olarak
cat <<EOF > scenarios/temp_health_check.json
{
  "name": "Health Check Call",
  "target_ip": "127.0.0.1",
  "port": 5060,
  "to": "9999",
  "from": "health-bot",
  "headless": true,
  "actions": [ { "type": "wait", "ms": 5000 }, { "type": "hangup" } ]
}
EOF

# Çıktıyı grep ile yakalayalım
if $UAC_BIN $TARGET_IP --scenario scenarios/temp_health_check.json | grep -q "MEDIA ACTIVE"; then
    echo "🟢 SİSTEM SAĞLIKLI: Zombie Maker sistemi kilitlenemedi! (Media Service port sızdırmıyor)."
else
    echo "🔴 SİSTEM ÇÖKTÜ VEYA KİLİTLENDİ!"
    echo "Zombie Maker başarılı oldu. Media Service portları tükendi veya B2BUA state leak yaşadı."
    echo "Lütfen Observer/Panopticon üzerinden 'PortPoolExhausted' veya 'RTP_TIMEOUT' hatalarını arayın."
fi
rm scenarios/temp_health_check.json
sleep 3

# ------------------------------------------------------------------
# TEST 3: RAPID DTMF STRESS
# ------------------------------------------------------------------
echo -e "\n🎹 VEKTÖR 3: RAPID DTMF SPAM"
$UAC_BIN $TARGET_IP --scenario scenarios/02_rapid_dtmf.json > /dev/null 2>&1 || echo "⚠️ UAC DTMF sırasında uyarı verdi."
echo "✅ DTMF Spam Tamamlandı."
sleep 3

# ------------------------------------------------------------------
# TEST 4: INACTIVITY TIMEOUT (Ghost Call)
# ------------------------------------------------------------------
echo -e "\n👻 VEKTÖR 4: GHOST CALL (Sessiz Çağrı)"
echo "Bu test 45 saniye sürecek. Sunucunun 30. saniyede bizi zorla atması (Timeout) bekleniyor."
$UAC_BIN $TARGET_IP --scenario scenarios/04_ghost_call.json > /dev/null 2>&1 || true
echo "✅ Ghost Call Tamamlandı."

echo -e "\n🎉 CHAOS TEST SETİ TAMAMLANDI."