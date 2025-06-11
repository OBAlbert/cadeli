import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_inset_box_shadow/flutter_inset_box_shadow.dart' as inset;
import 'package:collection/collection.dart';

// Replace with your real pages
import '../screens/cart_page.dart';
import '../screens/chat_page.dart'; // Placeholder chat screen

class AppScaffold extends StatelessWidget {
  final int currentIndex;
  final Widget child;
  final Function(int) onTabSelected;
  final bool isAdmin;

  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabSelected,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    // Define bottom nav items (Chat replaces Cart, Products icon updated)
    final items = [
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
      const BottomNavigationBarItem(icon: Icon(Icons.local_drink_outlined), label: "Products"),
      const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
    ];

    if (isAdmin) {
      items.insert(4, const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Admin"));
    }

    return Scaffold(
      // Main App Bar (with Cart icon top-right)
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A2D3D),
        title: const Row(
          children: [
            Icon(Icons.water_drop, color: Colors.lightBlueAccent),
            SizedBox(width: 10),
            Text(
              "Cadeli",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
          ],
        ),
        actions: [
          // Cart icon in top-right corner
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: "Cart",
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CartPage()),
              );
            },
          ),
        ],
      ),

      body: SafeArea(child: child),

      // GLASSY BOTTOM NAVIGATION BAR
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Main blur effect
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // Slim internal space
            decoration: BoxDecoration(
              color: const Color.fromRGBO(255, 255, 255, 0.08),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.fromRGBO(255, 255, 255, 0.12),
                  Color.fromRGBO(255, 255, 255, 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 0.8,
              ),
              boxShadow: const [
                // Soft white inner highlight
                inset.BoxShadow(
                  color: Color.fromRGBO(255, 255, 255, 0.08),
                  offset: Offset(0, 1),
                  blurRadius: 1.5,
                  inset: true,
                ),
                // Soft black inner depth
                inset.BoxShadow(
                  color: Color.fromRGBO(0, 0, 0, 0.15),
                  offset: Offset(0, -1),
                  blurRadius: 2,
                  inset: true,
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) {
                // Handle navigation to ChatPage for index 2
                if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatPage()),
                  );
                } else {
                  onTabSelected(index); // Trigger parent state update
                }
              },
              backgroundColor: Colors.transparent,
              selectedItemColor: Colors.lightBlueAccent,
              unselectedItemColor: Colors.white60,
              selectedFontSize: 12,
              unselectedFontSize: 11,
              iconSize: 24,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: items.mapIndexed((i, item) {
                final isSelected = i == currentIndex;
                return BottomNavigationBarItem(
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: isSelected
                        ? BoxDecoration(
                      color: Colors.lightBlueAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                    )
                        : null,
                    child: item.icon,
                  ),
                  label: item.label,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
