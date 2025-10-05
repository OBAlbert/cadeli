import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  ChatService._();
  static final instance = ChatService._();
  final _db = FirebaseFirestore.instance;

  // ---------- Admin list from /config/admins ----------
  List<String>? _cachedAdminUids;

  Future<List<String>> _adminUids() async {
    if (_cachedAdminUids != null) return _cachedAdminUids!;
    try {
      final doc = await _db.collection('config').doc('admins').get();
      final list = (doc.data()?['uids'] as List?)
          ?.map((e) => e.toString())
          .toList() ??
          const <String>[];
      _cachedAdminUids = list;

      // DEBUG
      // ignore: avoid_print
      print('[ChatService] adminUids = ${list.join(",")}');

      return list;
    } catch (e) {
      // ignore: avoid_print
      print('[ChatService] failed to load adminUids: $e');
      return const <String>[];
    }
  }

  // ---------- Ensure a chat doc exists and contains participants ----------
  Future<void> ensureChat({
    required String orderId,
    required String customerId,
    required String adminId, // kept for compatibility; not used now
    String? status,
  }) async {
    final ref = _db.collection('chats').doc(orderId);

    // participants = customer + ALL admin UIDs from /config/admins
    final admins = await _adminUids();
    final participants = <String>{customerId, ...admins}.toList();

    String? email;
    try {
      email = FirebaseAuth.instance.currentUser?.email;
    } catch (_) {}

    final data = <String, dynamic>{
      'orderId': orderId,
      'customerId': customerId,
      'customerEmail': email ?? '',
      'participants': participants,                 // <-- IMPORTANT
      if (status != null) 'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // DEBUG
    // ignore: avoid_print
    print('[ChatService] ensureChat order=$orderId participants=$participants');

    await ref.set(data, SetOptions(merge: true));
  }

  // ---------- List chats for the current user ----------
  // Everyone (admin/customer) uses the SAME query: "I'm in participants"
  Stream<QuerySnapshot<Map<String, dynamic>>> streamChatsForUser(
      String uid, {
        bool isAdmin = false, // kept to not break callers; no effect now
      }) {
    final q = _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true);

    // DEBUG
    // ignore: avoid_print
    print('[ChatService] streamChatsForUser uid=$uid');

    return q.snapshots();
  }

  // ---------- Messages ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> streamMessages(String orderId) {
    return _db
        .collection('chats')
        .doc(orderId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();
  }

  Future<void> sendMessage({
    required String orderId,
    required String senderId,
    required String text,
  }) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final ref = _db.collection('chats').doc(orderId);
    final now = FieldValue.serverTimestamp();

    await ref.collection('messages').add({
      'senderId': senderId,
      'senderRole': senderId == 'system' ? 'system' : 'user',
      'text': t,
      'type': 'text',
      'createdAt': now,
    });

    await ref.set(
      {'lastMessage': t, 'lastSenderId': senderId, 'updatedAt': now},
      SetOptions(merge: true),
    );
  }

  Future<void> sendSystem(String orderId, String text,
      {String sender = 'system'}) async {
    final t = text.trim();
    if (t.isEmpty) return;

    final ref = _db.collection('chats').doc(orderId);
    final now = FieldValue.serverTimestamp();

    await ref.collection('messages').add({
      'senderId': sender,
      'senderRole': 'system',
      'text': t,
      'type': 'system',
      'createdAt': now,
    });

    await ref.set(
      {'lastMessage': t, 'lastSenderId': sender, 'updatedAt': now},
      SetOptions(merge: true),
    );
  }

  Future<void> markThreadRead(String orderId, {required bool isAdmin}) async {
    await _db.collection('chats').doc(orderId).set(
      isAdmin ? {'unreadForAdmin': 0} : {'unreadForCustomer': 0},
      SetOptions(merge: true),
    );
  }
}
