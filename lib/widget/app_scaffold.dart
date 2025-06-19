// ✅ Step-by-step FIX to your GlobalKey conflict and cart animation issues

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_inset_box_shadow/flutter_inset_box_shadow.dart' as inset;
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../screens/cart_page.dart';
import '../screens/chat_page.dart';
import '../models/cart_provider.dart';

// ✅ 1. Declare the global cartIconKey ONCE
GlobalKey getCartIconKeyInstance() => GlobalKey(debugLabel: 'cartIconKey_unique');

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
          Consumer<CartProvider>(
            builder: (context, cart, _) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    key: getCartIconKeyInstance(),
                    icon: const Icon(Icons.shopping_cart_outlined),
                    tooltip: "Cart",
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartPage()),
                      );
                    },
                  ),
                  if (cart.cartItems.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        child: Text(
                          '${cart.totalItems}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                inset.BoxShadow(
                  color: Color.fromRGBO(255, 255, 255, 0.08),
                  offset: Offset(0, 1),
                  blurRadius: 1.5,
                  inset: true,
                ),
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
                if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatPage()),
                  );
                } else {
                  onTabSelected(index);
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
