// lib/main.dart
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentiric_sip_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_uac/src/rust/frb_generated.dart';
import 'controllers/call_controller.dart';
import 'ui/screens/dialer_screen.dart';

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
      title: 'Sip UAC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000), 
        primaryColor: const Color(0xFF00FF9D),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF9D),
          secondary: Colors.cyanAccent,
          surface: Color(0xFF111111),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  
  // 🧠 Bütün uygulama boyunca yaşayacak tek Controller (Singleton State)
  final CallController _callController = CallController();

  @override
  void dispose() {
    _callController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DialerScreen(controller: _callController), // MVC Pattern Devrede
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: const Color(0xFF00FF9D),
        unselectedItemColor: Colors.white30,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: "DSP Tuning"),
        ],
      ),
    );
  }
}

// --- DSP TUNING EKRANI (Aynı kaldı) ---
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
    
    updateAudioSettings(micGain: _micGain, speakerGain: _speakerGain, enableAec: _enableAec);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text("REAL-TIME DSP TUNING", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
          const SizedBox(height: 30),
          
          _buildSlider("Hardware TX Gain (Microphone)", _micGain, 0.1, 3.0, (val) {
            setState(() => _micGain = val);
            _saveSettings();
          }),
          
          _buildSlider("Hardware RX Gain (Speaker)", _speakerGain, 0.1, 5.0, (val) {
            setState(() => _speakerGain = val);
            _saveSettings();
          }),

          const SizedBox(height: 30),
          SwitchListTile(
            title: const Text("OS Acoustic Echo Cancel", style: TextStyle(fontSize: 14)),
            subtitle: const Text("Applies hardware AEC via AudioTrack routing.", style: TextStyle(fontSize: 12, color: Colors.white30)),
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
            Text("${value.toStringAsFixed(1)}x", style: const TextStyle(color: Color(0xFF00FF9D), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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