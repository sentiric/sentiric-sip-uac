import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentiric_sip_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_uac/telecom_telemetry.dart';

class CallController extends ChangeNotifier {
  static const platform = MethodChannel('ai.sentiric.sentiric_sip_uac/audio_route');

  // Input Controllers
  final TextEditingController ipController = TextEditingController();
  final TextEditingController portController = TextEditingController();
  final TextEditingController toController = TextEditingController();
  final TextEditingController fromController = TextEditingController();

  // Telemetry & UI State
  final List<TelemetryEntry> telemetryLogs = [];
  final ScrollController scrollController = ScrollController();
  
  bool isCalling = false;
  bool isMediaFlowing = false;
  bool showDebugConsole = false;
  bool isSpeakerOn = false;
  bool isMuted = false;
  
  int rxPackets = 0;
  int txPackets = 0;
  int callDurationSeconds = 0;
  String sipStatus = "STANDBY";
  
  Timer? _durationTimer;

  CallController() {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    ipController.text = prefs.getString('targetIp') ?? "";
    portController.text = prefs.getString('targetPort') ?? "";
    toController.text = prefs.getString('toUser') ?? "";
    fromController.text = prefs.getString('fromUser') ?? "";
    notifyListeners();
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetIp', ipController.text.trim());
    await prefs.setString('targetPort', portController.text.trim());
    await prefs.setString('toUser', toController.text.trim());
    await prefs.setString('fromUser', fromController.text.trim());
  }

  void toggleDebugConsole() {
    showDebugConsole = !showDebugConsole;
    notifyListeners();
    _scrollToBottom();
  }

  Future<void> toggleSpeaker() async {
    isSpeakerOn = !isSpeakerOn;
    notifyListeners();
    try {
      await platform.invokeMethod('toggleSpeaker', {'speakerOn': isSpeakerOn});
    } catch (e) {
      debugPrint("Speaker Toggle Error: $e");
    }
  }

void toggleMute() {
    isMuted = !isMuted;
    
    // [YENİ]: Rust (SDK) motoruna Mute komutunu gönderiyoruz
    setMute(muted: isMuted); 
    
    notifyListeners();
  }

  void sendDtmf(String key) {
    sendSipDtmf(key: key);
    _processEvent("Log(\"🎹 Sent DTMF: $key\")");
  }

  void _startDurationTimer() {
    callDurationSeconds = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      callDurationSeconds++;
      notifyListeners();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
  }

  String get formattedDuration {
    final minutes = (callDurationSeconds / 60).floor();
    final seconds = callDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _processEvent(String raw) {
    final entry = TelecomTelemetry.parse(raw);

    if (entry.level == TelemetryLevel.media && entry.rxCount != null) {
      rxPackets = entry.rxCount!;
      txPackets = entry.txCount!;
      if (rxPackets > 5) isMediaFlowing = true;
    } 
    else if (entry.message.contains("SYSTEM STATE:")) {
      sipStatus = entry.message.split(':').last.trim().toUpperCase();
      
      if (sipStatus == "CONNECTED") {
        _startDurationTimer();
      } else if (sipStatus == "TERMINATED" || sipStatus == "IDLE") {
        isCalling = false;
        isMediaFlowing = false;
        _stopDurationTimer();
        platform.invokeMethod('setNormalMode').catchError((_) {});
      }
      _addLog(entry);
    } else {
      _addLog(entry);
    }
    notifyListeners();
  }

  void _addLog(TelemetryEntry entry) {
    telemetryLogs.add(entry);
    _scrollToBottom();
  }

  void _scrollToBottom() {
    if (showDebugConsole && scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent + 50,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> toggleCall() async {
    if (isCalling) {
      await endSipCall();
      isCalling = false;
      isMediaFlowing = false;
      sipStatus = "TERMINATING...";
      _stopDurationTimer();
      platform.invokeMethod('setNormalMode').catchError((_) {});
      notifyListeners();
      return;
    }

    await saveProfile();

    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      isSpeakerOn = false;
      try {
        await platform.invokeMethod('setInCallMode');
      } catch (e) {
        debugPrint("InCall Mode Error: $e");
      }

      telemetryLogs.clear();
      isCalling = true;
      isMediaFlowing = false;
      rxPackets = 0;
      txPackets = 0;
      callDurationSeconds = 0;
      sipStatus = "DIALING...";
      notifyListeners();

      try {
        final stream = startSipCall(
          targetIp: ipController.text.trim(),
          targetPort: int.parse(portController.text.trim()),
          toUser: toController.text.trim(),
          fromUser: fromController.text.trim(),
        );

        stream.listen(
          (event) => _processEvent(event),
          onDone: () {
            isCalling = false;
            sipStatus = "DISCONNECTED";
            _stopDurationTimer();
            platform.invokeMethod('setNormalMode').catchError((_) {});
            notifyListeners();
          },
          onError: (e) {
            _processEvent("Error(\"Stream Fail: $e\")");
            platform.invokeMethod('setNormalMode').catchError((_) {});
          },
        );
      } catch (e) {
        _processEvent("Error(\"Init Fail: $e\")");
        isCalling = false;
        platform.invokeMethod('setNormalMode').catchError((_) {});
        notifyListeners();
      }
    } else {
      _addLog(TelemetryEntry(message: "❌ MIC PERMISSION DENIED", level: TelemetryLevel.error));
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    ipController.dispose();
    portController.dispose();
    toController.dispose();
    fromController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}