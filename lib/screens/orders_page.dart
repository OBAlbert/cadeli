import 'package:flutter/material.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        backgroundColor: const Color(0xFF254573),
      ),
      body: const Center(
        child: Text("Orders Page"),
      ),
    );
  }
}