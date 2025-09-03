import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String orderId;
  final String customerId;
  final String adminId;
  final String lastMessage;
  final String lastSenderId;
  final DateTime updatedAt;
  final String status;

  ChatThread({
    required this.orderId,
    required this.customerId,
    required this.adminId,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
    required this.status,
  });

  factory ChatThread.fromMap(Map<String, dynamic> m) {
    final raw = m['updatedAt'];
    DateTime parsed;
    if (raw is Timestamp) {
      parsed = raw.toDate();
    } else if (raw is DateTime) {
      parsed = raw;
    } else {
      parsed = DateTime.now();
    }

    return ChatThread(
      orderId: m['orderId'] ?? '',
      customerId: m['customerId'] ?? '',
      adminId: m['adminId'] ?? '',
      lastMessage: m['lastMessage'] ?? '',
      lastSenderId: m['lastSenderId'] ?? '',
      updatedAt: parsed,
      status: m['status'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'orderId': orderId,
    'customerId': customerId,
    'adminId': adminId,
    'lastMessage': lastMessage,
    'lastSenderId': lastSenderId,
    'updatedAt': updatedAt,
    'status': status,
  };
}
