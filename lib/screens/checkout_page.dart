import 'dart:async';
import 'package:cadeli/screens/pick_location_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import 'chat_thread_page.dart';
import 'main_page.dart';
import '../services/woocommerce_service.dart';
import '../services/payment_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../utils/address_icon.dart';
import 'dart:io';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  String selectedTimeSlot = 'Morning';

  Map<String, dynamic>? selectedAddress;
  List<Map<String, dynamic>> addressList = [];
  final WooCommerceService wooService = WooCommerceService();
  String? _selectedCardId;

  final _payment = PaymentService();
  bool _placing = false;

  @override
  void initState() {
    super.initState();
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

    final addresses = snapshot.docs
        .map((doc) => {'id': doc.id, ...doc.data()})
        .toList();

    if (!mounted) return;
    setState(() {
      addressList = addresses;
      if (addresses.isEmpty) {
        selectedAddress = null;
      } else {
        // pick default if any, else the most recent
        final idx = addresses.indexWhere((a) => a['isDefault'] == true);
        selectedAddress = idx >= 0 ? addresses[idx] : addresses.first;
      }
    });
  }

  Widget _showPaymentMethodPicker() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _payment.listPaymentMethods(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final cards = snapshot.data!;
        if (cards.isEmpty) {
          return TextButton.icon(
            onPressed: () async {
              await _addNewCardFromCheckout();
              setState(() {});
            },
            icon: const Icon(Icons.add, color: Color(0xFF0E1A36)),
            label: const Text(
              'Add Card',
              style: TextStyle(
                color: Color(0xFF0E1A36),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Color(0xFF0E1A36), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              dropdownColor: Colors.white,
              style: const TextStyle(
                color: Color(0xFF0E1A36),
                fontWeight: FontWeight.w600,
              ),
              hint: const Text(
                'Select saved card',
                style: TextStyle(color: Color(0xFF0E1A36)),
              ),
              value: _selectedCardId,
              onChanged: (val) => setState(() => _selectedCardId = val),
              items: cards.map((c) {
                final id = c['id'] as String;
                final brand = c['brand'];
                final last4 = c['last4'];
                return DropdownMenuItem(
                  value: id,
                  child: Text('$brand •••• $last4'),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _addNewCardFromCheckout() async {
    final setup = await _payment.createSetupIntent();

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        merchantDisplayName: 'Cadeli',
        customerId: setup['customerId'],
        setupIntentClientSecret: setup['clientSecret'],
        style: ThemeMode.light,
      ),
    );

    await Stripe.instance.presentPaymentSheet();

    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Card added')));
  }

  Future<void> _placeOrder() async {
    if (_placing) return;
    setState(() => _placing = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to place an order.')),
      );
      setState(() => _placing = false);
      return;
    }

    try {
      // force fresh token so callable sees auth
      await user.getIdToken(true);

      // 🛒 cart → list of items in canonical shape
      final cart = context.read<CartProvider>();
      final items = cart.cartItems.map<Map<String, dynamic>>((m) {
        final product = m['product'];
        final prodId = product != null ? product.id : m['id'];

        return {
          'id': int.tryParse(prodId.toString()) ?? 0,
          'name': product?.name ?? m['name'] ?? '',
          'brand': product?.brand ?? '',
          'imageUrl': product?.imageUrl ?? '',
          'price': product?.price ?? 0.0,
          'quantity': (m['quantity'] ?? 1) as int,
        };
      }).toList();

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Your cart is empty')),
        );
        setState(() => _placing = false);
        return;
      }

      // 👤 user info
      final userEmail = user.email ?? '';
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final fullName = (userDoc.data()?['fullName'] ?? '').toString().trim();

      // 🏷️ split first/last
      final parts = fullName.split(' ').where((s) => s.trim().isNotEmpty).toList();
      final firstName = parts.isNotEmpty ? parts.first : 'Customer';
      final lastName  = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      // -------------------------------------------------------
      // CLEAN, SAFE ADDRESS EXTRACTION (ALL ADDRESS TYPES)
      // -------------------------------------------------------
      final Map<String, dynamic> addr = selectedAddress ?? {};

      final String line1   = addr['line1']   ?? addr['label'] ?? 'Address';
      final String city    = addr['city']    ?? 'Larnaka';
      final String country = addr['country'] ?? 'CY';
      final String phone   = addr['phone']   ?? '';
      final String type    = addr['type']    ?? 'other';
      final String addrId  = addr['id']      ?? '';

      // details{} supports hotel/office/apartment/house/other
      final Map<String, dynamic> details =
      (addr['details'] is Map<String, dynamic>)
          ? Map<String, dynamic>.from(addr['details'])
          : <String, dynamic>{};

      // -------------------------------------------------------
      // ROBUST LAT / LNG EXTRACTION (CLEAN)
      // -------------------------------------------------------
      double? lat;
      double? lng;

      if (addr['geo'] is GeoPoint) {
        final g = addr['geo'] as GeoPoint;
        lat = g.latitude;
        lng = g.longitude;
      }

      lat ??= (addr['lat'] is num) ? (addr['lat'] as num).toDouble() : null;
      lng ??= (addr['lng'] is num) ? (addr['lng'] as num).toDouble() : null;

      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick a valid delivery location.')),
        );
        setState(() => _placing = false);
        return;
      }

      // -------------------------------------------------------
      // WOO ADDRESS BLOCK
      // -------------------------------------------------------
      final wooAddress = {
        'first_name': firstName,
        'last_name': lastName,
        'address_1': line1,
        'city': city,
        'country': country,
        'email': userEmail.isNotEmpty ? userEmail : 'noemail@cadeli.app',
        'phone': phone,
      };

      // -------------------------------------------------------
      // META (FIRESTORE ORDER FIELDS)
      // -------------------------------------------------------
      final meta = <String, dynamic>{
        'customer_name'      : fullName.isNotEmpty ? fullName : firstName,

        // Address fields
        'address_line'       : line1,
        'address_label'      : addr['label'] ?? line1,
        'address_type'       : type,
        'address_details'    : details,
        'address_city'       : city,
        'address_country'    : country,
        'address_id'         : addrId,

        // Contact
        'phone'              : phone,

        // Coordinates
        'location_lat'       : lat,
        'location_lng'       : lng,

        // Admin filtering
        'city'               : city,
        'country'            : country,

        // Subscription logic
        'delivery_type' : 'subscription',
        'frequency': 'weekly',
        'subscription_frequency': 'weekly',
        'cycle_number': 1,
        'next_cycle_date_ms': DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch,

        // Time slot
        'time_slot'          : selectedTimeSlot,

        // Timestamps
        'order_placed_at_ms' : DateTime.now().millisecondsSinceEpoch,
      };


      // ✅ basic validations
      if (selectedTimeSlot.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pick a time slot.')),
        );
        setState(() => _placing = false);
        return;
      }

      if (((wooAddress['address_1'] ?? '').toString().trim()).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add your street address.')),
        );
        setState(() => _placing = false);
        return;
      }

      // ===================== FLOW: CARD ONLY (SUBSCRIPTION) =====================

      // 1) Create Woo + Firestore order (unpaid, pending, subscription meta)
      final created = await _payment.createWooOrderAuthorized(
        cartItems: items,
        address: wooAddress,
        meta: meta,
      );

      final orderDocId = created.docId;


      // 2) Create manual-capture PaymentIntent tied to that orderDocId
      final sheet = await _payment.createStripePaymentSheet(
        orderId: orderDocId,
        mode: 'subscription',
      );

      final piSecret = sheet['paymentIntent'] as String?;
      final ek = sheet['ephemeralKey'] as String?;
      final cust = sheet['customer'] as String?;

      if (piSecret == null || ek == null || cust == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment setup failed (missing keys).')),
        );
        setState(() => _placing = false);
        return;
      }

      // 3a) If user picked a saved card, confirm PI with that card
      if (_selectedCardId != null && _selectedCardId!.isNotEmpty) {
        await Stripe.instance.confirmPayment(
          paymentIntentClientSecret: piSecret,
          data: PaymentMethodParams.cardFromMethodId(
            paymentMethodData: PaymentMethodDataCardFromMethod(
              paymentMethodId: _selectedCardId!,
            ),
          ),
        );
      } else {
        // 3b) Otherwise show PaymentSheet so they can choose / add a card now
        try {
          await Stripe.instance.initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
              paymentIntentClientSecret: piSecret,
              customerEphemeralKeySecret: ek,
              customerId: cust,
              merchantDisplayName: 'Cadeli',
              applePay: Platform.isIOS
                  ? const PaymentSheetApplePay(merchantCountryCode: 'CY')
                  : null,
              googlePay: Platform.isAndroid
                  ? const PaymentSheetGooglePay(
                merchantCountryCode: 'CY',
                testEnv: true,
              )
                  : null,
              style: ThemeMode.light,
              allowsDelayedPaymentMethods: false,
            ),
          );
          await Stripe.instance.presentPaymentSheet();
        } on StripeException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Card not authorized: ${e.error.localizedMessage ?? e.toString()}',
              ),
            ),
          );
          setState(() => _placing = false);
          return;
        }
      }

      // 4) Success: clear cart, go to Orders tab, then open chat for that order
      cart.clearCart();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment authorized. Awaiting approval.')),
      );

      // First go back to main app on Orders tab
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 2)),
            (route) => false,
      );

      // Then open the chat thread for this subscription/order
      Future.microtask(() {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ChatThreadPage(orderId: orderDocId, customerId: user.uid),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _showCardSelectionSheet() async {
    final cards = await _payment.listPaymentMethods();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pay with Card',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Color(0xFF0E1A36),
                  ),
                ),
                const SizedBox(height: 12),
                if (cards.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Color(0xFF0E1A36), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: Colors.white,
                        value: _selectedCardId,
                        hint: const Text(
                          'Select saved card',
                          style: TextStyle(color: Color(0xFF0E1A36)),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _selectedCardId = val;
                          });
                          Navigator.pop(context);
                        },
                        items: cards.map((c) {
                          final id = c['id'] as String;
                          final brand = c['brand'];
                          final last4 = c['last4'];
                          return DropdownMenuItem(
                            value: id,
                            child: Text('$brand •••• $last4'),
                          );
                        }).toList(),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No saved cards yet.'),
                  ),
                const SizedBox(height: 18),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _addNewCardFromCheckout();
                      await _payment.listPaymentMethods(); // refresh saved cards
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Card added successfully.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E1A36),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 22),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add / Use New Card'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _loadingOverlay() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _placing ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_placing,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.35),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation(Color(0xFF0E1A36)),
                  strokeWidth: 4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;

    // 🔑 Small behaviour change: user can place an order as long as
    // they have items + an address. Card is enforced INSIDE _placeOrder
    // (either saved card or PaymentSheet).
    final bool canPlace =
        cartItems.isNotEmpty && selectedAddress != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2D3D),
          ),
        ),
        leading: const SizedBox.shrink(),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.only(
                      left: 20, right: 20, bottom: 30, top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BACK TO CART BUTTON
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.arrow_back,
                                  size: 18, color: Colors.black),
                              SizedBox(width: 6),
                              Text(
                                'Cart',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'SUBSCRIPTION',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1A233D),
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Set up your weekly subscription order. Delivery day depends on the truck\'s location. You can chat with the admin after placing your order.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text('ADDRESS', style: _sectionTitle),
                      const SizedBox(height: 6),
                      _buildAddressSelector(),

                      const SizedBox(height: 24),

                      const Text('ORDER SUMMARY', style: _sectionTitle),
                      const SizedBox(height: 8),

                      // ---- PRODUCT LIST ----
                      ...cartItems.map((item) {
                        final product = item['product'];
                        final quantity = item['quantity'];
                        final price = product.price;
                        final subtotal = price * quantity;

                        return Container(
                          margin:
                          const EdgeInsets.symmetric(vertical: 6),
                          decoration: _glassDecoration(),
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                BorderRadius.circular(12),
                                child: (product.imageUrl ?? '')
                                    .toString()
                                    .isNotEmpty
                                    ? Image.network(
                                  product.imageUrl,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                                    : const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Icon(
                                    Icons.image_not_supported,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(product.name,
                                        style: _boldDark),
                                    if ((item['size']
                                        ?.toString()
                                        .isNotEmpty ??
                                        false) &&
                                        (item['package']
                                            ?.toString()
                                            .isNotEmpty ??
                                            false))
                                      Text(
                                        '${item['size']} • ${item['package']}',
                                        style: _secondaryStyle,
                                      )
                                    else if ((item['size']
                                        ?.toString()
                                        .isNotEmpty ??
                                        false))
                                      Text(
                                        '${item['size']}',
                                        style: _secondaryStyle,
                                      )
                                    else if ((item['package']
                                          ?.toString()
                                          .isNotEmpty ??
                                          false))
                                        Text(
                                          '${item['package']}',
                                          style: _secondaryStyle,
                                        ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '€${price.toStringAsFixed(2)} × $quantity',
                                      style: _lightDetail,
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '€${subtotal.toStringAsFixed(2)}',
                                style: _boldDark,
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 16),
                      const Divider(thickness: 1, color: Colors.black26),
                      const SizedBox(height: 12),

                      // ---- TOTALS ----
                      Builder(builder: (context) {
                        final double priceWithoutVat =
                            cartProvider.subtotal;
                        const double vatRate = 0.19;
                        final double vatAmount =
                            priceWithoutVat * vatRate;
                        final double grandTotal =
                            priceWithoutVat + vatAmount;

                        Widget _totalsRow(String label, double amount,
                            {bool isBold = false, bool big = false}) {
                          return Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: big ? 18 : 14,
                                  fontWeight: isBold
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: Color(0xFF1A2D3D),
                                ),
                              ),
                              Text(
                                '€${amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: big ? 18 : 14,
                                  fontWeight: isBold
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                  color: Color(0xFF1A2D3D),
                                ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            _totalsRow(
                                'Price (without VAT)', priceWithoutVat),
                            const SizedBox(height: 6),
                            _totalsRow('VAT (19%)', vatAmount),
                            const SizedBox(height: 10),
                            _totalsRow('Total (incl. VAT)', grandTotal,
                                isBold: true, big: true),
                          ],
                        );
                      }),

                      const SizedBox(height: 24),

                      const Text('DELIVERY TIME SLOT',
                          style: _sectionTitle),
                      const SizedBox(height: 6),
                      _buildChips(
                        ['Morning', 'Afternoon'],
                        selectedTimeSlot,
                            (val) => setState(() => selectedTimeSlot = val),
                      ),

                      const SizedBox(height: 24),

                      const Text('PAYMENT METHOD',
                          style: _sectionTitle),
                      const SizedBox(height: 6),

                      _showPaymentMethodPicker(),
                      const SizedBox(height: 8),

                      // ---- PAY WITH DIFFERENT CARD BUBBLE ----
                      GestureDetector(
                        onTap: _showCardSelectionSheet,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              )
                            ],
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.credit_card,
                                  color: Color(0xFF0E1A36)),
                              SizedBox(width: 12),
                              Text(
                                'Pay with a different card',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0E1A36),
                                ),
                              ),
                              Spacer(),
                              Icon(Icons.keyboard_arrow_right,
                                  color: Color(0xFF0E1A36)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      const Text(
                        'You can use a saved card here, or choose a new card on the next step.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),

                      const SizedBox(height: 24),

                      // ---- PLACE ORDER BUTTON ----
                      GestureDetector(
                        onTap:
                        (canPlace && !_placing) ? _placeOrder : null,
                        child: Opacity(
                          opacity: canPlace ? 1 : 0.5,
                          child: Container(
                            width: double.infinity,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Color(0xFF1A2D3D),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: const Text(
                              'Place Order',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

          // ---- LOADING OVERLAY ----
          _loadingOverlay(),
        ],
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
  static const TextStyle _secondaryStyle =
  TextStyle(fontSize: 13, color: Colors.black87);
  static const TextStyle _lightDetail =
  TextStyle(fontSize: 13, color: Colors.black54);

  BoxDecoration _glassDecoration() => BoxDecoration(
    color: Colors.white.withOpacity(0.3),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.4)),
    boxShadow: const [
      BoxShadow(
          color: Colors.black12,
          blurRadius: 8,
          offset: Offset(0, 4)),
      BoxShadow(
          color: Colors.white24,
          blurRadius: 2,
          offset: Offset(0, -2)),
    ],
  );

  Widget _buildAddressSelector() {
    final type = selectedAddress?['type'] ?? 'other';

    return GestureDetector(
      onTap: () => _showAddressPickerModal(), // opens bottom sheet
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4)),
            BoxShadow(
                color: Colors.white24,
                blurRadius: 2,
                offset: Offset(0, -2)),
          ],
        ),
        child: Row(
          children: [
            Icon(
              addressIcon(type),
              size: 20,
              color: const Color(0xFF1A233D),
            ),

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
            const Icon(Icons.keyboard_arrow_down,
                color: Color(0xFF1A233D)),
          ],
        ),
      ),
    );
  }

  Widget _buildChips(
      List<String> options, String selected, Function(String) onChanged) {
    return Wrap(
      spacing: 10,
      children: options.map((val) {
        final isSelected = selected == val;
        final label = {
          'Morning': 'Morning (9–15)',
          'Afternoon': 'Afternoon (15–21)',
          'Weekly': 'Weekly',
          'Monthly': 'Monthly',
          'COD': 'COD',
          'Card': 'Card',
        }[val] ??
            val;

        return ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 14)),
          selected: isSelected,
          selectedColor: const Color(0xFF1A2D3D),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          side: isSelected
              ? null
              : const BorderSide(color: Colors.black, width: 1),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
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
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Stack(
            children: [
              // ===== Scrollable address list =====
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 90),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select Delivery Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Expanded(
                      child: ListView.builder(
                        itemCount: addressList.length,
                        itemBuilder: (context, index) {
                          final a = addressList[index];
                          final type = a['type'] ?? 'other';
                          final isSelected = selectedAddress?['id'] == a['id'];

                          return ListTile(
                            leading: Icon(addressIcon(type), color: Colors.black54),
                            title: Text(
                              a['label'] ?? '',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : null,
                            onTap: () {
                              setState(() => selectedAddress = a);
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // ===== Fixed bottom button =====
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);

                    final picked = await Navigator.push<Map<String, dynamic>?>(
                      context,
                      MaterialPageRoute(builder: (_) => const PickLocationPage()),
                    );

                    await _loadAddresses();
                    if (!mounted) return;

                    setState(() {
                      final idx = addressList.indexWhere((a) => a['isDefault'] == true);
                      selectedAddress =
                      idx >= 0 ? addressList[idx] : (addressList.isNotEmpty ? addressList.first : null);
                    });

                    if (picked != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address saved')),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Add new Address"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D2952),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.25)
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.black
                : Colors.black.withOpacity(0.2),
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
}
