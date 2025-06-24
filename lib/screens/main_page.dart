import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widget/app_scaffold.dart';
import 'home_page.dart';
import 'products_page.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'admin_dashboard.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  bool _isAdmin = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    checkAdminStatus();
  }

  Future<void> checkAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        _isAdmin = doc.data()?['isAdmin'] == true;
        _loading = false;
      });
    } else {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = _isAdmin
        ? [
      const HomePage(),
      const ProductsPage(),
      const CartPage(),
      const ProfilePage(),
      const AdminDashboard(),
    ]
        : [
      const HomePage(),
      const ProductsPage(),
      const CartPage(),
      const ProfilePage(),
    ];

    return AppScaffold(
      currentIndex: _currentIndex,
      onTabSelected: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      isAdmin: _isAdmin,
      child: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
    );
  }
}
