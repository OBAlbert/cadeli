import 'dart:async';
import 'package:cadeli/screens/pick_location_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import '../services/chat_service.dart';
import '../widget/app_scaffold.dart';
import 'chat_thread_page.dart';
import 'main_page.dart';
import '../services/woocommerce_service.dart';
import '../services/payment_service.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../models/payment_method.dart' as apppay;
import 'dart:io';


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
  Map<String, dynamic>? selectedAddress;
  List<Map<String, dynamic>> addressList = [];
  final WooCommerceService wooService = WooCommerceService();
  String? _selectedCardId;


  final _payment = PaymentService();
  bool _placing = false;

  // Single source of truth for payment method
  String _selectedMethod = '';
  String? get selectedPayment => _selectedMethod;

  void _handlePaymentMethodSelection(String method) {
    setState(() {
      _selectedMethod = method; // 'card' or 'cod'
    });
  }

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
      await user.getIdToken(true);

      // 🛒 cart → [{id, quantity}]
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

      double? _toDouble(dynamic v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      // ✅ robust lat/lng extractor
      double? lat, lng;
      final addr = selectedAddress ?? {};

      if (addr['geo'] is GeoPoint) {
        final g = addr['geo'] as GeoPoint;
        lat = g.latitude; lng = g.longitude;
      }
      if ((lat == null || lng == null) && addr['location'] is GeoPoint) {
        final g = addr['location'] as GeoPoint;
        lat = g.latitude; lng = g.longitude;
      }

      lat ??= _toDouble(addr['lat'] ?? addr['latitude']);
      lng ??= _toDouble(addr['lng'] ?? addr['longitude']);

      final loc = addr['location'];
      if ((lat == null || lng == null) && loc is Map) {
        lat ??= _toDouble(loc['lat']);
        lng ??= _toDouble(loc['lng']);
      }

      final coords = addr['coords'];
      if ((lat == null || lng == null) && coords is Map) {
        lat ??= _toDouble(coords['lat']);
        lng ??= _toDouble(coords['lng']);
      }

      // 🔎 backfill from saved address if needed
      try {
        final addrId = addr['id'] ?? addr['addressId'];
        if ((lat == null || lng == null) && addrId != null) {
          final addrDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('addresses')
              .doc(addrId.toString())
              .get();
          final a = addrDoc.data();
          if (a != null) {
            if (a['geo'] is GeoPoint) {
              final g = a['geo'] as GeoPoint;
              lat ??= g.latitude; lng ??= g.longitude;
            }
            if (a['location'] is GeoPoint) {
              final g = a['location'] as GeoPoint;
              lat ??= g.latitude; lng ??= g.longitude;
            }
            lat ??= _toDouble(a['lat'] ?? a['latitude']);
            lng ??= _toDouble(a['lng'] ?? a['longitude']);
          }
        }
      } catch (e) {
        debugPrint('Could not backfill lat/lng from saved address: $e');
      }

      if (lat == null || lng == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please pick your exact location on the map.')),
        );
        setState(() => _placing = false);
        return;
      }

      // 🏷️ split first/last
      final parts = fullName.split(' ').where((s) => s.trim().isNotEmpty).toList();
      final firstName = parts.isNotEmpty ? parts.first : 'Customer';
      final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

      // 🏠 Woo-style address
      final wooAddress = {
        'first_name': firstName,
        'last_name' : lastName,
        'address_1': selectedAddress?['line1'] ?? selectedAddress?['address'] ?? 'Address',
        'city'     : selectedAddress?['city'] ?? 'Larnaca',
        'country'  : selectedAddress?['country'] ?? 'CY',
        'email'    : (userEmail.isNotEmpty ? userEmail : 'noemail@cadeli.app'),
        'phone'    : selectedAddress?['phone'] ?? '',
      };

      final meta = <String, dynamic>{
        'customer_name'      : fullName.isNotEmpty ? fullName : firstName,
        'address_line'       : wooAddress['address_1'],
        'city'               : wooAddress['city'],
        'country'            : wooAddress['country'],
        'phone'              : wooAddress['phone'],
        'delivery_type'      : isSubscription ? 'subscription' : 'normal',
        'time_slot'          : isSubscription ? selectedTimeSlot : null,
        'frequency'          : isSubscription ? selectedFrequency : null,
        'preferred_day'      : isSubscription ? selectedDay : null,
        'order_placed_at_ms' : DateTime.now().millisecondsSinceEpoch,
        'location_lat'       : lat,
        'location_lng'       : lng,
      }..removeWhere((k, v) => v == null);

      // ✅ basic validations
      if (_selectedMethod != 'card' && _selectedMethod != 'cod') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please choose a payment method.')),
        );
        setState(() => _placing = false);
        return;
      }

      if (isSubscription) {
        if ((selectedDay.isEmpty) || (selectedTimeSlot.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select preferred day and time slot.')),
          );
          setState(() => _placing = false);
          return;
        }
      }

      if (((wooAddress['address_1'] ?? '').toString().trim()).isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add your street address.')),
        );
        setState(() => _placing = false);
        return;
      }

      // ===================== FLOW =====================
      if (_selectedMethod == 'card') {
        // 1) Create Woo + Firestore order (unpaid, pending)
        final created = await _payment.createWooOrderAuthorized(
          userId: user.uid,
          cartItems: items,
          address: wooAddress,
          paymentMethodSlug: 'stripe',
          meta: meta,
        );
        final orderDocId = created.docId;

        // 2) Create manual-capture PaymentIntent tied to that orderDocId
        final sheet = await _payment.createStripePaymentSheet(
          orderId: orderDocId,
          mode: isSubscription ? 'subscription' : 'one_time',
        );

        final piSecret = sheet['paymentIntent'] as String?;
        final ek       = sheet['ephemeralKey'] as String?;
        final cust     = sheet['customer'] as String?;

        if (piSecret == null || ek == null || cust == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment setup failed (missing keys).')),
          );
          setState(() => _placing = false);
          return;
        }

        if (_selectedCardId != null && _selectedCardId!.isNotEmpty) {
          await Stripe.instance.confirmPayment(
            paymentIntentClientSecret: piSecret!,
            data: PaymentMethodParams.cardFromMethodId(
              paymentMethodData: PaymentMethodDataCardFromMethod(paymentMethodId: _selectedCardId!),
            ),
          );
          cart.clearCart();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Payment authorized.')));
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 2)),
                (route) => false,
          );
          return; // skip the PaymentSheet since we used saved card
        }


        // 3) Show Stripe PaymentSheet (AUTH only)
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
                  ? const PaymentSheetGooglePay(merchantCountryCode: 'CY', testEnv: true)
                  : null,
              style: ThemeMode.light,
              allowsDelayedPaymentMethods: false,
            ),
          );
          await Stripe.instance.presentPaymentSheet();
        } on StripeException catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Card not authorized: ${e.error.localizedMessage ?? e.toString()}')),
          );
          setState(() => _placing = false);
          return;
        }


        // If you DO have ChatService.instance.sendSystem, you can add:
        // await ChatService.instance.sendSystem(orderDocId, 'Payment authorized. Waiting for admin approval.');

        cart.clearCart();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment authorized. Awaiting approval.')),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 2)),
              (route) => false,
        );
        Future.microtask(() {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatThreadPage(orderId: orderDocId, customerId: user.uid),
            ),
          );
        });

      } else {
        // COD branch: server creates Woo+Firestore and posts first system message
        final res = await _payment.placeCodOrderFromCart(
          items: items,
          address: wooAddress,
          meta: meta,
        );


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed. Awaiting admin approval.')),
        );
        cart.clearCart();
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainPage(initialIndex: 2)),
              (route) => false,
        );
        Future.microtask(() {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChatThreadPage(orderId: res.docId, customerId: user.uid),
            ),
          );
        });
      }
      // ===============================================

    } catch (e) {
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
                      border: Border.all(color: Color(0xFF0E1A36), width: 1.5),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                            _selectedMethod = 'card';
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
                        const SnackBar(content: Text('Card added successfully.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0E1A36),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
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


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;
    final bool canPlace = cartItems.isNotEmpty && selectedAddress != null && _selectedMethod.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Checkout',
          style: TextStyle(
            fontSize: 24,                // matches Cart
            fontWeight: FontWeight.w800, // matches Cart
            color: Color(0xFF1A2D3D),
          ),
        ),
        leading: const SizedBox.shrink(),
      ),


      body: SafeArea(
          child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 30, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, size: 18, color: Colors.black),
                          SizedBox(width: 6),
                          Text('Cart', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  AnimatedBuilder(
                    animation: _tabAnimation,
                    builder: (_, __) => Container(
                      height: 48,
                      width: double.infinity,                               // full width within 20px page padding
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.black, width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () { setState(() => isSubscription = false); _controller.forward(from: 0); },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: !isSubscription ? const Color(0xFF1A233D) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Text(
                                  'Normal Delivery',
                                  style: TextStyle(
                                    color: !isSubscription ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () { setState(() => isSubscription = true); _controller.forward(from: 0); },
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSubscription ? const Color(0xFF1A233D) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                child: Text(
                                  'Subscription',
                                  style: TextStyle(
                                    color: isSubscription ? Colors.white : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
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
                            child: (product.imageUrl ?? '').toString().isNotEmpty
                                ? Image.network(product.imageUrl, width: 60, height: 60, fit: BoxFit.cover)
                                : const SizedBox(width: 60, height: 60, child: Icon(Icons.image_not_supported)),

                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, style: _boldDark),
                                // Show "size • package" only when each part exists; otherwise show whichever exists; never show a lone slash.
                                if ((item['size']?.toString().isNotEmpty ?? false) && (item['package']?.toString().isNotEmpty ?? false))
                                  Text('${item['size']} • ${item['package']}', style: _secondaryStyle)
                                else if ((item['size']?.toString().isNotEmpty ?? false))
                                  Text('${item['size']}', style: _secondaryStyle)
                                else if ((item['package']?.toString().isNotEmpty ?? false))
                                    Text('${item['package']}', style: _secondaryStyle),
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

// Mirror Cart totals: Price (without VAT), VAT, Total (incl. VAT)
                  Builder(builder: (context) {
                    final double priceWithoutVat = cartProvider.subtotal;
                    const double vatRate = 0.19; // 19% CY
                    final double vatAmount = priceWithoutVat * vatRate;
                    final double grandTotal = priceWithoutVat + vatAmount;

                    Widget _totalsRow(String label, double amount, {bool isBold = false, bool big = false}) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: big ? 18 : 14,
                              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                              color: const Color(0xFF1A2D3D),
                            ),
                          ),
                          Text(
                            '€${amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: big ? 18 : 14,
                              fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
                              color: const Color(0xFF1A2D3D),
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        _totalsRow('Price (without VAT)', priceWithoutVat),
                        const SizedBox(height: 6),
                        _totalsRow('VAT (19%)', vatAmount),
                        const SizedBox(height: 10),
                        _totalsRow('Total (incl. VAT)', grandTotal, isBold: true, big: true),
                      ],
                    );
                  }),




                  if (isSubscription) ...[
                    const SizedBox(height: 24),
                    const Text('DELIVERY TIME SLOT', style: _sectionTitle),
                    const SizedBox(height: 6),
                    _buildChips(['Morning', 'Afternoon', 'Evening'], selectedTimeSlot, (val) {
                      setState(() => selectedTimeSlot = val);
                    }),

                    const SizedBox(height: 24),
                    const Text('FREQUENCY', style: _sectionTitle),
                    const SizedBox(height: 6),
                              // Weekly only – fixed, not interactive
                    ChoiceChip(
                      label: Text('Weekly', style: TextStyle(fontSize: 14)),
                      selected: true,
                      onSelected: null, // disables interaction
                      selectedColor: Color(0xFF1A233D),
                      labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 24),
                    const Text('PREFERRED DAY', style: _sectionTitle),
                    const SizedBox(height: 6),
                    _buildGlassDropdownDay(),
                  ],

                  const SizedBox(height: 24),
                  const Text('PAYMENT METHOD', style: _sectionTitle),
                  _showPaymentMethodPicker(),
                  const SizedBox(height: 12),

                  const SizedBox(height: 6),

                  _buildPaymentButton(
                    icon: Icons.credit_card_outlined,
                    label: 'Pay with Card',
                    isSelected: _selectedMethod == 'card',
                    onTap: _showCardSelectionSheet,
                  ),

                  _buildPaymentButton(
                    icon: Icons.euro, // use Euro for cash to avoid the $ sign
                    label: 'Cash on Delivery',
                    isSelected: _selectedMethod == 'cod',
                    onTap: () => _handlePaymentMethodSelection('cod'),
                  ),


                  const SizedBox(height: 24),

                  GestureDetector(
                    onTap: (canPlace && !_placing) ? _placeOrder : null,
                    child: Opacity(
                      opacity: canPlace ? 1 : 0.5,
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2D3D),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Place Order',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
    boxShadow: const [
      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
      BoxShadow(color: Colors.white24, blurRadius: 2, offset: Offset(0, -2)),
    ],
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
            BoxShadow(color: Colors.white24, blurRadius: 2, offset: Offset(0, -2)),
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
                trailing: (selectedAddress?['id'] == a['id'])
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
                  selectedAddress = idx >= 0
                      ? addressList[idx]
                      : (addressList.isNotEmpty ? addressList.first : null);
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

  Widget _buildPaymentCard({required apppay.PaymentMethod method}) {
    String asset = 'visa.png';
    if (method.type == 'mastercard') asset = 'mastercard.png';

    bool isSelected = selectedPayment == method.type;

    return GestureDetector(
      onTap: () {
        _handlePaymentMethodSelection(method.type); // ✅ Use the setter method
      },      child: Container(
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
      onTap: () async {
        _handlePaymentMethodSelection('card'); // ✅ Use the setter method
        await _placeOrder();
      },      child: Container(
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
