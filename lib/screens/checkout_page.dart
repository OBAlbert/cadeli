import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import '../widget/app_scaffold.dart';
import 'order_success_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> with SingleTickerProviderStateMixin {
  bool isSubscription = false;
  String selectedTimeSlot = 'Morning';
  String selectedFrequency = 'Weekly';
  String selectedDay = 'Monday';
  String selectedPayment = 'COD';
  String? selectedAddress;
  List<Map<String, dynamic>> addressList = [];

  late AnimationController _controller;
  late Animation<double> _tabAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _tabAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .orderBy('timestamp', descending: true)
        .get();

    final addresses = snapshot.docs.map((doc) => doc.data()).toList();

    setState(() {
      addressList = addresses;
      selectedAddress = addresses.firstWhere(
            (a) => a['isDefault'] == true,
        orElse: () => addresses.first,
      )['label'];
    });
  }

  Future<void> _placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedAddress == null) return;
    final cart = Provider.of<CartProvider>(context, listen: false);

    final orderData = {
      'uid': user.uid,
      'type': isSubscription ? 'subscription' : 'normal',
      'timestamp': FieldValue.serverTimestamp(),
      'address': selectedAddress,
      'timeSlot': selectedTimeSlot,
      'payment': selectedPayment,
      'status': 'pending',
      'totalCost': cart.totalCost,
      'items': cart.cartItems.map((item) => {
        'productId': item['product'].id,
        'name': item['product'].name,
        'brand': item['product'].brand,
        'price': item['product'].price,
        'imageUrl': item['product'].imageUrl,
        'quantity': item['quantity'],
        'size': item['size'],
        'package': item['package'],
      }).toList(),
      if (isSubscription) ...{
        'frequency': selectedFrequency,
        'day': selectedDay,
      },
    };

    try {
      await FirebaseFirestore.instance.collection('orders').add(orderData);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'lastOrder': orderData,
      });

      cart.clearCart();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const OrderSuccessPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to place order: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;

    return AppScaffold(
      currentIndex: 2,
      onTabSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD2E4EC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2D3D),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Checkout', style: TextStyle(color: Colors.white)),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle: Normal / Subscription
              Center(
                child: AnimatedBuilder(
                  animation: _tabAnimation,
                  builder: (_, __) => ToggleButtons(
                    borderRadius: BorderRadius.circular(30),
                    borderColor: Colors.grey.shade300,
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFF1A233D),
                    color: Colors.black87,
                    isSelected: [!isSubscription, isSubscription],
                    onPressed: (index) {
                      setState(() => isSubscription = index == 1);
                      _controller.forward(from: 0);
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Normal Delivery'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Text('Subscription'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Address Section
              const Text('ADDRESS', style: _sectionTitle),
              const SizedBox(height: 6),
              _buildGlassDropdown(),

              const SizedBox(height: 24),
              const Text('ORDER SUMMARY', style: _sectionTitle),
              const SizedBox(height: 8),

              ...cartItems.map((item) {
                final product = item['product'];
                final quantity = item['quantity'];
                final price = product.price;
                final subtotal = price * quantity;

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: _glassDecoration(),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/products/${product.imageUrl}',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 40, color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name, style: _boldDark),
                            Text('${item['size']} / ${item['package']}', style: _secondaryStyle),
                            const SizedBox(height: 4),
                            Text('€${price.toStringAsFixed(2)} × $quantity', style: _lightDetail),
                          ],
                        ),
                      ),
                      Text('€${subtotal.toStringAsFixed(2)}', style: _boldDark),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Total Summary Line
              const Divider(thickness: 1, color: Colors.black26),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2D3D),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'TOTAL: €${cartProvider.totalCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),
              const Text('DELIVERY TIME SLOT', style: _sectionTitle),
              const SizedBox(height: 6),
              _buildChips(['Morning', 'Afternoon', 'Evening'], selectedTimeSlot, (val) {
                setState(() => selectedTimeSlot = val);
              }),

              if (isSubscription) ...[
                const SizedBox(height: 24),
                const Text('FREQUENCY', style: _sectionTitle),
                _buildChips(['Weekly', 'Biweekly', 'Monthly'], selectedFrequency, (val) {
                  setState(() => selectedFrequency = val);
                }),
                const SizedBox(height: 24),
                const Text('PREFERRED DAY', style: _sectionTitle),
                const SizedBox(height: 6),
                _buildGlassDropdownDay(),
              ],

              const SizedBox(height: 24),
              const Text('PAYMENT METHOD', style: _sectionTitle),
              const SizedBox(height: 6),
              _buildChips(['COD', 'Card'], selectedPayment, (val) {
                setState(() => selectedPayment = val);
              }),

              const SizedBox(height: 28),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('Place Order'),
                onPressed: _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A233D),
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  shadowColor: Colors.black54,
                ),
              )
,
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable styling
  static const TextStyle _sectionTitle = TextStyle(
    color: Color(0xFF1A233D),
    fontWeight: FontWeight.bold,
    fontSize: 16,
  );

  static const TextStyle _boldDark = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
    color: Color(0xFF1A233D),
  );

  static const TextStyle _secondaryStyle = TextStyle(fontSize: 13, color: Colors.black87);
  static const TextStyle _lightDetail = TextStyle(fontSize: 13, color: Colors.black54);

  BoxDecoration _glassDecoration() => BoxDecoration(
    color: Colors.white.withOpacity(0.3),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.4)),
    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
  );

  Widget _buildGlassDropdown() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 8),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedAddress,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1A233D)),
              dropdownColor: Colors.white,
              style: const TextStyle(color: Color(0xFF1A233D)),
              items: [
                ...addressList.map((a) => DropdownMenuItem(
                  value: a['label'],
                  child: Text(a['label']),
                )),
                const DropdownMenuItem(
                  value: 'add_new',
                  child: Text('+ Add New Address'),
                ),
              ],
              onChanged: (val) {
                if (val == 'add_new') {
                  Navigator.pushNamed(context, '/pick-location');
                } else {
                  setState(() => selectedAddress = val);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassDropdownDay() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DropdownButton<String>(
          value: selectedDay,
          isExpanded: true,
          underline: const SizedBox(),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1A233D)),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A233D),
            fontSize: 14,
          ),
          dropdownColor: Colors.white,
          items: [
            'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
          ].map((d) => DropdownMenuItem(
            value: d,
            child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold)),
          )).toList(),
          onChanged: (val) => setState(() => selectedDay = val!),
        ),
      ),
    );
  }

  Widget _buildChips(List<String> options, String selected, Function(String) onChanged) {
    return Wrap(
      spacing: 10,
      children: options.map((val) {
        final isSelected = selected == val;
        return ChoiceChip(
          label: Text(
            val == 'Morning'
                ? 'Morning (9–12)'
                : val == 'Afternoon'
                ? 'Afternoon (1–4)'
                : val == 'Evening'
                ? 'Evening (6–9)'
                : val,
            style: const TextStyle(fontSize: 14),
          ),
          selected: isSelected,
          selectedColor: const Color(0xFF1A233D),
          backgroundColor: Colors.black,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (_) => onChanged(val),
        );
      }).toList(),
    );
  }
}
