import 'package:cloud_firestore/cloud_firestore.dart';

class ServerChannel {
  final String id;
  final String name;
  final String type; // 'text' | 'voice'
  final String subtype; // 'chat' | 'library' (chỉ áp dụng cho text)
  final int position;
  final String? icon; // emoji string, null = dùng icon mặc định theo type
  final int messageCount; // dùng để tính số tin chưa đọc

  ServerChannel({
    required this.id,
    required this.name,
    required this.type,
    required this.subtype,
    required this.position,
    this.icon,
    this.messageCount = 0,
  });

  bool get isText => type == 'text';
  bool get isVoice => type == 'voice';
  bool get isLibrary => type == 'text' && subtype == 'library';
  bool get isChat => type == 'text' && subtype == 'chat';

  factory ServerChannel.fromMap(Map<String, dynamic> map, String id) {
    final rawIcon = map['icon'] as String?;
    return ServerChannel(
      id: id,
      name: map['name'] ?? '',
      type: map['type'] ?? 'text',
      subtype: map['subtype'] ?? 'chat',
      position: map['position'] ?? 0,
      icon: (rawIcon == null || rawIcon.isEmpty) ? null : rawIcon,
      messageCount: (map['messageCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'type': type,
        'subtype': subtype,
        'position': position,
        if (icon != null) 'icon': icon,
        'messageCount': messageCount,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
