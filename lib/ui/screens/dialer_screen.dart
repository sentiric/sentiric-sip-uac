import 'package:flutter/material.dart';
import '../../controllers/call_controller.dart';
import '../../telecom_telemetry.dart';

class DialerScreen extends StatelessWidget {
  final CallController controller;

  const DialerScreen({super.key, required this.controller});

  void _showDtmfPad(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            children: [
              const Text("DTMF KEYPAD", style: TextStyle(color: Color(0xFF00FF9D), letterSpacing: 2.0, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () {
                        controller.sendDtmf(keys[index]);
                        Navigator.pop(context); // Basınca kapat (opsiyonel)
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        alignment: Alignment.center,
                        child: Text(keys[index], style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w300)),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('SIP UAC', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3.0)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            actions: [
              IconButton(
                onPressed: controller.toggleDebugConsole,
                icon: Icon(Icons.terminal, color: controller.showDebugConsole ? const Color(0xFF00FF9D) : Colors.white30)
              )
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (!controller.isCalling) _buildDialerForm(),
                if (controller.isCalling) Expanded(child: _buildActiveCallScreen(context)),
                if (controller.showDebugConsole) Expanded(child: _buildConsole()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialerForm() {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // YENİ: MOD SEÇİCİ
            Center(
              child: ToggleButtons(
                isSelected: [!controller.isTrunkMode, controller.isTrunkMode],
                onPressed: (int index) => controller.setMode(index == 1),
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.black,
                fillColor: const Color(0xFF00FF9D),
                color: Colors.white54,
                constraints: const BoxConstraints(minHeight: 36, minWidth: 140),
                children: const [
                  Text("SIP ACCOUNT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text("RAW TRUNK", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const Text("TARGET NODE", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(flex: 3, child: _input(controller.ipController, controller.isTrunkMode ? "IP Address" : "Domain / SBC IP", Icons.dns, keyboardType: TextInputType.url)),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _input(controller.portController, "Port", Icons.numbers, isCompact: true, keyboardType: TextInputType.number)),
            ]),
            const SizedBox(height: 20),
            
            const Text("IDENTITY", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            const SizedBox(height: 12),
            _input(controller.fromController, "Username / Caller ID", Icons.person_outline, keyboardType: TextInputType.text),
            
            if (!controller.isTrunkMode) ...[
              const SizedBox(height: 12),
              _input(controller.passwordController, "Password", Icons.lock_outline, obscureText: true),
            ],

            const SizedBox(height: 20),

            // AKSİYON DÜĞMELERİ
            if (controller.isTrunkMode) ...[
              const Text("DESTINATION", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
              const SizedBox(height: 12),
              _input(controller.toController, "Target Extension (e.g., 9999)", Icons.call_made, keyboardType: TextInputType.phone),
              const SizedBox(height: 30),
              _buildBigButton("INJECT CALL", Icons.rocket_launch, controller.makeCall, const Color(0xFF00FF9D)),
            ] else ...[
              // SIP ACCOUNT MODU
              if (controller.sipStatus != "REGISTERED") ...[
                const SizedBox(height: 20),
                _buildBigButton("REGISTER", Icons.how_to_reg, controller.registerAccount, Colors.blueAccent),
                const SizedBox(height: 12),
                Center(child: Text("Status: ${controller.sipStatus}", style: const TextStyle(color: Colors.white54, fontSize: 12))),
              ] else ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.check_circle, color: Colors.green, size: 18), SizedBox(width: 8), Text("REGISTERED SECURELY", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("DESTINATION", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                const SizedBox(height: 12),
                _input(controller.toController, "Target Extension (e.g., 2002)", Icons.call_made, keyboardType: TextInputType.phone),
                const SizedBox(height: 30),
                _buildBigButton("CALL", Icons.call, controller.makeCall, const Color(0xFF00FF9D)),
              ]
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBigButton(String text, IconData icon, VoidCallback onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 65,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 20, spreadRadius: 1)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(text, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 2.0)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveCallScreen(BuildContext context) {
    Color statusColor = controller.sipStatus == "CONNECTED" ? const Color(0xFF00FF9D) : Colors.orangeAccent;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          children: [
            Text(controller.toController.text, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 2.0)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withOpacity(0.5)),
              ),
              child: Text(controller.sipStatus, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: statusColor)),
            ),
            const SizedBox(height: 16),
            Text(controller.sipStatus == "CONNECTED" ? controller.formattedDuration : "Negotiating...", style: const TextStyle(fontSize: 18, color: Colors.white54, fontFamily: 'monospace')),
          ],
        ),

        Container(
          margin: const EdgeInsets.symmetric(horizontal: 30),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem("TX (EGRESS)", "${controller.txPackets}", Colors.white70),
              Icon(Icons.compare_arrows, color: controller.isMediaFlowing ? const Color(0xFF00FF9D) : Colors.white24, size: 28),
              _statItem("RX (INGRESS)", "${controller.rxPackets}", Colors.white70),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionBtn(Icons.mic_off, controller.isMuted ? "MUTED" : "MUTE", controller.isMuted, controller.toggleMute),
            const SizedBox(width: 20),
            _actionBtn(Icons.dialpad, "KEYPAD", false, () => _showDtmfPad(context)),
            const SizedBox(width: 20),
            _actionBtn(controller.isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk, "ROUTE", controller.isSpeakerOn, controller.toggleSpeaker),
          ],
        ),

        GestureDetector(
          onTap: controller.endCall, // DÜZELTİLDİ: Sadece kapatma
          child: Container(
            height: 80, width: 80,
            decoration: const BoxDecoration(
              color: Colors.redAccent, 
              shape: BoxShape.circle, 
              boxShadow: [BoxShadow(color: Color(0x66FF5252), blurRadius: 20, spreadRadius: 2)]
            ),
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
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : const Color(0xFF1A1A1A),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 26),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isCompact = false, TextInputType keyboardType = TextInputType.text, bool obscureText = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: TextStyle(fontSize: isCompact ? 13 : 15, fontFamily: 'monospace', color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: isCompact ? 11 : 13, color: Colors.white30, letterSpacing: 1.0),
        prefixIcon: Icon(icon, size: isCompact ? 16 : 20, color: Colors.white30),
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF00FF9D), width: 1.5)),
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: isCompact ? 6 : 16),
      ),
    );
  }

  Widget _statItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Text(val, style: TextStyle(fontSize: 20, color: color, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildConsole() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF090909),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF111111),
            child: const Row(
              children: [
                Icon(Icons.terminal, color: Colors.white30, size: 14),
                SizedBox(width: 8),
                Text("LIVE TELEMETRY STREAM", style: TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: controller.scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: controller.telemetryLogs.length,
              itemBuilder: (context, index) {
                final log = controller.telemetryLogs[index];
                Color color = Colors.white54;
                if (log.level == TelemetryLevel.status) color = const Color(0xFF00FF9D);
                if (log.level == TelemetryLevel.error) color = Colors.redAccent;
                if (log.level == TelemetryLevel.sipTx) color = Colors.blueAccent;  
                if (log.level == TelemetryLevel.sipRx) color = Colors.amberAccent; 

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("> ${log.message}", style: TextStyle(color: color, fontFamily: 'monospace', fontSize: 11)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}