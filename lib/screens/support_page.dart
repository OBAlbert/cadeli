import 'package:flutter/material.dart';

class SupportPage extends StatelessWidget {
  const SupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Customer support coming soon...",
        style: TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
