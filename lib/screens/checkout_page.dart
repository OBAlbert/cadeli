import 'dart:async';
import 'dart:ui';
import 'package:cadeli/screens/pick_location_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import '../models/payment_method.dart';
import '../widget/app_scaffold.dart';
import 'main_page.dart';
import 'order_success_page.dart';
import '../services/woocommerce_service.dart';


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
  Map<String, dynamic>? selectedAddress;
  List<Map<String, dynamic>> addressList = [];

  final WooCommerceService wooService = WooCommerceService();

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
      );
    });
  }

  Future<void> _placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || selectedAddress == null) return;

    final cart = Provider.of<CartProvider>(context, listen: false);

    // Inject email into address map so WooCommerce doesn't reject
    selectedAddress = {
      ...selectedAddress!,
      'email': user.email ?? '',
    };

    try {
      // 1. Create WooCommerce order (unpaid)

      final wooService = WooCommerceService();
      final wooOrder = await wooService.createWooOrder(
        cart.cartItems.map((item) => item['product']).toList(),
        selectedAddress!,
        selectedPayment,
        setPaid: false, // 🔴 Let admin set paid later
      );

      // Check if Woo order was created
      if (wooOrder['id'] == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Failed to create WooCommerce order"),
        ));
        return;
      }

      // 🔁 Fetch user's full name from Firestore
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final fullName = userDoc.data()?['fullName'] ?? 'No Name';


      final orderData = {
        'uid': user.uid,
        'type': isSubscription ? 'subscription' : 'normal',
        'timestamp': FieldValue.serverTimestamp(),
        'payment': selectedPayment,
        'status': 'pending',
        'wooOrderId': wooOrder['id'], // ✅ save Woo order ID
        'totalCost': cart.totalCost,
        'userName': "${user.displayName ?? ''} - ${selectedAddress?['city'] ?? ''}",
        'addressSummary': selectedAddress?['label'] ?? '',
        'deliveryNotes': selectedAddress?['notes'] ?? '',
        'name': fullName,
        'adminStatusHistory': [
          {
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
          }
        ],
        'items': cart.cartItems.map((item) => {
          'productId': item['product'].id,
          'name': item['product'].name,
          'brand': item['product'].brand,
          'price': item['product'].price,
          'imageUrl': item['product'].imageUrl,
          'quantity': item['quantity'],
          'size': item['size'],
          'pack': item['pack'],
        }).toList(),
      };

      // 2. Save to Firestore
      await FirebaseFirestore.instance.collection('orders').add(orderData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Order placed! Waiting for admin approval"),
      ));

      // 3. Clear cart + navigate
      cart.clearCart();
      Navigator.pushReplacementNamed(context, '/order_success');

    } catch (e) {
      print("❌ Error placing order: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Something went wrong. Try again."),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;

    return AppScaffold(
      currentIndex: 0,
      hideNavigationBar: true,
      onTabSelected: (index) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
        },
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 2, 20, 10),
                    child: Text(
                      'Checkout',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A2D3D),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(40),
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                            BoxShadow(color: Colors.white30, offset: Offset(0, -2), blurRadius: 2),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 18, color: Colors.black),
                            SizedBox(width: 6),
                            Text('Back to Cart', style: TextStyle(color: Colors.black)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                  const Text('ADDRESS', style: _sectionTitle),
                  const SizedBox(height: 6),
                  _buildAddressSelector(),

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
                            child: Image.network(
                              product.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
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



                  if (isSubscription) ...[
                    const SizedBox(height: 24),
                    const Text('DELIVERY TIME SLOT', style: _sectionTitle),
                    const SizedBox(height: 6),
                    _buildChips(['Morning', 'Afternoon', 'Evening'], selectedTimeSlot, (val) {
                      setState(() => selectedTimeSlot = val);
                    }),

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

                  const SizedBox(height: 8),
                  const Text(
                    'Recently used',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildPaymentCard(method: PaymentMethod(type: 'visa', last4: '4242', expiry: '12/26')),
                        _buildPaymentCard(method: PaymentMethod(type: 'mastercard', last4: '7890', expiry: '08/25')),
                        _buildAddPaymentCard(),

                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _buildPaymentButton(
                    icon: Icons.credit_card,
                    label: 'Pay with Card',
                    isSelected: selectedPayment == 'Card',
                    onTap: () {
                      setState(() => selectedPayment = 'Card');
                    },
                  ),
                  _buildPaymentButton(
                    icon: Icons.attach_money,
                    label: 'Cash on Delivery',
                    isSelected: selectedPayment == 'COD',
                    onTap: () {
                      setState(() => selectedPayment = 'COD');
                    },
                  ),
                  _buildPaymentButton(
                    icon: Icons.phone_iphone,
                    label: 'Apple Pay',
                    isSelected: selectedPayment == 'ApplePay',
                    onTap: () {
                      setState(() => selectedPayment = 'ApplePay');
                    },
                  ),


                  const SizedBox(height: 28),
                  GestureDetector(
                    onTap: _placeOrder,
                    child: Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A2D3D),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black38, offset: Offset(0, 8), blurRadius: 24),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.payment, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            'Place Order',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

              ),
            );
          },
        ),
      ),

    );
  }

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

  Widget _buildAddressSelector() {
    return GestureDetector(
      onTap: () => _showAddressPickerModal(), // opens bottom sheet
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
            BoxShadow(color: Colors.white24, offset: Offset(0, -2), blurRadius: 2),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, size: 20, color: Color(0xFF1A233D)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selectedAddress?['label'] ?? 'No address selected',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A233D),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1A233D)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassDropdownDay() {
    List<String> days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black, width: 1.2),
        // boxShadow: const [
        //   BoxShadow(
        //     color: Colors.black12,
        //     blurRadius: 8,
        //     offset: Offset(0, 4),
        //
        //   ),
        // ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedDay,
          icon: const Icon(Icons.arrow_drop_down),
          dropdownColor: Colors.white, // fix dark background
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          onChanged: (String? newVal) {
            if (newVal != null) {
              setState(() {
                selectedDay = newVal;
              });
            }
          },
          items: days.map((day) {
            return DropdownMenuItem(
              value: day,
              child: Text(day),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildChips(List<String> options, String selected, Function(String) onChanged) {
    return Wrap(
      spacing: 10,
      children: options.map((val) {
        final isSelected = selected == val;
        final label = {
          'Morning': 'Morning (9–12)',
          'Afternoon': 'Afternoon (1–4)',
          'Evening': 'Evening (6–9)',
          'Weekly': 'Weekly',
          'Biweekly': 'Biweekly',
          'Monthly': 'Monthly',
          'COD': 'COD',
          'Card': 'Card',
        }[val] ?? val;

        return ChoiceChip(
          label: Text(label, style: TextStyle(fontSize: 14)),
          selected: isSelected,
          selectedColor: const Color(0xFF1A233D),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          side: isSelected
              ? null
              : const BorderSide(color: Colors.black, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (_) => onChanged(val),
        );
      }).toList(),
    );
  }

   void _showAddressPickerModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select Delivery Address',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            ...addressList.map((a) {
              return ListTile(
                title: Text(
                  a['label'],
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),

                ),

                leading: const Icon(Icons.location_on_outlined, color: Colors.black54),
                trailing: selectedAddress == a['label']
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    selectedAddress = a;
                  });
                  Navigator.pop(context);
                },
              );
            }).toList(),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PickLocationPage()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text("Add new Address"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D2952),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard({required PaymentMethod method}) {
    String asset = 'visa.png';
    if (method.type == 'mastercard') asset = 'mastercard.png';

    bool isSelected = selectedPayment == method.type;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedPayment = method.type;
        });
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black.withOpacity(0.15),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SizedBox(
          height: 100, // or whatever height works for your design
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset("assets/icons/$asset", width: 36, height: 36),
              if (method.last4.isNotEmpty)
                Text(
                  "**** ${method.last4}",
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              if (method.expiry.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    method.expiry,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),


      ),
    );
  }


  Widget _buildPaymentButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.25) : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.black : Colors.black.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
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

  Widget _buildAddPaymentCard() {
    return GestureDetector(
      onTap: () {
        // Navigate to add payment page or show a modal
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add payment method coming soon')),
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.black.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 32, color: Colors.black87),
            SizedBox(height: 10),
            Text(
              'Add Method',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

}



