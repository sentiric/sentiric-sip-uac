// Dosya: sentiric-sip-uac/lib/ui/screens/dialer_screen.dart
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
        final keys =['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
        return Container(
          padding: const EdgeInsets.all(24),
          height: 400,
          child: Column(
            children:[
              const Text("DTMF KEYPAD", style: TextStyle(color: Color(0xFF00FF9D), letterSpacing: 2.0, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
                  itemCount: keys.length,
                  itemBuilder: (context, index) {
                    return InkWell(
                      onTap: () { controller.sendDtmf(keys[index]); Navigator.pop(context); },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)), alignment: Alignment.center, child: Text(keys[index], style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.w300))),
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
            title: Text(controller.activeProfile?.name ?? "No Profile", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: controller.isCalling ? null : IconButton(
              icon: Icon(Icons.how_to_reg, color: controller.sipStatus == "REGISTERED" ? const Color(0xFF00FF9D) : Colors.white54),
              onPressed: controller.registerAccount,
            ),
            actions:[
              IconButton(onPressed: controller.toggleDebugConsole, icon: Icon(Icons.terminal, color: controller.showDebugConsole ? const Color(0xFF00FF9D) : Colors.white30))
            ],
          ),
          body: SafeArea(
            child: Column(
              children:[
                if (!controller.isCalling) Expanded(child: _buildDialpad(context)),
                if (controller.isCalling) Expanded(child: _buildActiveCallScreen(context)),
                if (controller.showDebugConsole) Expanded(child: _buildConsole()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialpad(BuildContext context) {
    final keys =['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children:[
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            controller.dialedNumber.isEmpty ? "Enter Number" : controller.dialedNumber,
            style: TextStyle(fontSize: 36, color: controller.dialedNumber.isEmpty ? Colors.white24 : Colors.white, letterSpacing: 2.0, fontFamily: 'monospace'),
          ),
        ),
        Text("Status: ${controller.sipStatus}", style: TextStyle(color: controller.sipStatus == "REGISTERED" ? Colors.green : Colors.white54, fontSize: 12)),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: keys.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => controller.appendDial(keys[index]),
                borderRadius: BorderRadius.circular(40),
                child: Container(alignment: Alignment.center, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF1A1A1A)), child: Text(keys[index], style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.w300))),
              );
            },
          ),
        ),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:[
            const SizedBox(width: 50),
            GestureDetector(
              onTap: () => controller.makeCall(controller.dialedNumber),
              child: Container(height: 75, width: 75, decoration: BoxDecoration(color: const Color(0xFF00FF9D).withOpacity(0.2), shape: BoxShape.circle, border: Border.all(color: const Color(0xFF00FF9D), width: 2)), child: const Icon(Icons.call, color: Color(0xFF00FF9D), size: 36)),
            ),
            GestureDetector(
              onTap: controller.backspaceDial,
              onLongPress: () { while(controller.dialedNumber.isNotEmpty) { controller.backspaceDial(); } },
              child: const SizedBox(height: 50, width: 50, child: Icon(Icons.backspace, color: Colors.white54, size: 24)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildActiveCallScreen(BuildContext context) {
    if (controller.sipStatus == "INCOMING CALL") {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            const Icon(Icons.ring_volume, size: 80, color: Color(0xFF00FF9D)),
            const SizedBox(height: 40),
            Text(controller.incomingCaller, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w200, color: Colors.white)),
            const SizedBox(height: 80),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children:[
                GestureDetector(onTap: controller.rejectCall, child: Container(height: 75, width: 75, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.call_end, color: Colors.white, size: 36))),
                GestureDetector(onTap: controller.answerCall, child: Container(height: 75, width: 75, decoration: const BoxDecoration(color: Color(0xFF00FF9D), shape: BoxShape.circle), child: const Icon(Icons.call, color: Colors.black, size: 36))),
              ],
            )
          ],
        );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children:[
        Column(
          children:[
            Text(controller.currentCallTarget, style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w200, color: Colors.white, letterSpacing: 2.0)),
            const SizedBox(height: 12),
            Text(controller.sipStatus, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Color(0xFF00FF9D))),
            const SizedBox(height: 16),
            Text(controller.sipStatus == "CONNECTED" ? controller.formattedDuration : "Negotiating...", style: const TextStyle(fontSize: 18, color: Colors.white54, fontFamily: 'monospace')),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:[
            _actionBtn(Icons.mic_off, "MUTE", controller.isMuted, controller.toggleMute),
            const SizedBox(width: 30),
            _actionBtn(Icons.dialpad, "KEYPAD", false, () => _showDtmfPad(context)),
            const SizedBox(width: 30),
            _actionBtn(controller.isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk, "SPEAKER", controller.isSpeakerOn, controller.toggleSpeaker),
          ],
        ),
        GestureDetector(
          onTap: controller.endCall, 
          child: Container(height: 80, width: 80, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle), child: const Icon(Icons.call_end, color: Colors.white, size: 36)),
        ),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children:[
          Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: isActive ? Colors.white : const Color(0xFF1A1A1A), shape: BoxShape.circle), child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 26)),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.white54, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
        ],
      ),
    );
  }

  Widget _buildConsole() {
    return Container(
      color: const Color(0xFF090909),
      child: ListView.builder(
        controller: controller.scrollController,
        padding: const EdgeInsets.all(12),
        itemCount: controller.telemetryLogs.length,
        itemBuilder: (context, index) {
          final log = controller.telemetryLogs[index];
          return Text("> ${log.message}", style: TextStyle(color: log.level == TelemetryLevel.error ? Colors.red : Colors.white54, fontFamily: 'monospace', fontSize: 11));
        },
      ),
    );
  }
}