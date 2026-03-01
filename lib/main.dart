// sentiric-sip-mobile-uac/lib/main.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_mobile_uac/src/rust/frb_generated.dart';
import 'package:sentiric_sip_mobile_uac/telecom_telemetry.dart';
import 'dart:io';
import 'dart:ffi';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Platform.isAndroid) {
      try {
        DynamicLibrary.open('libc++_shared.so');
      } catch (e) {
        debugPrint("⚠️ libc++ load warning: $e");
      }
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
      title: 'Sentiric Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF050505),
        primaryColor: const Color(0xFF00FF9D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D),
          secondary: Colors.cyanAccent,
          surface: Color(0xFF111111),
        ),
      ),
      home: const DialerScreen(),
    );
  }
}

class DialerScreen extends StatefulWidget {
  const DialerScreen({super.key});
  @override
  State<DialerScreen> createState() => _DialerScreenState();
}

class _DialerScreenState extends State<DialerScreen> {
  final TextEditingController _ipController = TextEditingController(text: "34.122.40.122");
  final TextEditingController _portController = TextEditingController(text: "5060");
  final TextEditingController _toController = TextEditingController(text: "9999");
  final TextEditingController _fromController = TextEditingController(text: "mobile-uac");

  final List<TelemetryEntry> _telemetryLogs = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _isCalling = false;
  bool _isMediaFlowing = false;
  int _rxPackets = 0;
  int _txPackets = 0;
  String _sipStatus = "IDLE";

  void _processEvent(String raw) {
    if (!mounted) return;
    
    final entry = TelecomTelemetry.parse(raw);

    setState(() {
      if (entry.level == TelemetryLevel.media && entry.rxCount != null) {
        _rxPackets = entry.rxCount!;
        _txPackets = entry.txCount!;
        if (_rxPackets > 5) _isMediaFlowing = true;
      } 
      else if (entry.message.contains("SIP STATE:")) {
        _sipStatus = entry.message.split(":").last.trim().toUpperCase();
        if (_sipStatus == "TERMINATED") {
           _isCalling = false;
           _isMediaFlowing = false;
        }
        _addLog(entry);
      }
      else {
        _addLog(entry);
      }
    });
  }

  void _addLog(TelemetryEntry entry) {
    _telemetryLogs.add(entry);
    if (_scrollController.hasClients) {
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
      setState(() {
        _isCalling = false;
        _isMediaFlowing = false;
        _sipStatus = "IDLE";
      });
      return;
    }

    // [KRİTİK DÜZELTME]: Mikrofon iznini garanti altına alıyoruz.
    PermissionStatus status = await Permission.microphone.status;
    if (!status.isGranted) {
      _addLog(TelemetryEntry(message: "Requesting Microphone Permission...", level: TelemetryLevel.info));
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      setState(() {
        _telemetryLogs.clear();
        _isCalling = true;
        _isMediaFlowing = false;
        _rxPackets = 0;
        _txPackets = 0;
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
          onDone: () => setState(() { 
            _isCalling = false; 
            _sipStatus = "DISCONNECTED"; 
          }),
          onError: (e) => _processEvent("Error(\"Stream Fail: $e\")"),
        );
      } catch (e) {
        _processEvent("Error(\"Init Fail: $e\")");
        setState(() => _isCalling = false);
      }
    } else {
      _addLog(TelemetryEntry(message: "❌ MIC PERMISSION DENIED BY USER", level: TelemetryLevel.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SENTIRIC FIELD MONITOR v2.6', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(onPressed: () => setState(() => _telemetryLogs.clear()), icon: const Icon(Icons.delete_sweep, size: 20))
        ],
      ),
      body: Column(
        children: [
          _buildTopPanel(),
          if (_isCalling) _buildLiveStats(),
          const Divider(height: 1, color: Colors.white12),
          Expanded(child: _buildConsole()),
        ],
      ),
    );
  }

  Widget _buildTopPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF111111),
      child: Column(
        children: [
          Row(children: [
            Expanded(flex: 3, child: _input(_ipController, "EDGE IP", Icons.dns)),
            const SizedBox(width: 10),
            Expanded(flex: 1, child: _input(_portController, "PORT", Icons.numbers)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _input(_toController, "CALLEE", Icons.call_received)),
            const SizedBox(width: 10),
            Expanded(child: _input(_fromController, "CALLER", Icons.person)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _toggleCall,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isCalling ? Colors.red.shade900 : const Color(0xFF00FF9D),
                foregroundColor: _isCalling ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              icon: Icon(_isCalling ? Icons.call_end : Icons.call),
              label: Text(_isCalling ? "TERMINATE SESSION" : "INITIATE CALL", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      enabled: !_isCalling,
      style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10, color: Colors.grey),
        prefixIcon: Icon(icon, size: 14, color: Colors.grey),
        filled: true,
        fillColor: Colors.black,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Colors.white24)),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildLiveStats() {
    Color statusColor = Colors.grey;
    if (_sipStatus == "CONNECTED") statusColor = Colors.blue;
    if (_isMediaFlowing) statusColor = const Color(0xFF00FF9D);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Colors.black,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _statItem("STATUS", _sipStatus, statusColor),
          _statItem("MEDIA", _isMediaFlowing ? "FLOWING" : "WAITING...", _isMediaFlowing ? const Color(0xFF00FF9D) : Colors.orange),
          _statItem("TX (SENT)", "$_txPackets pkts", Colors.white70),
          _statItem("RX (RECV)", "$_rxPackets pkts", Colors.white70),
        ],
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(val, style: TextStyle(fontSize: 12, color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConsole() {
    return Container(
      color: Colors.black,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(10),
        itemCount: _telemetryLogs.length,
        itemBuilder: (context, index) {
          final log = _telemetryLogs[index];
          Color color = Colors.white60;
          if (log.level == TelemetryLevel.status) color = const Color(0xFF00FF9D);
          if (log.level == TelemetryLevel.error) color = Colors.redAccent;
          if (log.level == TelemetryLevel.sip) color = Colors.cyanAccent;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(log.message, style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 10)),
          );
        },
      ),
    );
  }
}