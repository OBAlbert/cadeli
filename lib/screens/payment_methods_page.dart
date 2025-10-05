import 'dart:ui';
import 'package:cadeli/screens/payment_prefs.dart';
import '../models/payment_method.dart';
import 'package:flutter/material.dart';
import 'add_payment_method_page.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  PaymentMethod? selectedMethod;

  @override
  void initState() {
    super.initState();
    loadMethod();
  }

  Future<void> loadMethod() async {
    final method = await PaymentPrefs.getSelectedPaymentMethod();
    setState(() {
      selectedMethod = method;
    });
  }

  void selectMethod(PaymentMethod method) async {
    await PaymentPrefs.saveSelectedPaymentMethod(method);
    setState(() {
      selectedMethod = method;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔵 Title: Payment Methods
              const Text(
                'Payment Methods',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2D3D),
                ),
              ),

              const SizedBox(height: 30),

              // 🖤 Subtitle: Recently used
              const Text(
                'Recently used',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              const SizedBox(height: 16),

              // 💳 Horizontal card list
              SizedBox(
                height: 120,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCard(method: PaymentMethod(type: 'visa', last4: '4242', expiry: '12/26')),
                    _buildCard(method: PaymentMethod(type: 'mastercard', last4: '0924', expiry: '09/24')),
                    _buildCard(method: PaymentMethod(type: 'paypal')),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ➕ Full-width glassy buttons
              _buildButton(
                icon: Icons.add,
                label: 'Add new card',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddPaymentMethodPage()),
                  );
                },
              ),
              _buildButton(
                icon: Icons.money,
                label: 'Cash on delivery',
                onTap: () => selectMethod(PaymentMethod(type: 'cod')),
              ),
              _buildButton(
                icon: Icons.phone_iphone,
                label: 'Apple Pay',
                onTap: () => selectMethod(PaymentMethod(type: 'apple_pay')),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCard({required PaymentMethod method}) {
    final isSelected = selectedMethod?.type == method.type && selectedMethod?.last4 == method.last4;

    String asset = 'visa.png';
    if (method.type == 'mastercard') asset = 'mastercard.png';
    if (method.type == 'paypal') asset = 'paypal.png';

    return GestureDetector(
      onTap: () => selectMethod(method),
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/icons/$asset", width: 40, height: 40),
            const SizedBox(height: 10),
            if (method.last4.isNotEmpty)
              Text("**** ${method.last4}", style: const TextStyle(color: Colors.black,fontWeight: FontWeight.bold)),
            if (method.expiry.isNotEmpty)
              Text(method.expiry, style: const TextStyle(fontSize: 12, color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 24, color: Colors.black87),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }


}
