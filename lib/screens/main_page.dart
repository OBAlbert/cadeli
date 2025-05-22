import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../widget/app_scaffold.dart';
import 'home_page.dart';
import 'products_page.dart';
import 'cart_page.dart';
import 'profile_page.dart';
import 'login_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const ProductsPage(),
    const CartPage(),
    const ProfilePageRedirect(),
  ];


  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: _currentIndex,
      onTabSelected: _onTabSelected,
      child: _pages[_currentIndex],
    );
  }


}

// Handles redirect to login if not authenticated
class ProfilePageRedirect extends StatelessWidget {
  const ProfilePageRedirect({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginPage();
    } else {
      return const ProfilePage();
    }
  }
}
