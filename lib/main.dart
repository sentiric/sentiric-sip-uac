// sentiric-sip-mobile-uac/lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/frb_generated.dart';
import 'package:sentiric_sip_mobile_uac/telecom_telemetry.dart';
import 'dart:io';
import 'dart:ffi';
import 'dart:async';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Platform.isAndroid) {
      try { DynamicLibrary.open('libc++_shared.so'); } catch (e) { debugPrint("⚠️ libc++ load warning: $e"); }
    }
    await RustLib.init();
    await initLogger(); 
  } catch (e) {
    debugPrint("Rust Init Error: $e");
  }
  runApp(const SentiricApp());
}

class SentiricApp extends StatelessWidget {
  const SentiricApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentiric UAC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF09090B),
        primaryColor: const Color(0xFF00FF9D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D),
          secondary: Colors.cyanAccent,
          surface: Color(0xFF18181B),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// --- ANA NAVİGASYON (PRODUCT READY YAPI) ---
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const DialerScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF18181B),
        selectedItemColor: const Color(0xFF00FF9D),
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: "Dialer"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}

// --- AYARLAR EKRANI ---
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _micGain = 1.0;
  double _speakerGain = 1.5;
  bool _enableAec = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _micGain = prefs.getDouble('micGain') ?? 1.0;
      _speakerGain = prefs.getDouble('speakerGain') ?? 1.5;
      _enableAec = prefs.getBool('enableAec') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('micGain', _micGain);
    await prefs.setDouble('speakerGain', _speakerGain);
    await prefs.setBool('enableAec', _enableAec);
    
    // TODO: Adım 2'de bu değerleri Rust tarafına (Engine'e) anlık göndereceğiz.
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("DSP SETTINGS", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 20),
          
          _buildSlider("Microphone Gain", _micGain, 0.1, 3.0, (val) {
            setState(() => _micGain = val);
            _saveSettings();
          }),
          
          _buildSlider("Speaker Gain", _speakerGain, 0.1, 5.0, (val) {
            setState(() => _speakerGain = val);
            _saveSettings();
          }),

          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text("Hardware AEC (Echo Cancel)", style: TextStyle(fontSize: 14)),
            subtitle: const Text("Use OS level acoustic echo cancellation", style: TextStyle(fontSize: 12, color: Colors.grey)),
            value: _enableAec,
            activeColor: const Color(0xFF00FF9D),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _enableAec = val);
              _saveSettings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14)),
            Text("${value.toStringAsFixed(1)}x", style: const TextStyle(color: Color(0xFF00FF9D), fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF00FF9D),
          inactiveColor: Colors.white10,
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

// --- ARAMA EKRANI (DIALER) ---
class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  static const platform = MethodChannel('ai.sentiric.mobile/audio_route');

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _fromController = TextEditingController();

  final List<TelemetryEntry> _telemetryLogs = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isCalling = false;
  bool _isMediaFlowing = false;
  bool _showDebugConsole = false;
  bool _isSpeakerOn = false; 
  bool _isMuted = false;     
  
  int _rxPackets = 0;
  int _txPackets = 0;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  String _sipStatus = "IDLE";

  @override
  void initState() {
    super.initState();
    _loadProfile(); // Açılışta son girilen bilgileri yükle
  }

  // --- PERSISTENCE LOGIC ---
  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _ipController.text = prefs.getString('targetIp') ?? "";
      _portController.text = prefs.getString('targetPort') ?? "";
      _toController.text = prefs.getString('toUser') ?? "";
      _fromController.text = prefs.getString('fromUser') ?? ""; // Strict E.164 formatı
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('targetIp', _ipController.text.trim());
    await prefs.setString('targetPort', _portController.text.trim());
    await prefs.setString('toUser', _toController.text.trim());
    await prefs.setString('fromUser', _fromController.text.trim());
  }
  // -----------------------

  Future<void> _toggleSpeaker() async {
    setState(() { _isSpeakerOn = !_isSpeakerOn; });
    try { await platform.invokeMethod('setInCallMode', {'speakerOn': _isSpeakerOn}); } catch (e) { debugPrint("$e"); }
  }

  void _startDurationTimer() {
    _callDurationSeconds = 0;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() { _callDurationSeconds++; });
    });
  }

  void _stopDurationTimer() { _durationTimer?.cancel(); }

  String get _formattedDuration {
    final minutes = (_callDurationSeconds / 60).floor();
    final seconds = _callDurationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _processEvent(String raw) {
    if (!mounted) return;
    final entry = TelecomTelemetry.parse(raw);

    setState(() {
      if (entry.level == TelemetryLevel.media && entry.rxCount != null) {
        _rxPackets = entry.rxCount!;
        _txPackets = entry.txCount!;
        if (_rxPackets > 5) _isMediaFlowing = true;
      } 
      else if (entry.message.contains("SIP STATE:") || entry.message.contains("CallStateChanged")) {
        _sipStatus = entry.message.split(RegExp(r'[:\(]')).last.replaceAll(")", "").trim().toUpperCase();
        
        if (_sipStatus == "CONNECTED") { _startDurationTimer(); }
        else if (_sipStatus == "TERMINATED") {
           _isCalling = false;
           _isMediaFlowing = false;
           _stopDurationTimer();
           platform.invokeMethod('setNormalMode').catchError((_) {});
        }
        _addLog(entry);
      } else {
        _addLog(entry);
      }
    });
  }

  void _addLog(TelemetryEntry entry) {
    _telemetryLogs.add(entry);
    if (_showDebugConsole && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _toggleCall() async {
    if (_isCalling) {
      await endSipCall();
      setState(() {
        _isCalling = false;
        _isMediaFlowing = false;
        _sipStatus = "TERMINATING...";
        _stopDurationTimer();
      });
      platform.invokeMethod('setNormalMode').catchError((_) {});
      return;
    }

    // Çağrı başlatırken profili otomatik kaydet
    await _saveProfile();

    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) { status = await Permission.microphone.request(); }

    if (status.isGranted) {
      _isSpeakerOn = false;
      try { await platform.invokeMethod('setInCallMode', {'speakerOn': false}); } catch (e) { debugPrint("$e"); }

      setState(() {
        _telemetryLogs.clear();
        _isCalling = true;
        _isMediaFlowing = false;
        _rxPackets = 0;
        _txPackets = 0;
        _callDurationSeconds = 0;
        _sipStatus = "DIALING...";
      });

      try {
        final stream = startSipCall(
          targetIp: _ipController.text.trim(),
          targetPort: int.parse(_portController.text.trim()),
          toUser: _toController.text.trim(),
          fromUser: _fromController.text.trim(),
        );

        stream.listen(
          (event) => _processEvent(event),
          onDone: () {
            setState(() { _isCalling = false; _sipStatus = "DISCONNECTED"; _stopDurationTimer(); });
            platform.invokeMethod('setNormalMode').catchError((_) {});
          },
          onError: (e) {
            _processEvent("Error(\"Stream Fail: $e\")");
            platform.invokeMethod('setNormalMode').catchError((_) {});
          },
        );
      } catch (e) {
        _processEvent("Error(\"Init Fail: $e\")");
        setState(() => _isCalling = false);
        platform.invokeMethod('setNormalMode').catchError((_) {});
      }
    } else {
      _addLog(TelemetryEntry(message: "❌ MIC PERMISSION DENIED BY USER", level: TelemetryLevel.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sentiric UAC', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => setState(() => _showDebugConsole = !_showDebugConsole), 
            icon: Icon(Icons.bug_report, color: _showDebugConsole ? Colors.greenAccent : Colors.grey)
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isCalling) _buildDialerForm(),
            if (_isCalling) Expanded(child: _buildActiveCallScreen()),
            if (_showDebugConsole) Expanded(child: _buildConsole()),
          ],
        ),
      ),
    );
  }

  Widget _buildDialerForm() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("NETWORK EDGE", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(flex: 3, child: _input(_ipController, "Target IP", Icons.dns, keyboardType: TextInputType.url)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _input(_portController, "Port", Icons.numbers, isCompact: true, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 24),
            
            const Text("SIP IDENTITY", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            const SizedBox(height: 8),
            _input(_toController, "Destination (e.g., 9999)", Icons.call_made, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _input(_fromController, "Your Caller ID", Icons.person_outline, keyboardType: TextInputType.phone),
            
            const SizedBox(height: 40),
            
            GestureDetector(
              onTap: _toggleCall,
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF9D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: const Color(0xFF00FF9D), width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x3300FF9D), blurRadius: 20, spreadRadius: 5)],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, color: Color(0xFF00FF9D), size: 32),
                    SizedBox(width: 16),
                    Text("START TEST CALL", style: TextStyle(color: Color(0xFF00FF9D), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCallScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Text(_toController.text, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300, color: Colors.white)),
            const SizedBox(height: 8),
            Text(_sipStatus, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0, color: _sipStatus == "CONNECTED" ? Colors.greenAccent : Colors.orangeAccent)),
            const SizedBox(height: 8),
            Text(_sipStatus == "CONNECTED" ? _formattedDuration : "Connecting...", style: const TextStyle(fontSize: 16, color: Colors.grey, fontFamily: 'monospace')),
          ],
        ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF18181B), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("TX (SENT)", "$_txPackets", Colors.white70),
              Icon(Icons.compare_arrows, color: _isMediaFlowing ? Colors.greenAccent : Colors.grey, size: 24),
              _statItem("RX (RECV)", "$_rxPackets", Colors.white70),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionBtn(Icons.mic_off, _isMuted ? "MUTED" : "MUTE", _isMuted, () => setState(() => _isMuted = !_isMuted)),
            const SizedBox(width: 30),
            _actionBtn(Icons.dialpad, "KEYPAD", false, () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("DTMF Keypad - Coming Soon"), duration: Duration(seconds: 1)));
            }),
            const SizedBox(width: 30),
            _actionBtn(_isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk, "SPEAKER", _isSpeakerOn, _toggleSpeaker),
          ],
        ),

        GestureDetector(
          onTap: _toggleCall,
          child: Container(
            height: 70, width: 70,
            decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red, blurRadius: 20)]),
            child: const Icon(Icons.call_end, color: Colors.white, size: 36),
          ),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : const Color(0xFF27272A),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isCompact = false, TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: isCompact ? 12 : 14, fontFamily: 'monospace', color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: isCompact ? 10 : 12, color: Colors.grey),
        prefixIcon: Icon(icon, size: isCompact ? 14 : 18, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF18181B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF00FF9D))),
        contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: isCompact ? 4 : 12),
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(val, style: TextStyle(fontSize: 16, color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConsole() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Colors.white24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(4),
            color: Colors.white10,
            child: const Text(" SYSTEM LOGS", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _telemetryLogs.length,
              itemBuilder: (context, index) {
                final log = _telemetryLogs[index];
                Color color = Colors.white60;
                if (log.level == TelemetryLevel.status) color = const Color(0xFF00FF9D);
                if (log.level == TelemetryLevel.error) color = Colors.redAccent;
                if (log.level == TelemetryLevel.sip) color = Colors.cyanAccent;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(log.message, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}