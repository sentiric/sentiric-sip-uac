// Dosya: sentiric-sip-uac/lib/main.dart
import 'dart:ffi';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sentiric_sip_uac/src/rust/api/simple.dart';
import 'package:sentiric_sip_uac/src/rust/frb_generated.dart';
import 'controllers/call_controller.dart';
import 'ui/screens/dialer_screen.dart';
import 'ui/screens/dashboard_screens.dart';

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
  final CallController _callController = CallController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children:[
          DialerScreen(controller: _callController), 
          ContactsScreen(controller: _callController),
          HistoryScreen(controller: _callController),
          ProfilesScreen(controller: _callController),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF111111),
        selectedItemColor: const Color(0xFF00FF9D),
        unselectedItemColor: Colors.white30,
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const[
          BottomNavigationBarItem(icon: Icon(Icons.dialpad), label: "Dialer"),
          BottomNavigationBarItem(icon: Icon(Icons.contacts), label: "Contacts"),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
          BottomNavigationBarItem(icon: Icon(Icons.manage_accounts), label: "Profiles"),
        ],
      ),
    );
  }
}