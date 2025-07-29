import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cadeli/screens/orders_page.dart';
import 'package:cadeli/screens/main_page.dart';
import '../widget/app_scaffold.dart';

class OrderSuccessPage extends StatelessWidget {
  final int itemCount;
  final double totalPrice;

  const OrderSuccessPage({
    super.key,
    required this.itemCount,
    required this.totalPrice,
  });

  void saveOrderToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final orderData = {
      'userId': user.uid,
      'itemCount': itemCount,
      'totalPrice': totalPrice,
      'status': 'pending',
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance.collection('orders').add(orderData);
  }

  @override
  Widget build(BuildContext context) {
    saveOrderToFirestore(); // 🔁 save as soon as it's built

    return AppScaffold(
      currentIndex: 2,
      onTabSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD2E4EC),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1A2D3D)),
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainPage()),
                  );
                },
              ),
              const SizedBox(height: 20),
              const Center(
                child: Icon(Icons.check_circle_outline,
                    color: Color(0xFF1A2D3D), size: 70),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Your Order Has Been Placed!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A2D3D),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),

              // Order summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.white24,
                      offset: Offset(0, -2),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Order Summary',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF1A2D3D),
                        )),
                    const SizedBox(height: 10),
                    Text('• Product(s): $itemCount items',
                        style: const TextStyle(fontSize: 14, color: Colors.black87)),
                    Text('• Total Price: €${totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A2D3D),
                        )),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.list_alt),
                      label: const Text("View My Orders"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2D3D),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 8,
                        shadowColor: Colors.black54,
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const OrdersPage()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.home, color: Color(0xFF1A2D3D)),
                      label: const Text(
                        "Back to Home",
                        style: TextStyle(color: Color(0xFF1A2D3D)),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1A2D3D)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const MainPage()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
