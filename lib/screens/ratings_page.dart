import 'package:flutter/material.dart';

class RatingsPage extends StatelessWidget {
  const RatingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ratings"),
        backgroundColor: const Color(0xFF254573),
      ),
      body: const Center(
        child: Text("Ratings Page"),
      ),
    );
  }
}
