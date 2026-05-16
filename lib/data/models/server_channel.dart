import 'package:cloud_firestore/cloud_firestore.dart';

class ServerChannel {
  final String id;
  final String name;
  final String type; // 'text' | 'voice'
  final String subtype; // 'chat' | 'library' (chỉ áp dụng cho text)
  final int position;

  ServerChannel({
    required this.id,
    required this.name,
    required this.type,
    required this.subtype,
    required this.position,
  });

  bool get isText => type == 'text';
  bool get isVoice => type == 'voice';
  bool get isLibrary => type == 'text' && subtype == 'library';
  bool get isChat => type == 'text' && subtype == 'chat';

  factory ServerChannel.fromMap(Map<String, dynamic> map, String id) {
    return ServerChannel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? 'text',
      subtype: map['subtype'] ?? 'chat',
      position: map['position'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'subtype': subtype,
        'position': position,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
