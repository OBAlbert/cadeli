import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PaymentService {
  static const String _stripePublishableKey = 'pk_test_YOUR_PUBLISHABLE_KEY_HERE';
  static const String _stripeSecretKey = 'sk_test_YOUR_SECRET_KEY_HERE';
  static const String _baseUrl = 'https://api.stripe.com/v1';

  static Future<void> initialize() async {
    Stripe.publishableKey = _stripePublishableKey;
    await Stripe.instance.applySettings();
  }

  // Create Payment Intent
  static Future<Map<String, dynamic>?> createPaymentIntent({
    required double amount,
    required String currency,
    required String customerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/payment_intents'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'amount': (amount * 100).round().toString(), // Convert to cents
          'currency': currency.toLowerCase(),
          'customer': customerId,
          'automatic_payment_methods[enabled]': 'true',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to create payment intent: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error creating payment intent: $e');
      return null;
    }
  }

  // Process Card Payment
  static Future<bool> processCardPayment({
    required double amount,
    required String currency,
    required BuildContext context,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Create payment intent
      final paymentIntent = await createPaymentIntent(
        amount: amount,
        currency: currency,
        customerId: await _getOrCreateCustomerId(),
      );

      if (paymentIntent == null) {
        throw Exception('Failed to create payment intent');
      }

      // Initialize payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntent['client_secret'],
          merchantDisplayName: 'Cadeli Water Delivery',
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF1A233D),
            ),
          ),
        ),
      );

      // Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Payment successful
      await _savePaymentRecord(paymentIntent['id'], amount, currency, metadata);
      return true;

    } on StripeException catch (e) {
      debugPrint('Stripe error: ${e.error.localizedMessage}');
      _showErrorSnackBar(context, e.error.localizedMessage ?? 'Payment failed');
      return false;
    } catch (e) {
      debugPrint('Payment error: $e');
      _showErrorSnackBar(context, 'Payment failed. Please try again.');
      return false;
    }
  }

  // Save payment method for future use
  static Future<bool> savePaymentMethod(BuildContext context) async {
    try {
      final customerId = await _getOrCreateCustomerId();
      
      // Initialize setup intent for saving payment method
      final setupIntent = await _createSetupIntent(customerId);
      
      if (setupIntent == null) return false;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          setupIntentClientSecret: setupIntent['client_secret'],
          merchantDisplayName: 'Cadeli Water Delivery',
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFF1A233D),
            ),
          ),
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      
      // Save payment method reference in Firestore
      await _savePaymentMethodReference(setupIntent['payment_method']);
      return true;

    } catch (e) {
      debugPrint('Error saving payment method: $e');
      _showErrorSnackBar(context, 'Failed to save payment method');
      return false;
    }
  }

  // Get saved payment methods
  static Future<List<Map<String, dynamic>>> getSavedPaymentMethods() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('payment_methods')
          .get();

      return doc.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    } catch (e) {
      debugPrint('Error fetching payment methods: $e');
      return [];
    }
  }

  // Process subscription payment
  static Future<bool> createSubscription({
    required double amount,
    required String interval, // 'week', 'month'
    required BuildContext context,
  }) async {
    try {
      final customerId = await _getOrCreateCustomerId();
      
      // Create subscription
      final response = await http.post(
        Uri.parse('$_baseUrl/subscriptions'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
          'items[0][price_data][currency]': 'eur',
          'items[0][price_data][product_data][name]': 'Water Delivery Subscription',
          'items[0][price_data][unit_amount]': (amount * 100).round().toString(),
          'items[0][price_data][recurring][interval]': interval,
          'payment_behavior': 'default_incomplete',
          'payment_settings[save_default_payment_method]': 'on_subscription',
          'expand[]': 'latest_invoice.payment_intent',
        },
      );

      if (response.statusCode == 200) {
        final subscription = json.decode(response.body);
        
        // Handle payment confirmation if needed
        final paymentIntent = subscription['latest_invoice']['payment_intent'];
        if (paymentIntent['status'] == 'requires_action') {
          await Stripe.instance.confirmPayment(
            paymentIntentClientSecret: paymentIntent['client_secret'],
          );
        }

        await _saveSubscriptionRecord(subscription);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Subscription error: $e');
      _showErrorSnackBar(context, 'Failed to create subscription');
      return false;
    }
  }

  // Private helper methods
  static Future<String> _getOrCreateCustomerId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    String? customerId = userDoc.data()?['stripeCustomerId'];

    if (customerId == null) {
      // Create new Stripe customer
      final response = await http.post(
        Uri.parse('$_baseUrl/customers'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'email': user.email ?? '',
          'name': userDoc.data()?['fullName'] ?? '',
          'metadata[firebase_uid]': user.uid,
        },
      );

      if (response.statusCode == 200) {
        final customer = json.decode(response.body);
        customerId = customer['id'];

        // Save customer ID to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'stripeCustomerId': customerId});
      } else {
        throw Exception('Failed to create Stripe customer');
      }
    }

    return customerId!;
  }

  static Future<Map<String, dynamic>?> _createSetupIntent(String customerId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/setup_intents'),
        headers: {
          'Authorization': 'Bearer $_stripeSecretKey',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'customer': customerId,
          'payment_method_types[]': 'card',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      debugPrint('Error creating setup intent: $e');
      return null;
    }
  }

  static Future<void> _savePaymentRecord(
    String paymentIntentId,
    double amount,
    String currency,
    Map<String, dynamic>? metadata,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('payments').add({
      'uid': user.uid,
      'paymentIntentId': paymentIntentId,
      'amount': amount,
      'currency': currency,
      'status': 'completed',
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': metadata ?? {},
    });
  }

  static Future<void> _savePaymentMethodReference(String? paymentMethodId) async {
    if (paymentMethodId == null) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('payment_methods')
        .add({
      'paymentMethodId': paymentMethodId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _saveSubscriptionRecord(Map<String, dynamic> subscription) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({
      'subscription': {
        'id': subscription['id'],
        'status': subscription['status'],
        'currentPeriodEnd': subscription['current_period_end'],
        'interval': subscription['items']['data'][0]['price']['recurring']['interval'],
        'amount': subscription['items']['data'][0]['price']['unit_amount'] / 100,
      }
    });
  }

  static void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }
}

