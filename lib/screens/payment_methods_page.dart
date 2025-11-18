import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../models/payment_method.dart' as app;
import '../services/payment_service.dart';
import '../screens/payment_prefs.dart';

class PaymentMethodsPage extends StatefulWidget {
  const PaymentMethodsPage({super.key});

  @override
  State<PaymentMethodsPage> createState() => _PaymentMethodsPageState();
}

class _PaymentMethodsPageState extends State<PaymentMethodsPage> {
  final PaymentService _paymentService = PaymentService();
  List<Map<String, dynamic>> savedCards = [];
  app.PaymentMethod? selectedMethod;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
  }

  Future<void> _loadSavedCards() async {
    setState(() => _loading = true);
    try {
      final cards = await _paymentService.listPaymentMethods();
      setState(() => savedCards = cards);
    } catch (e) {
      debugPrint('Error loading cards: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load saved cards')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  void _selectMethod(app.PaymentMethod method) async {
    await PaymentPrefs.saveSelectedPaymentMethod(method);
    setState(() => selectedMethod = method);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected ${method.type.toUpperCase()}')),
    );
  }

  Future<void> _addNewCard() async {
    try {
      // 1️⃣ Create setup intent & customer
      final setup = await _paymentService.createSetupIntent();
      final clientSecret = setup['clientSecret'];
      final customerId = setup['customerId'];

      // 2️⃣ Initialize PaymentSheet for saving a card
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Cadeli',
          customerId: customerId,
          setupIntentClientSecret: clientSecret,
          style: ThemeMode.light,
          allowsDelayedPaymentMethods: false,
        ),
      );

      // 3️⃣ Present sheet (saves the card)
      await Stripe.instance.presentPaymentSheet();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card added successfully')),
      );

      // 4️⃣ Refresh saved list
      await _loadSavedCards();
    } on StripeException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment sheet cancelled: ${e.error.localizedMessage ?? e.toString()}')),
      );
    } catch (e) {
      debugPrint('Error adding card: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add card: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ Added AppBar
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0E1A36)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0E1A36),
          ),
        ),
        centerTitle: true,
      ),

      // ✅ Page Body
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (savedCards.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      'No saved cards yet',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 130,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: savedCards.length,
                    itemBuilder: (context, i) {
                      final card = savedCards[i];
                      return _buildCard(
                        method: app.PaymentMethod(
                          type: card['brand'] ?? '',
                          last4: card['last4'] ?? '',
                          expiry: '${card['exp_month']}/${card['exp_year']}',
                        ),
                        stripeId: card['id'],
                      );
                    },
                  ),
                ),

              const Spacer(),

              // ✅ Add New Card Button
              GestureDetector(
                onTap: _addNewCard,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: Color(0xFF0E1A36)),
                      SizedBox(width: 10),
                      Text(
                        'Add New Card',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF0E1A36),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required app.PaymentMethod method, String? stripeId}) {
    final isSelected = selectedMethod?.last4 == method.last4;
    String asset = 'visa.png';
    if (method.type.contains('master')) asset = 'mastercard.png';
    if (method.type.contains('amex')) asset = 'amex.png';

    return GestureDetector(
      onTap: () => _selectMethod(method),
      onLongPress: stripeId != null ? () => _showCardMenu(stripeId) : null,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF0E1A36) : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset("assets/icons/$asset", width: 40, height: 40),
            const SizedBox(height: 10),
            Text(
              "**** ${method.last4}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0E1A36),
              ),
            ),
            Text(
              method.expiry,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1A233D),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Future<void> _deleteCard(String id) async {
    try {
      await _paymentService.deletePaymentMethod(id);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card deleted')),
      );
      await _loadSavedCards();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  void _showCardMenu(String id) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete card'),
            onTap: () {
              Navigator.pop(context);
              _deleteCard(id);
            },
          ),
        ]),
      ),
    );
  }


}
