import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../models/cart_provider.dart';
import '../screens/cart_page.dart';
import '../screens/chat_page.dart';
import '../screens/admin_dashboard.dart';
import '../screens/info_page.dart';
import '../screens/search_page.dart';
import 'address_dropdown.dart'; // 👈 NEW: You'll create this file below

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
      const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
      const BottomNavigationBarItem(icon: Icon(Icons.local_drink_outlined), label: "Products"),
      const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: "Chat"),
      const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
    ];

    if (isAdmin) {
      items.insert(4, const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: "Admin"));
    }

    return Scaffold(
      extendBody: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.12),
                    Color.fromRGBO(255, 255, 255, 0.06),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 360;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 🌤 Greeting line
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

                      // 📍 Address & Icons Row
                      // 📍 Address & Icons Row with proper alignment
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // ⬅️ Address dropdown container
                          // Expanded(
                          //   child: Container(
                          //     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          //     decoration: BoxDecoration(
                          //       color: Colors.white.withOpacity(0.15),
                          //       borderRadius: BorderRadius.circular(14),
                          //       border: Border.all(color: Colors.white.withOpacity(0.3)),
                          //       boxShadow: [
                          //         BoxShadow(
                          //           color: Colors.white.withOpacity(0.05),
                          //           blurRadius: 8,
                          //           offset: const Offset(0, 2),
                          //         ),
                          //       ],
                          //     ),
                          //     child: const AddressDropdown(),
                          //   ),
                          // ),

                          SizedBox(
                            width: 200, // 👈 adjust this value to tighten or stretch manually
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const AddressDropdown(),
                            ),
                          ),


                          const SizedBox(width: 8),

                          // ➡️ Icons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.search, color: Color(0xFF1A233D), size: 22),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
                                },
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(Icons.info_outline, color: Color(0xFF1A233D), size: 22),
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoPage()));
                                },
                              ),
                              Consumer<CartProvider>(
                                builder: (context, cart, _) => Stack(
                                  children: [
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      key: getCartIconKeyInstance(),
                                      icon: const Icon(Icons.shopping_cart_outlined, color: Color(0xFF1A233D), size: 22),
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
                  );
                },
              ),
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: Container(
          color: Colors.white,
          child: child,
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color.fromRGBO(255, 255, 255, 0.25),
                    Color.fromRGBO(255, 255, 255, 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),

              child: BottomNavigationBar(
                currentIndex: currentIndex >= 0 && currentIndex < items.length ? currentIndex : 0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.redAccent,
                unselectedItemColor: const Color(0xFF1A233D).withOpacity(0.5),
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Colors.redAccent,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: const Color(0xFF1A233D).withOpacity(0.5),
                ),

                onTap: (index) {
                  if (index == 2) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPage()));
                  } else if (isAdmin && index == 4) {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminDashboard()));
                  } else {
                    onTabSelected(index);
                  }
                },
                items: items.mapIndexed((i, item) {
                  final isSelected = currentIndex == i && currentIndex >= 0;
                  return BottomNavigationBarItem(
                    label: item.label,
                    icon: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: Colors.redAccent.withOpacity(0.3))
                            : null,
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 3),
                          ),
                        ]
                            : [],
                      ),
                      child: IconTheme(
                        data: IconThemeData(
                          color: isSelected ? Colors.redAccent : const Color(0xFF1A233D).withOpacity(0.5),
                        ),
                        child: item.icon,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),


    );
  }
}
