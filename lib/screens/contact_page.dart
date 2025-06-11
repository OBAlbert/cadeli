import 'package:flutter/material.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Contact"),
        backgroundColor: const Color(0xFF254573),
      ),
      body: const Center(
        child: Text("Contact Page"),
      ),
    );
  }
}
