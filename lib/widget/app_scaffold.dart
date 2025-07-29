// 📄 app_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/cart_provider.dart';
import '../screens/cart_page.dart';
import '../screens/chat_page.dart';
import '../screens/info_page.dart';
import '../screens/search_overlay_page.dart';
import '../screens/search_page.dart';
import '../screens/admin_dashboard.dart';
import 'address_dropdown.dart';
import 'custom_bottom_nav_bar.dart';

GlobalKey getCartIconKeyInstance() => GlobalKey(debugLabel: 'cartIconKey_unique');

class AppScaffold extends StatelessWidget {
  final int currentIndex;
  final Widget child;
  final Function(int) onTabSelected;
  final bool isAdmin;
  final bool hideNavigationBar;


  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabSelected,
    this.isAdmin = false,
    this.hideNavigationBar = false,
  });

  /// 🔍 Fetches the user's first name from Firestore
  Future<String> _getUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'there';
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final fullName = doc.data()?['fullName'] ?? '';
    return fullName.toString().split(' ').first.isNotEmpty ? fullName.toString().split(' ').first : 'there';
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      BottomNavItem(
        icon: Icons.home,
        label: "Home",
      ),
      BottomNavItem(
        icon: Icons.inventory_2,
        label: "Products",
      ),
      BottomNavItem(
        icon: Icons.chat_bubble_outline,
        label: "Messages",
      ),
      BottomNavItem(
        icon: Icons.person_outline,
        label: "Profile",
      ),
    ];

    if (isAdmin) {
      items.add(BottomNavItem(
        icon: Icons.admin_panel_settings_outlined,
        label: "Admin",
      ));
    }

    return Scaffold(
      extendBody: true,


      /// 🧊 Frosted AppBar with greeting and dropdown
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(context).size.height * 0.12),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width * 0.04,
                MediaQuery.of(context).padding.top + 8,
                MediaQuery.of(context).size.width * 0.03,
                6
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color.fromRGBO(255, 255, 255, 0.12), Color.fromRGBO(255, 255, 255, 0.06)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  /// 👋 Greeting
                  FutureBuilder<String>(
                    future: _getUserFirstName(),
                    builder: (context, snapshot) {
                      final name = snapshot.connectionState == ConnectionState.waiting
                          ? "..."
                          : (snapshot.data ?? "there");
                      return Text(
                        "Good afternoon $name",
                        style: const TextStyle(
                          color: Color(0xFF1A233D),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),

                  /// 📍 Address Dropdown & Action Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AddressDropdown(),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.search, size: 22, color: Color(0xFF1A233D)),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SearchPage()),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline, size: 22, color: Color(0xFF1A233D)),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage()));
                            },
                          ),
                          Consumer<CartProvider>(
                            builder: (context, cart, _) => Stack(
                              children: [
                                IconButton(
                                  key: getCartIconKeyInstance(),
                                  icon: const Icon(Icons.shopping_cart_outlined, size: 22, color: Color(0xFF1A233D)),
                                  onPressed: () {
                                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage()));
                                  },
                                ),
                                if (cart.cartItems.isNotEmpty)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                      child: Text(
                                        '${cart.totalItems}',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      /// 🧱 Main content
      body: child,


      /// 🍥 Custom BottomNavigationBar with pill-shaped active tabs
      bottomNavigationBar: hideNavigationBar
          ? null
          : CustomBottomNavBar(
              currentIndex: currentIndex,
              items: items,
              onTap: (index) {
                if (index == 2) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPage()));
                } else if (isAdmin && index == 4) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboard()));
                } else {
                  onTabSelected(index);
                }
              },
            ),




    );
  }
}
