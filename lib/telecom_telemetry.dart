// lib/telecom_telemetry.dart

enum TelemetryLevel { info, status, error, sipTx, sipRx, media }

class TelemetryEntry {
  final String message;
  final TelemetryLevel level;
  
  final int? rxCount;
  final int? txCount;

  TelemetryEntry({
    required this.message,
    this.level = TelemetryLevel.info,
    this.rxCount,
    this.txCount,
  });
}

class TelecomTelemetry {
  static TelemetryEntry parse(String raw) {
    
    if (raw.contains("MediaActive")) {
      return TelemetryEntry(message: "🎙️ SECURE RTP CHANNEL ESTABLISHED", level: TelemetryLevel.status);
    }

    if (raw.contains("RtpStats")) {
      final rxMatch = RegExp(r"rx_cnt:\s*(\d+)").firstMatch(raw);
      final txMatch = RegExp(r"tx_cnt:\s*(\d+)").firstMatch(raw);
      return TelemetryEntry(
        message: "Stats Update", 
        level: TelemetryLevel.media,
        rxCount: int.tryParse(rxMatch?.group(1) ?? "0"),
        txCount: int.tryParse(txMatch?.group(1) ?? "0"),
      );
    }

    if (raw.contains("CallStateChanged")) {
      final state = raw.split('(').last.split(')').first;
      return TelemetryEntry(message: "🔔 SYSTEM STATE: $state", level: TelemetryLevel.status);
    }

    if (raw.contains("Error") || raw.contains("Fail")) {
      String clean = raw.replaceAll("Error(", "").replaceAll(")", "").replaceAll("\"", "");
      return TelemetryEntry(message: "❌ SYSTEM HALT: $clean", level: TelemetryLevel.error);
    }

    // [YENİ]: Trafik Okları İçin Renklendirme
    if (raw.contains("Log(")) {
      String content = raw;
      int start = raw.indexOf("Log(\"");
      if (start != -1) {
        content = raw.substring(start + 5, raw.lastIndexOf("\""));
      }
      content = content.replaceAll("\\n", "\n").replaceAll("\\r", "").replaceAll("\\\"", "\"");

      TelemetryLevel lvl = TelemetryLevel.info;
      if (content.startsWith("⬇️")) lvl = TelemetryLevel.sipRx;
      else if (content.startsWith("⬆️")) lvl = TelemetryLevel.sipTx;

      return TelemetryEntry(message: content, level: lvl);
    }

    return TelemetryEntry(message: raw);
  }
}