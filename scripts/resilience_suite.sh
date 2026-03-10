#!/bin/bash
# ==============================================================================
# SENTIRIC SIP UAC - RESILIENCE TEST SUITE
# Sistemin dayanıklılığını uç senaryolarla test eder.
# ==============================================================================

set -e

TARGET_IP=${1:-"127.0.0.1"}
UAC_BIN="./target/release/sentiric-sip-uac"

echo "🛡️ SENTIRIC RESILIENCE TEST SUITE BAŞLATILIYOR..."
echo "🎯 Hedef: $TARGET_IP"
echo "------------------------------------------------"

# Binary kontrolü
if [ ! -f "$UAC_BIN" ]; then
    echo "⚠️ Binary bulunamadı. Derleniyor..."
    cargo build --release
fi

run_scenario() {
    local scenario_file=$1
    echo -e "\n▶️ ÇALIŞTIRILIYOR: $scenario_file"
    # UAC'yi çalıştır, hataları yakala ama scripti durdurma
    $UAC_BIN $TARGET_IP --scenario $scenario_file --debug || echo "⚠️ UAC Exited with error (Expected in some stress tests)"
    echo "✅ TAMAMLANDI: $scenario_file"
    echo "⏳ Sistem toparlanması için 3 saniye bekleniyor..."
    sleep 3
}

# Senaryoları sırayla çalıştır
run_scenario "scenarios/01_immediate_hangup.json"
run_scenario "scenarios/02_rapid_dtmf.json"
run_scenario "scenarios/04_ghost_call.json"

echo -e "\n🔥 UZUN SÜRELİ STRES TESTİ BAŞLIYOR (1 Dakika)..."
echo "👉 LÜTFEN ORCHESTRATOR'DAN MEDIA-SERVICE RAM TÜKETİMİNİ İZLEYİNİZ."
run_scenario "scenarios/03_long_call.json"

echo -e "\n🎉 TÜM DAYANIKLILIK TESTLERİ TAMAMLANDI."