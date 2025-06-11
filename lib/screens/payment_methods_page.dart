import 'package:flutter/material.dart';

class PaymentMethodsPage extends StatelessWidget {
  const PaymentMethodsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payment Methods"),
        backgroundColor: const Color(0xFF254573),
      ),
      body: const Center(
        child: Text("Payment Methods Page"),
      ),
    );
  }
}
