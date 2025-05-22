// lib/widgets/app_scaffold.dart
import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final int currentIndex;
  final Widget child;
  final Function(int) onTabSelected;

  const AppScaffold({
    super.key,
    required this.currentIndex,
    required this.child,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1A2D3D), // dark navy
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
      ),
      body: SafeArea(child: child),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabSelected,
        backgroundColor: const Color(0xFF1A2D3D),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.local_drink), label: "Products"),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: "Cart"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
