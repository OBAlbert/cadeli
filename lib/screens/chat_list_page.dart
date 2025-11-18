import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_thread.dart';
import '../services/chat_service.dart';
import 'chat_thread_page.dart';
import '../services/hidden_chats_store.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key, this.isAdmin = false});
  final bool isAdmin;

  String _fmtWhen(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    final now = DateTime.now();
    final sameDay = d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
      final m = d.minute.toString().padLeft(2, '0');
      final ap = d.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    }
    return '${d.day}/${d.month}';
  }

  Color _statusBg(String s) {
    switch (s) {
      case 'pending': return const Color(0xFFFFE9C6);
      case 'active':  return const Color(0xFFDFF7E3);
      case 'rejected':return const Color(0xFFFDE2E1);
      default:        return const Color(0xFFEFEFEF);
    }
  }

  Color _statusFg(String s) {
    switch (s) {
      case 'pending': return const Color(0xFFBE7A00);
      case 'active':  return const Color(0xFF116C3E);
      case 'rejected':return const Color(0xFFAA1D1D);
      default:        return const Color(0xFF444444);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: Image.asset('assets/background/fade_base.jpg', fit: BoxFit.cover)),
        SafeArea(
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, userSnap) {
              final user = userSnap.data;
              if (user == null) {
                return const Center(
                  child: Text(
                    'Sign in to view chats',
                    style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                  ),
                );
              }
              final uid = user.uid;

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ChatService.instance.streamChatsForUser(uid, isAdmin: isAdmin),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text('Chats error: ${snap.error}', style: const TextStyle(color: Colors.red)),
                        ),
                      );
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];

                    return FutureBuilder<Set<String>>(
                      future: HiddenChatsStore.get(),
                      builder: (context, hiddenSnap) {
                        final hidden = hiddenSnap.data ?? const <String>{};
                        final visible = docs.where((d) => !hidden.contains(d.id)).toList();

                        if (visible.isEmpty) {
                          return Center(
                            child: Text(
                              isAdmin ? 'No active order chats yet.' : 'No chats yet. Place an order to begin.',
                              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: visible.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final doc = visible[i];
                            final m = doc.data();
                            final t = ChatThread.fromMap({...m, 'orderId': m['orderId'] ?? doc.id});
                            final status = (m['status'] ?? '').toString();
                            final updatedAt = m['updatedAt'] is Timestamp ? m['updatedAt'] as Timestamp : null;
                            final unread = isAdmin
                                ? (m['unreadForAdmin'] ?? 0) as int
                                : (m['unreadForCustomer'] ?? 0) as int;

                            final tile = InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () async {
                                await ChatService.instance.markThreadRead(t.orderId, isAdmin: isAdmin);
                                // open thread
                                // ignore: use_build_context_synchronously
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatThreadPage(
                                      orderId: t.orderId,
                                      customerId: t.customerId,
                                      isAdminView: isAdmin,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7F9FC),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.7)),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8))],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      height: 44, width: 44, alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A233D).withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.receipt_long, color: Color(0xFF1A233D)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Order #${t.orderId}',
                                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0E1A36)),
                                                ),
                                              ),
                                              if (updatedAt != null)
                                                Text(_fmtWhen(updatedAt), style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            t.lastMessage.isNotEmpty ? t.lastMessage : 'No messages yet',
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                                          ),
                                          if ((m['customerEmail'] ?? '').toString().isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(m['customerEmail'], maxLines: 1, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 12, color: Colors.black45)),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (status.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _statusBg(status),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: _statusFg(status).withOpacity(0.7), width: 0.6),
                                        ),
                                        child: Text(status.toUpperCase(),
                                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusFg(status))),
                                      ),
                                    if (unread > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: const Color(0xFF0DBA4B), borderRadius: BorderRadius.circular(12)),
                                        child: Text('$unread', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                    const SizedBox(width: 6),
                                    const Icon(Icons.chevron_right, color: Colors.black45),
                                  ],
                                ),
                              ),
                            );

                            return Dismissible(
                              key: ValueKey(doc.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.redAccent,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              confirmDismiss: (_) async {
                                await HiddenChatsStore.add(doc.id);
                                // ignore: use_build_context_synchronously
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat hidden on this device')));
                                return true;
                              },
                              child: tile,
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
