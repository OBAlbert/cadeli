import 'package:cloud_firestore/cloud_firestore.dart';

class ChatThread {
  final String orderId;
  final String customerId;
  final String adminId;
  final String lastMessage;
  final String lastSenderId;
  final DateTime updatedAt;
  final String status;                 // 'pending' | 'active' | 'rejected' | ''
  final int unreadForAdmin;
  final int unreadForCustomer;
  final String customerEmail;
  final List<String> participants;

  ChatThread({
    required this.orderId,
    required this.customerId,
    required this.adminId,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
    required this.status,
    required this.unreadForAdmin,
    required this.unreadForCustomer,
    required this.customerEmail,
    required this.participants,
  });

  static DateTime _parseTime(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    return DateTime.now();
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  factory ChatThread.fromMap(Map<String, dynamic> m) {
    return ChatThread(
      orderId: (m['orderId'] ?? '').toString(),
      customerId: (m['customerId'] ?? '').toString(),
      adminId: (m['adminId'] ?? '').toString(),
      lastMessage: (m['lastMessage'] ?? '').toString(),
      lastSenderId: (m['lastSenderId'] ?? '').toString(),
      updatedAt: _parseTime(m['updatedAt']),
      status: (m['status'] ?? '').toString(),
      unreadForAdmin: _toInt(m['unreadForAdmin']),
      unreadForCustomer: _toInt(m['unreadForCustomer']),
      customerEmail: (m['customerEmail'] ?? '').toString(),
      participants: ((m['participants'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
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
    'unreadForAdmin': unreadForAdmin,
    'unreadForCustomer': unreadForCustomer,
    'customerEmail': customerEmail,
    'participants': participants,
  };

  bool get isPending => status == 'pending';
  bool get isActive  => status == 'active';
  bool get isRejected=> status == 'rejected';
  int unreadFor({required bool isAdmin}) =>
      isAdmin ? unreadForAdmin : unreadForCustomer;
}
