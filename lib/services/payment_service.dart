// lib/services/payment_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

/// Result we need back in the app after placing an order.
class CreateOrderResult {
  final String docId;        // Firestore order doc id (used by your admin/dashboard)
  final int wooOrderId;      // WooCommerce order id
  final String orderKey;     // Woo order key
  final Uri payUrl;          // Hosted payment URL (Stripe/Woo) to open
  final String? total;       // Optional display
  final String? currency;    // Optional display

  const CreateOrderResult({
    required this.docId,
    required this.wooOrderId,
    required this.orderKey,
    required this.payUrl,
    this.total,
    this.currency,
  });
}

class PaymentService {
  // If your functions are NOT in us-central1, change the region here.
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  // Optional: centralize callable options (timeout etc.)
  HttpsCallable _call(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  /// Create an UNPAID Woo order on server → server writes Firestore → returns payUrl.
  ///
  /// [cartItems] MUST be a list like: [{'id': 123, 'quantity': 2}, ...]
  /// [address] keys expected by server: first_name, last_name, address_1, city, country, email, phone
  /// [paymentMethodSlug]: 'stripe' for card, 'cod' for cash on delivery
  Future<CreateOrderResult> createWooOrderAuthorized({
    required String userId,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic> address,
    required String paymentMethodSlug,
    Map<String, dynamic>? meta,
  }) async {
    try {
      // Shape items safely (accepts either maps with 'product' or 'id')
      final items = cartItems.map((item) {
        final prodId = item['product'] != null ? item['product'].id : item['id'];
        final qty = (item['quantity'] as num?)?.toInt() ?? 1;
        return {
          'id': int.tryParse(prodId.toString()) ?? 0,
          'quantity': qty,
        };
      }).toList();

      final callable = _call('createWooOrderFromCart');
      final res = await callable.call({
        'userId': userId,
        'cartItems': items,
        'address': address,
        'paymentMethod': paymentMethodSlug, // <-- must be 'paymentMethod'
        'meta': meta ?? {},
      });

      final data = Map<String, dynamic>.from(res.data as Map);

      final docId = (data['docId'] ?? '') as String;
      final wooOrderId = (data['wooOrderId'] as num?)?.toInt() ?? 0;
      final orderKey = (data['orderKey'] ?? '') as String;
      final payUrlStr = (data['payUrl'] ?? '') as String;

      if (docId.isEmpty || wooOrderId == 0 || orderKey.isEmpty || payUrlStr.isEmpty) {
        throw Exception('Invalid response from server: $data');
      }

      return CreateOrderResult(
        docId: docId,
        wooOrderId: wooOrderId,
        orderKey: orderKey,
        payUrl: Uri.parse(payUrlStr),
        total: data['total']?.toString(),
        currency: data['currency']?.toString(),
      );
    } catch (e) {
      // Surface to caller
      rethrow;
    }
  }

  /// Open the hosted Woo/Stripe checkout page in the external browser.
  /// (Use this if you DON'T want an in-app WebView.)
  Future<void> openPayUrl(Uri url) async {
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw 'Could not open $url';
    }
  }

  /// Capture payment server-side (admin accept).
  /// If you pass [docId], server should mirror Firestore status.
  Future<bool> capturePaymentServerSide({
    required int orderId,
    String? docId,
  }) async {
    try {
      final callable = _call('captureWooPayment');
      final res = await callable.call({'orderId': orderId, 'docId': docId});
      final data = Map<String, dynamic>.from(res.data as Map);
      final status = (data['status'] ?? '').toString().toLowerCase();
      return status == 'completed' || status == 'processing' || data['set_paid'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Void / cancel the Woo order (admin reject).
  Future<bool> voidPaymentServerSide({required int orderId}) async {
    try {
      final callable = _call('voidWooPayment');
      final res = await callable.call({'orderId': orderId});
      final data = Map<String, dynamic>.from(res.data as Map);
      return (data['status']?.toString().toLowerCase() == 'cancelled');
    } catch (_) {
      return false;
    }
  }

  /// Small debug helper to verify callable auth context.
  Future<Map<String, dynamic>> debugWhoAmI() async {
    final callable = _call('debugWhoAmI');
    final res = await callable.call();
    return Map<String, dynamic>.from(res.data as Map);
  }
}
