import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/chat_thread.dart';
import '../services/chat_service.dart';
import 'chat_thread_page.dart';
import '../widget/app_scaffold.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key, this.isAdmin = false});
  final bool isAdmin;


  // route helper for bottom tabs
  void _goTab(BuildContext context, int i) {
    // replace these with your real named routes if different
    const routes = ['/home', '/products', '/messages', '/profile'];

    if (i == 2) {
      // Messages tab → open list explicitly
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatListPage()),
      );
      return;
    }
    if (i >= 0 && i < routes.length) {
      Navigator.of(context).pushReplacementNamed(routes[i]);
    }
  }


  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return AppScaffold(
      currentIndex: 2, // Messages tab
      onTabSelected: (i) => _goTab(context, i),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: Image.asset('assets/background/fade_base.jpg', fit: BoxFit.cover)),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ChatService.instance.streamChatsForUser(uid, isAdmin: isAdmin),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      isAdmin ? 'No active order chats yet.' : 'No chats yet. Place an order to begin.',
                      style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final t = ChatThread.fromMap(m);
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
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
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                        ),
                        child: Row(
                          children: [
                            // existing leading icon + Expanded(...) block stays as-is above
                            const SizedBox(width: 8),

                            // ⬇️ ADD THIS STATUS CHIP
                            if ((m['status'] ?? '').toString().isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 6),
                                child: Chip(
                                  label: Text(
                                    (m['status'] as String).toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  padding: EdgeInsets.zero,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: ((m['status'] ?? '') == 'pending')
                                      ? Colors.orange.withOpacity(0.15)
                                      : Colors.green.withOpacity(0.15),
                                  side: BorderSide(
                                    color: ((m['status'] ?? '') == 'pending')
                                        ? Colors.orange
                                        : Colors.green,
                                    width: 0.6,
                                  ),
                                ),
                              ),

                            const Icon(Icons.chevron_right, color: Colors.black45),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
