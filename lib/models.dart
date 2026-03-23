// Dosya: sentiric-sip-uac/lib/models.dart
import 'dart:convert';

class SipProfile {
  String id;
  String name;
  String ip;
  String port;
  String user;
  String password;
  bool isTrunk;

  SipProfile({required this.id, required this.name, required this.ip, required this.port, required this.user, required this.password, required this.isTrunk});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'ip': ip, 'port': port, 'user': user, 'password': password, 'isTrunk': isTrunk};
  factory SipProfile.fromJson(Map<String, dynamic> json) => SipProfile(id: json['id']??'', name: json['name']??'', ip: json['ip']??'', port: json['port']??'5060', user: json['user']??'', password: json['password']??'', isTrunk: json['isTrunk']??false);
}

class PhoneContact {
  String id;
  String profileId; // PROFIL İZOLASYONU
  String name;
  String number;
  PhoneContact({required this.id, required this.profileId, required this.name, required this.number});
  Map<String, dynamic> toJson() => {'id': id, 'profileId': profileId, 'name': name, 'number': number};
  factory PhoneContact.fromJson(Map<String, dynamic> json) => PhoneContact(id: json['id']??'', profileId: json['profileId']??'default', name: json['name']??'', number: json['number']??'');
}

class CallRecord {
  String id;
  String profileId; // PROFIL İZOLASYONU
  String targetNumber;
  String direction; 
  String status;    
  int durationSeconds;
  DateTime timestamp;

  CallRecord({required this.id, required this.profileId, required this.targetNumber, required this.direction, required this.status, required this.durationSeconds, required this.timestamp});
  Map<String, dynamic> toJson() => {'id': id, 'profileId': profileId, 'targetNumber': targetNumber, 'direction': direction, 'status': status, 'durationSeconds': durationSeconds, 'timestamp': timestamp.toIso8601String()};
  factory CallRecord.fromJson(Map<String, dynamic> json) => CallRecord(id: json['id']??'', profileId: json['profileId']??'default', targetNumber: json['targetNumber']??'', direction: json['direction']??'', status: json['status']??'', durationSeconds: json['durationSeconds']??0, timestamp: DateTime.parse(json['timestamp']));
}