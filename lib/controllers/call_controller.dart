// Dosya: lib/controllers/call_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentiric_sip_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_uac/telecom_telemetry.dart';
import '../models.dart';

class CallController extends ChangeNotifier {
  static const platform = MethodChannel('ai.sentiric.sentiric_sip_uac/audio_route');

  List<SipProfile> profiles =[];
  List<PhoneContact> _allContacts = [];
  List<CallRecord> _allHistory =[];
  SipProfile? activeProfile;

  List<PhoneContact> get activeContacts => _allContacts.where((c) => c.profileId == activeProfile?.id).toList();
  List<CallRecord> get activeHistory => _allHistory.where((h) => h.profileId == activeProfile?.id).toList();

  // [UX FIX] Zero-latency dialpad için ValueNotifier yapısı.
  final ValueNotifier<String> dialedNumber = ValueNotifier<String>("");
  
  final List<TelemetryEntry> telemetryLogs =[];
  final ScrollController scrollController = ScrollController();
  
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
  
  String incomingCaller = "";
  String currentCallTarget = "";
  bool isIncomingCall = false;
  Timer? _durationTimer;

  // [UX FIX] Başka bir sekmeden çağrı geldiğinde ana sekmeye yönlendirme Callback'i
  VoidCallback? onNavigateToDialer;

  // [UX FIX] FRB Event Throttler
  bool _updateScheduled = false;
  void _scheduleUiUpdate() {
    if (!_updateScheduled) {
      _updateScheduled = true;
      Future.delayed(const Duration(milliseconds: 64), () {
        notifyListeners();
        _updateScheduled = false;
      });
    }
  }

  CallController() { _initStorage(); }

  Future<void> _initStorage() async {
    final prefs = await SharedPreferences.getInstance();
    
    final profData = prefs.getString('profiles');
    if (profData != null) {
      profiles = (jsonDecode(profData) as List).map((x) => SipProfile.fromJson(x)).toList();
    }
    if (profiles.isEmpty) {
      profiles.add(SipProfile(id: 'default', name: 'Local Test', ip: '127.0.0.1', port: '5060', user: '1000', password: '123', isTrunk: false));
    }
    final lastProf = prefs.getString('active_profile') ?? profiles.first.id;
    activeProfile = profiles.firstWhere((p) => p.id == lastProf, orElse: () => profiles.first);

    final contData = prefs.getString('contacts');
    if (contData != null) _allContacts = (jsonDecode(contData) as List).map((x) => PhoneContact.fromJson(x)).toList();

    final histData = prefs.getString('history');
    if (histData != null) _allHistory = (jsonDecode(histData) as List).map((x) => CallRecord.fromJson(x)).toList();

    notifyListeners();
  }

  Future<void> saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profiles', jsonEncode(profiles.map((e) => e.toJson()).toList()));
    await prefs.setString('contacts', jsonEncode(_allContacts.map((e) => e.toJson()).toList()));
    await prefs.setString('history', jsonEncode(_allHistory.map((e) => e.toJson()).toList()));
    if (activeProfile != null) await prefs.setString('active_profile', activeProfile!.id);
    notifyListeners();
  }

  void addContact(String name, String number) {
    if (activeProfile == null) return;
    _allContacts.add(PhoneContact(id: DateTime.now().millisecondsSinceEpoch.toString(), profileId: activeProfile!.id, name: name, number: number));
    saveState();
  }

  void removeContact(String id) {
    _allContacts.removeWhere((c) => c.id == id);
    saveState();
  }

  void clearActiveHistory() {
    if (activeProfile == null) return;
    _allHistory.removeWhere((h) => h.profileId == activeProfile!.id);
    saveState();
  }

  void loadProfile(SipProfile p) {
    if(isCalling) endCall();
    activeProfile = p;
    sipStatus = "STANDBY";
    dialedNumber.value = ""; 
    saveState();
  }

  void appendDial(String digit) {
    if (dialedNumber.value.length < 20) dialedNumber.value += digit;
  }

  void backspaceDial() {
    if (dialedNumber.value.isNotEmpty) {
      dialedNumber.value = dialedNumber.value.substring(0, dialedNumber.value.length - 1);
    }
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

  String _parseCallerId(String rawFrom) {
    try {
      final sipRegex = RegExp(r'sip:([^@>]+)');
      final match = sipRegex.firstMatch(rawFrom);
      String parsedNumber = match != null ? match.group(1)! : "Unknown";
      
      final contact = activeContacts.where((c) => c.number == parsedNumber).firstOrNull;
      return contact != null ? contact.name : parsedNumber;
    } catch (_) {
      return "Unknown Caller";
    }
  }

  void _processEvent(String raw) {
    final entry = TelecomTelemetry.parse(raw);

    if (raw.contains("IncomingCall")) {
      final fromMatch = RegExp(r'from:\s*"([^"]+)"').firstMatch(raw);
      final rawFrom = fromMatch?.group(1) ?? "Unknown";
      
      incomingCaller = _parseCallerId(rawFrom); 
      
      sipStatus = "INCOMING CALL";
      isCalling = true; 
      isIncomingCall = true;
      
      final sipRegex = RegExp(r'sip:([^@>]+)');
      final match = sipRegex.firstMatch(rawFrom);
      currentCallTarget = match != null ? match.group(1)! : "Unknown";
      
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(seconds: 1), () { if(sipStatus == "INCOMING CALL") HapticFeedback.heavyImpact(); });
      
      onNavigateToDialer?.call(); // [UX FIX] Çağrı gelince ekranı aktifleştir
      
      _addLog(TelemetryEntry(message: "🔔 Incoming call from: $incomingCaller", level: TelemetryLevel.status));
      notifyListeners(); // Hızlı tepki için anında render.
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
        notifyListeners(); // Acil UI güncellemesi
      } else if (sipStatus == "TERMINATED" || sipStatus == "IDLE" || sipStatus == "AUTHFAILED") {
        
        if (isCalling && currentCallTarget.isNotEmpty && activeProfile != null) {
          _allHistory.insert(0, CallRecord(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            profileId: activeProfile!.id,
            targetNumber: currentCallTarget,
            direction: isIncomingCall ? "IN" : "OUT",
            status: callDurationSeconds > 0 ? "ANSWERED" : (isIncomingCall ? "MISSED" : "REJECTED"),
            durationSeconds: callDurationSeconds,
            timestamp: DateTime.now()
          ));
          saveState();
        }

        isCalling = false;
        isMediaFlowing = false;
        rxPackets = 0; 
        txPackets = 0;
        _stopDurationTimer();
        platform.invokeMethod('setNormalMode').catchError((_) {});
        notifyListeners();
      }
      _addLog(entry);
    } else {
      _addLog(entry);
    }
    
    // [UX FIX] Sürekli güncellenen statüler için Throttle 
    _scheduleUiUpdate();
  }

  void toggleDebugConsole() { showDebugConsole = !showDebugConsole; notifyListeners(); _scrollToBottom(); }
  void _addLog(TelemetryEntry entry) { telemetryLogs.add(entry); _scrollToBottom(); }
  void _scrollToBottom() {
    if (showDebugConsole && scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) scrollController.animateTo(scrollController.position.maxScrollExtent + 50, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      });
    }
  }

  void _startDurationTimer() {
    callDurationSeconds = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) { callDurationSeconds++; notifyListeners(); });
  }

  void _stopDurationTimer() => _durationTimer?.cancel();
  String get formattedDuration {
    final minutes = (callDurationSeconds / 60).floor();
    final seconds = callDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> registerAccount() async {
    if (activeProfile == null || activeProfile!.ip.isEmpty || activeProfile!.isTrunk) return;
    await initEngineIfNeeded();
    sipStatus = "REGISTERING...";
    notifyListeners();
    try { await registerSipAccount(targetIp: activeProfile!.ip, targetPort: int.tryParse(activeProfile!.port) ?? 5060, user: activeProfile!.user, password: activeProfile!.password); } catch (e) {}
  }

  Future<void> makeCall(String targetNumber) async {
    if (isCalling || activeProfile == null || targetNumber.isEmpty) return;
    await initEngineIfNeeded();

    if (Platform.isAndroid || Platform.isIOS) {
      PermissionStatus status = await Permission.microphone.status;
      if (!status.isGranted) status = await Permission.microphone.request();
      if (!status.isGranted) return;
    }

    currentCallTarget = targetNumber;
    isIncomingCall = false;
    isSpeakerOn = false;
    
    onNavigateToDialer?.call(); // [UX FIX] Rehberden aranırsa ana ekrana at.
    
    try { if (Platform.isAndroid || Platform.isIOS) await platform.invokeMethod('setInCallMode'); } catch (e) {}

    telemetryLogs.clear();
    isCalling = true;
    isMediaFlowing = false;
    rxPackets = 0;
    txPackets = 0;
    callDurationSeconds = 0;
    sipStatus = "DIALING...";
    notifyListeners();

    try { await startSipCall(targetIp: activeProfile!.ip, targetPort: int.tryParse(activeProfile!.port) ?? 5060, toUser: targetNumber, fromUser: activeProfile!.user); } catch (e) {}
  }

  Future<void> answerCall() async {
    if (Platform.isAndroid || Platform.isIOS) {
      PermissionStatus status = await Permission.microphone.status;
      if (!status.isGranted) status = await Permission.microphone.request();
      if (!status.isGranted) return rejectCall(); 
    }
    try { if (Platform.isAndroid || Platform.isIOS) await platform.invokeMethod('setInCallMode'); } catch (e) {}
    sipStatus = "ANSWERING...";
    notifyListeners();
    try { await acceptInboundCall(); } catch (e) {}
  }

  Future<void> rejectCall() async { try { await rejectInboundCall(); } catch (e) {} }
  Future<void> endCall() async { try { await endSipCall(); } catch (e) {} }
  Future<void> toggleSpeaker() async { isSpeakerOn = !isSpeakerOn; notifyListeners(); try { if (Platform.isAndroid || Platform.isIOS) await platform.invokeMethod('toggleSpeaker', {'speakerOn': isSpeakerOn}); } catch (e) {} }
  void toggleMute() { isMuted = !isMuted; setMute(muted: isMuted); notifyListeners(); }
  void sendDtmf(String key) { sendSipDtmf(key: key); _processEvent("Log(\"🎹 Sent DTMF: $key\")"); }
}