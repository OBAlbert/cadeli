// 📄 app_scaffold.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/cart_provider.dart';
import '../screens/cart_page.dart';
import '../screens/info_page.dart';
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
  final bool hideAppBar;            // NEW
  final bool showAddressDropdown;   // NEW


  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabSelected,
    this.isAdmin = false,
    this.hideNavigationBar = false,
    this.hideAppBar = false,          // NEW (default keep AppBar)
    this.showAddressDropdown = true,
  });

  /// 🔍 Fetches the user's first name from Firestore
  Future<String> _getUserFirstName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'there';
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final fullName = doc.data()?['fullName'] ?? '';
    return fullName.toString().split(' ').first.isNotEmpty ? fullName.toString().split(' ').first : 'there';
  }

  Widget _tint(Color c) => IgnorePointer(
    child: Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: c.withOpacity(0.12), // subtle coloured bloom
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {

    // Build bottom nav items (different for admin vs customer)
    final List<BottomNavigationBarItem> items = isAdmin
    // ADMIN: Home, Products, Messages, Admin  (no Profile)
        ? [
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/home_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/product_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Products',
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/chat_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Messages',
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/admin_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Admin',
      ),
    ]
    // CUSTOMER: Home, Products, Messages, Profile
        : [
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/home_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/product_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Products',
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/chat_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Messages',
      ),
      BottomNavigationBarItem(
        icon: Image.asset('assets/icons/profile_icon.png', height: 30, width: 30, fit: BoxFit.contain),
        label: 'Profile',
      ),
    ];


    return Scaffold(
      extendBody: true,


      /// 🧊 Frosted AppBar with greeting and dropdown (can be hidden)
      appBar: hideAppBar
          ? null
          : PreferredSize(
        preferredSize: const Size.fromHeight(120), // taller to avoid clip
        child: SafeArea( bottom: false,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors:[Color.fromRGBO(255,255,255,0.12), Color.fromRGBO(255,255,255,0.06)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FutureBuilder<String>(
                        future: _getUserFirstName(),
                        builder:(context,s){
                          final name = s.connectionState==ConnectionState.waiting? '...' : (s.data??'there');
                          debugPrint('[AppScaffold] appbar-built; name=$name');
                          return Text('Good day, $name',
                              style: const TextStyle(color: Color(0xFF1A233D), fontWeight: FontWeight.bold, fontSize: 16));
                        }),
                    const SizedBox(height: 6),
                    Row(children:[
                      Expanded(child: showAddressDropdown ? const AddressDropdown() : const SizedBox.shrink()),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.search, size:22, color: Color(0xFF1A233D)),
                          onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>SearchPage()))),
                      IconButton(icon: const Icon(Icons.info_outline, size:22, color: Color(0xFF1A233D)),
                          onPressed: ()=>Navigator.push(context, MaterialPageRoute(builder:(_)=>const InfoPage()))),
                      if(!isAdmin) Consumer<CartProvider>(builder:(context,cart,_)=>
                          Stack(children:[
                            IconButton(key: getCartIconKeyInstance(),
                                icon: const Icon(Icons.shopping_cart_outlined, size:22, color: Color(0xFF1A233D)),
                                onPressed: ()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const CartPage()))),
                            if(cart.cartItems.isNotEmpty) Positioned(right:6, top:6, child:
                            Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth:18, minHeight:18),
                                child: Text('${cart.totalItems}', style: const TextStyle(color: Colors.white, fontSize:10, fontWeight: FontWeight.bold))))
                          ])),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),





      body: SafeArea(bottom: false, child: child),


      /// 🍥 BottomNavigationBar with glowing frosted active tab
      bottomNavigationBar: hideNavigationBar
          ? null
          : Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            // 👇 this actually blurs the content behind the pill
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                // 👇 translucent fill so the blur is visible
                color: Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  // crisp “glass edge”
                  color: Colors.white.withOpacity(0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  // gentle lift from the page
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // soft diagonal sheen across the glass
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.25),
                            Colors.white.withOpacity(0.08),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // optional coloured edge tints like your screenshot
                  Positioned(left: -16, top: -8, child: _tint(Colors.greenAccent)),
                  Positioned(right: -16, bottom: -8, child: _tint(Colors.redAccent)),

                  // the actual bottom nav
                  BottomNavigationBar(
                    currentIndex: currentIndex,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    type: BottomNavigationBarType.fixed,
                    selectedItemColor: const Color(0xFF1A233F),
                    unselectedItemColor: const Color(0xFF1A235A).withOpacity(0.6),
                    selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, height: 1.1),
                    unselectedLabelStyle: const TextStyle(fontSize: 8, fontWeight: FontWeight.w400, height: 1.1),
                    onTap: onTabSelected,
                    items: items,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

    );
  }
}
