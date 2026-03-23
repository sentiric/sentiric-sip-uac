// Dosya: lib/ui/screens/dashboard_screens.dart
import 'package:flutter/material.dart';
import '../../controllers/call_controller.dart';
import '../../models.dart';

class ProfilesScreen extends StatelessWidget {
  final CallController controller;
  const ProfilesScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text("SIP PROFILES", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Colors.transparent),
          body: ListView.builder(
            itemCount: controller.profiles.length,
            itemBuilder: (context, index) {
              final p = controller.profiles[index];
              final isActive = controller.activeProfile?.id == p.id;
              return ListTile(
                leading: Icon(p.isTrunk ? Icons.dns : Icons.person, color: isActive ? const Color(0xFF00FF9D) : Colors.white54),
                title: Text(p.name, style: TextStyle(color: isActive ? const Color(0xFF00FF9D) : Colors.white)),
                subtitle: Text(p.isTrunk ? "Trunk Target: ${p.ip}:${p.port}" : "Account: ${p.user}@${p.ip}:${p.port}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children:[
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blueAccent),
                      onPressed: () => _showAddProfile(context, existingProfile: p),
                    ),
                    if (!isActive) IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white24),
                      onPressed: () { controller.profiles.removeAt(index); controller.saveState(); },
                    ),
                    if (isActive) const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Icon(Icons.check_circle, color: Color(0xFF00FF9D)),
                    ),
                  ],
                ),
                onTap: () => controller.loadProfile(p),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF00FF9D),
            child: const Icon(Icons.add, color: Colors.black),
            onPressed: () => _showAddProfile(context),
          ),
        );
      }
    );
  }

  //[MİMARİ DÜZELTME]: Edit yeteneği ve Trunk modu için dinamik label eklendi
  void _showAddProfile(BuildContext context, {SipProfile? existingProfile}) {
    final nameC = TextEditingController(text: existingProfile?.name ?? "");
    final ipC = TextEditingController(text: existingProfile?.ip ?? "");
    final portC = TextEditingController(text: existingProfile?.port ?? "5060");
    final userC = TextEditingController(text: existingProfile?.user ?? "");
    final passC = TextEditingController(text: existingProfile?.password ?? "");
    bool isTrunk = existingProfile?.isTrunk ?? false;

    showDialog(context: context, builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: Text(existingProfile == null ? "New Profile" : "Edit Profile", style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children:[
            TextField(controller: nameC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Profile Name (e.g. Prod 1)")),
            TextField(controller: ipC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "IP / Domain")),
            TextField(controller: portC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Port")),
            SwitchListTile(
              title: const Text("Raw Trunk Mode", style: TextStyle(color: Colors.white)),
              subtitle: const Text("Direct IP Call without Register", style: TextStyle(color: Colors.white54, fontSize: 10)),
              value: isTrunk,
              activeColor: const Color(0xFF00FF9D),
              onChanged: (val) => setState(() => isTrunk = val)
            ),
            // Trunk modunda Caller ID, Account modunda SIP Username
            TextField(controller: userC, style: const TextStyle(color: Colors.white), decoration: InputDecoration(labelText: isTrunk ? "Caller ID Number" : "SIP Username")),
            if (!isTrunk) ...[
              TextField(controller: passC, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Password")),
            ]
          ]),
        ),
        actions:[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
          TextButton(onPressed: () {
            if (nameC.text.isNotEmpty && ipC.text.isNotEmpty) {
              if (existingProfile != null) {
                // Update
                existingProfile.name = nameC.text;
                existingProfile.ip = ipC.text;
                existingProfile.port = portC.text;
                existingProfile.user = userC.text;
                existingProfile.password = isTrunk ? "" : passC.text;
                existingProfile.isTrunk = isTrunk;
              } else {
                // Add
                controller.profiles.add(SipProfile(id: DateTime.now().millisecondsSinceEpoch.toString(), name: nameC.text, ip: ipC.text, port: portC.text, user: userC.text, password: isTrunk ? "" : passC.text, isTrunk: isTrunk));
              }
              controller.saveState();
              Navigator.pop(context);
            }
          }, child: const Text("SAVE", style: TextStyle(color: Color(0xFF00FF9D))))
        ],
      )
    ));
  }
}

class ContactsScreen extends StatelessWidget {
  final CallController controller;
  const ContactsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final myContacts = controller.activeContacts; 
        return Scaffold(
          appBar: AppBar(title: Text("PHONEBOOK (${controller.activeProfile?.name})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0)), backgroundColor: Colors.transparent),
          body: myContacts.isEmpty ? const Center(child: Text("No contacts for this profile.", style: TextStyle(color: Colors.white24))) : ListView.builder(
            itemCount: myContacts.length,
            itemBuilder: (context, index) {
              final c = myContacts[index];
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFF1A1A1A), child: Icon(Icons.person, color: Colors.white)),
                title: Text(c.name),
                subtitle: Text(c.number),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children:[
                    IconButton(icon: const Icon(Icons.delete, color: Colors.white24), onPressed: () => controller.removeContact(c.id)),
                    IconButton(icon: const Icon(Icons.call, color: Color(0xFF00FF9D)), onPressed: () => controller.makeCall(c.number)),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: const Color(0xFF00FF9D),
            child: const Icon(Icons.person_add, color: Colors.black),
            onPressed: () {
              final nC = TextEditingController();
              final numC = TextEditingController();
              showDialog(context: context, builder: (c) => AlertDialog(
                backgroundColor: const Color(0xFF111111),
                title: const Text("Add Contact", style: TextStyle(color: Colors.white)),
                content: Column(mainAxisSize: MainAxisSize.min, children:[
                  TextField(controller: nC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Name")),
                  TextField(controller: numC, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "Target Ext / Number")),
                ]),
                actions:[
                  TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.white54))),
                  TextButton(onPressed: () {
                    if(nC.text.isNotEmpty && numC.text.isNotEmpty) {
                      controller.addContact(nC.text, numC.text);
                      Navigator.pop(c);
                    }
                  }, child: const Text("SAVE", style: TextStyle(color: Color(0xFF00FF9D))))
                ],
              ));
            },
          ),
        );
      }
    );
  }
}

class HistoryScreen extends StatelessWidget {
  final CallController controller;
  const HistoryScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final myHistory = controller.activeHistory; 
        return Scaffold(
          appBar: AppBar(
            title: Text("HISTORY (${controller.activeProfile?.name})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0)), 
            backgroundColor: Colors.transparent,
            actions:[
              IconButton(icon: const Icon(Icons.delete_sweep, color: Colors.white24), onPressed: controller.clearActiveHistory)
            ],
          ),
          body: myHistory.isEmpty ? const Center(child: Text("No history for this profile.", style: TextStyle(color: Colors.white24))) : ListView.builder(
            itemCount: myHistory.length,
            itemBuilder: (context, index) {
              final h = myHistory[index];
              IconData icon = Icons.call_made;
              Color color = Colors.white54;
              if (h.direction == "IN") {
                icon = h.status == "MISSED" ? Icons.call_missed : Icons.call_received;
                color = h.status == "MISSED" ? Colors.redAccent : Colors.blueAccent;
              } else {
                color = h.status == "ANSWERED" ? const Color(0xFF00FF9D) : Colors.white54;
              }
              // Geçmişte rehber ismi göstermek için arama
              final contact = controller.activeContacts.where((c) => c.number == h.targetNumber).firstOrNull;
              final displayName = contact != null ? contact.name : h.targetNumber;

              return ListTile(
                leading: Icon(icon, color: color),
                title: Text(displayName),
                subtitle: Text("${h.timestamp.toLocal().toString().split('.')[0]} • ${h.status}"),
                trailing: Text("${h.durationSeconds}s", style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, color: Colors.white70)),
                onTap: () => controller.makeCall(h.targetNumber),
              );
            },
          ),
        );
      }
    );
  }
}