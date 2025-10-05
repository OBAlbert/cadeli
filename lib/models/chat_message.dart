import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final String type;        // 'text' | 'system' | ...
  final String senderRole;  // 'user' | 'system'

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.type,
    required this.senderRole,
  });

  bool get isSystem => type == 'system' || senderRole == 'system';

  static DateTime _parseTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.now();
  }

  factory ChatMessage.fromMap(String id, Map<String, dynamic> m) {
    final type = (m['type'] ?? 'text').toString();
    final role = (m['senderRole'] ?? (type == 'system' ? 'system' : 'user')).toString();

    return ChatMessage(
      id: id,
      senderId: (m['senderId'] ?? '').toString(),
      text: (m['text'] ?? '').toString(),
      createdAt: _parseTime(m['createdAt']),
      type: type,
      senderRole: role,
    );
  }

  Map<String, dynamic> toMap() => {
    'senderId': senderId,
    'text': text,
    'createdAt': createdAt,   // Firestore SDK converts DateTime → Timestamp
    'type': type,
    'senderRole': senderRole,
  };
}
