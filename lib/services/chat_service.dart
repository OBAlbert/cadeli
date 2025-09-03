import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();
  final _db = FirebaseFirestore.instance;

  /// Get or create the chat doc using orderId as the docId.
  Future<void> ensureChat({
    required String orderId,
    required String customerId,
    required String adminId,
    String status = '',
  }) async {
    final ref = _db.collection('chats').doc(orderId);
    final snap = await ref.get();

    // Try to capture an email once (for admin convenience)
    String? email;
    try {
      email = FirebaseAuth.instance.currentUser?.email;
      // If you ever run this on server/admin, you can also read users/{uid}.email
    } catch (_) {}

    if (!snap.exists) {
      await ref.set({
        'orderId': orderId,
        'customerId': customerId,
        'adminId': adminId,
        'customerEmail': email ?? '',
        'participants': [customerId, adminId], // handy if you later query by array-contains
        'lastMessage': '',
        'lastSenderId': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'status': status,
      }, SetOptions(merge: true));
    } else {
      // keep things fresh (important for list sorting)
      final data = snap.data() ?? {};
      final alreadyHasEmail = (data['customerEmail'] ?? '').toString().isNotEmpty;

      await ref.set({
        if (!alreadyHasEmail && (email ?? '').isNotEmpty) 'customerEmail': email,
        if (status.isNotEmpty) 'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Stream the current user’s chat threads (user or admin).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamChatsForUser(String uid, {bool isAdmin = false}) {
    final q = isAdmin
        ? _db.collection('chats').orderBy('updatedAt', descending: true)
        : _db.collection('chats')
        .where('customerId', isEqualTo: uid)
        .orderBy('updatedAt', descending: true);
    return q.snapshots();
  }

  /// Stream messages for one chat (order).
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String orderId) {
    return _db
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Send a text message.
  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String text,
  }) async {
    final ref = _db.collection('chats').doc(orderId);
    final msgRef = ref.collection('messages').doc();
    final now = FieldValue.serverTimestamp();

    await msgRef.set({
      'senderId': senderId,
      'text': text,
      'createdAt': now,
      'type': 'text',
    });

    await ref.set({
      'lastMessage': text,
      'lastSenderId': senderId,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  /// Convenience: send a system message (timestamps + list ordering maintained).
  Future<void> sendSystem(String orderId, String text) async {
    final ref = _db.collection('chats').doc(orderId);
    final msgRef = ref.collection('messages').doc();
    final now = FieldValue.serverTimestamp();
    await msgRef.set({
      'senderId': 'system',
      'text': text,
      'createdAt': now,
      'type': 'system',
    });
    await ref.set({
      'lastMessage': text,
      'lastSenderId': 'system',
      'updatedAt': now,
    }, SetOptions(merge: true));
  }
}
