// Dosya: sentiric-sip-uac/lib/controllers/call_controller.dart
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
  final TextEditingController passwordController = TextEditingController();

  // Telemetry & UI State
  final List<TelemetryEntry> telemetryLogs =[];
  final ScrollController scrollController = ScrollController();
  
  bool isTrunkMode = false;
  bool isCalling = false;
  bool isMediaFlowing = false;
  bool showDebugConsole = false;
  bool isSpeakerOn = false;
  bool isMuted = false;
  bool _isEngineStarted = false;
  
  int rxPackets = 0;
  int txPackets = 0;
  int callDurationSeconds = 0;
  String sipStatus = "STANDBY";
  
  // [YENİ]: Gelen Arama İçin Kimlik Tutucu
  String incomingCaller = "";
  
  Timer? _durationTimer;

  CallController() {
    _loadProfile();
  }

  Future<void> initEngineIfNeeded() async {
    if (_isEngineStarted) return;
    try {
      final stream = startEngine();
      stream.listen(
        (event) => _processEvent(event),
        onError: (e) => _processEvent("Error(\"Engine Stream Fail: $e\")")
      );
      _isEngineStarted = true;
    } catch (e) {
      debugPrint("Engine Start Error: $e");
    }
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    ipController.text = prefs.getString('targetIp') ?? "service.sentiric.cloud";
    portController.text = prefs.getString('targetPort') ?? "5060";
    toController.text = prefs.getString('toUser') ?? "";
    fromController.text = prefs.getString('fromUser') ?? "";
    passwordController.text = prefs.getString('password') ?? "";
    isTrunkMode = prefs.getBool('isTrunkMode') ?? false;
    notifyListeners();
  }

  Future<void> saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetIp', ipController.text.trim());
    await prefs.setString('targetPort', portController.text.trim());
    await prefs.setString('toUser', toController.text.trim());
    await prefs.setString('fromUser', fromController.text.trim());
    await prefs.setString('password', passwordController.text.trim());
    await prefs.setBool('isTrunkMode', isTrunkMode);
  }

  void setMode(bool trunkMode) {
    isTrunkMode = trunkMode;
    if (!isCalling) {
      sipStatus = "STANDBY";
      notifyListeners();
    }
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

    // [YENİ]: Gelen Arama Olayını Yakala (IncomingCall { from: "...", call_id: "..." })
    if (raw.contains("IncomingCall")) {
      final fromMatch = RegExp(r'from:\s*"([^"]+)"').firstMatch(raw);
      incomingCaller = fromMatch?.group(1) ?? "Unknown Caller";
      
      sipStatus = "INCOMING CALL";
      isCalling = true; 
      
      // HapticFeedback eklenebilir
      HapticFeedback.heavyImpact();
      
      _addLog(TelemetryEntry(message: "🔔 Incoming call from: $incomingCaller", level: TelemetryLevel.status));
      notifyListeners();
      return;
    }

    if (entry.level == TelemetryLevel.media && entry.rxCount != null) {
      rxPackets = entry.rxCount!;
      txPackets = entry.txCount!;
      if (rxPackets > 5) isMediaFlowing = true;
    } 
    else if (entry.message.contains("SYSTEM STATE:")) {
      sipStatus = entry.message.split(':').last.trim().toUpperCase();
      
      if (sipStatus == "CONNECTED") {
        _startDurationTimer();
      } else if (sipStatus == "TERMINATED" || sipStatus == "IDLE" || sipStatus == "AUTHFAILED") {
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

  // --- ARAMA İŞLEMLERİ ---

  Future<void> registerAccount() async {
    await saveProfile();
    await initEngineIfNeeded();

    sipStatus = "REGISTERING...";
    notifyListeners();

    try {
      await registerSipAccount(
        targetIp: ipController.text.trim(),
        targetPort: int.parse(portController.text.trim()),
        user: fromController.text.trim(),
        password: passwordController.text.trim(),
      );
    } catch (e) {
      _processEvent("Error(\"Register Fail: $e\")");
    }
  }

  Future<void> makeCall() async {
    if (isCalling) return;
    await saveProfile();
    await initEngineIfNeeded();

    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();

    if (!status.isGranted) {
      _addLog(TelemetryEntry(message: "❌ MIC PERMISSION DENIED", level: TelemetryLevel.error));
      notifyListeners();
      return;
    }

    isSpeakerOn = false;
    try { await platform.invokeMethod('setInCallMode'); } catch (e) { debugPrint("InCall Mode Error: $e"); }

    telemetryLogs.clear();
    isCalling = true;
    isMediaFlowing = false;
    rxPackets = 0;
    txPackets = 0;
    callDurationSeconds = 0;
    sipStatus = "DIALING...";
    notifyListeners();

    try {
      await startSipCall(
        targetIp: ipController.text.trim(),
        targetPort: int.parse(portController.text.trim()),
        toUser: toController.text.trim(),
        fromUser: fromController.text.trim(),
      );
    } catch (e) {
      _processEvent("Error(\"Call Fail: $e\")");
      isCalling = false;
      platform.invokeMethod('setNormalMode').catchError((_) {});
      notifyListeners();
    }
  }

  // [YENİ]: Gelen Aramayı Cevapla
  Future<void> answerCall() async {
    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) status = await Permission.microphone.request();

    if (!status.isGranted) {
      _addLog(TelemetryEntry(message: "❌ MIC PERMISSION DENIED", level: TelemetryLevel.error));
      return rejectCall(); // Mikrofon izni yoksa doğrudan kapat
    }

    try { await platform.invokeMethod('setInCallMode'); } catch (e) { debugPrint("InCall Mode Error: $e"); }
    
    sipStatus = "ANSWERING...";
    notifyListeners();
    
    try {
      await acceptInboundCall();
    } catch (e) {
      _processEvent("Error(\"Answer Fail: $e\")");
    }
  }

  // [YENİ]: Gelen Aramayı Reddet
  Future<void> rejectCall() async {
    try {
      await rejectInboundCall();
      sipStatus = "REJECTED";
      isCalling = false;
      notifyListeners();
    } catch (e) {
      _processEvent("Error(\"Reject Fail: $e\")");
    }
  }

  Future<void> endCall() async {
    if (!isCalling) return;
    await endSipCall();
    isCalling = false;
    isMediaFlowing = false;
    sipStatus = "TERMINATING...";
    _stopDurationTimer();
    platform.invokeMethod('setNormalMode').catchError((_) {});
    notifyListeners();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    ipController.dispose();
    portController.dispose();
    toController.dispose();
    fromController.dispose();
    passwordController.dispose();
    scrollController.dispose();
    super.dispose();
  }
}