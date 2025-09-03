// 📄 lib/screens/chat_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// adjust this import path if your app_scaffold.dart is in a different folder:
import '../widget/app_scaffold.dart';

// (optional) adjust these imports to your actual main tab pages if you want tab switching here.
// If your main/home/products/profile pages live elsewhere or have different names, update them.
import 'home_page.dart';
import 'products_page.dart';
import 'profile_page.dart';
import 'admin_dashboard.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // still wrap in AppScaffold so the header/nav show
      return AppScaffold(
        currentIndex: 2,
        isAdmin: false,
        onTabSelected: (i) => _handleTabSwitch(context, i),
        child: const Center(child: Text("Not signed in")),
      );
    }

    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(user.uid)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    return AppScaffold(
      currentIndex: 2,            // Messages tab
      isAdmin: false,             // set true if you detect admin for this user
      onTabSelected: (i) => _handleTabSwitch(context, i),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: messagesRef.snapshots(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "No updates yet",
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }

            final docs = snap.data!.docs;

            return Container(
              color: const Color(0xFFE6F2FA), // light “water” blue behind the list
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final text = (data['text'] ?? '').toString();
                  final type = (data['type'] ?? '').toString(); // 'accepted' | 'rejected' | etc.

                  IconData leading;
                  Color tint;
                  switch (type) {
                    case 'accepted':
                      leading = Icons.check_circle;
                      tint = Colors.green;
                      break;
                    case 'rejected':
                      leading = Icons.cancel;
                      tint = Colors.red;
                      break;
                    default:
                      leading = Icons.info_outline;
                      tint = Colors.blueGrey;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(leading, color: tint, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            text,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleTabSwitch(BuildContext context, int index) {
    // Avoid reloading if already on Messages
    if (index == 2) return;

    // 👉 Replace the route so we don’t stack infinite pages.
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProductsPage()),
        );
        break;
      case 3:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
        break;
      case 4:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
        break;
      default:
        break;
    }
  }
}
