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
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/icons/home_icon.png',
          height: 30,
          width: 30,
          fit: BoxFit.contain,
        ),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/icons/product_icon.png',
          height: 30,
          width: 30,
          fit: BoxFit.contain,
        ),
        label: 'Products',
      ),
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/icons/chat_icon.png',
          height: 30,
          width: 30,
          fit: BoxFit.contain,
        ),
        label: 'Messages',
      ),
      BottomNavigationBarItem(
        icon: Image.asset(
          'assets/icons/profile_icon.png',
          height: 30,
          width: 30,
          fit: BoxFit.contain,
        ),
        label: 'Profile',
      ),
    ];




    if (isAdmin) {
      items.add(
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined, size: 30),
          label: 'Admin',
        ),
      );
    }



    return Scaffold(
      extendBody: true,


      /// 🧊 Frosted AppBar with greeting and dropdown
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 6),
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


      /// 🍥 BottomNavigationBar with glowing frosted active tab
      bottomNavigationBar: hideNavigationBar
          ? null
          : Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Stack(
                    children: [
                      // 🧊 Full frosted nav bar background with border
                      BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          height: 66,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            // ✅ BLACK outline for full nav bar — adjust color here
                            border: Border.all(color: Colors.black.withOpacity(0.15), width: 1.3),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.fromRGBO(255, 255, 255, 0.1),
                                Color.fromRGBO(255, 255, 255, 0.05),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 📦 Navigation bar content
                      SizedBox(
                        height: 66,
                        child: BottomNavigationBar(
                          currentIndex: currentIndex,
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          type: BottomNavigationBarType.fixed,
                          selectedItemColor: const Color(0xFF1A233D),
                          unselectedItemColor: const Color(0xFF1A233D).withOpacity(0.5),
                          selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.1),
                          unselectedLabelStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.w400, height: 1.1),
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
                            final isSelected = i == currentIndex;
                            return item;
                          }).toList(),
                        ),
                      ),
                    ],

                  ),
              ),
           ),
      ),
      )




    );
  }
}
