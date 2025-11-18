// lib/services/payment_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Result we need back in the app after placing an order.
class CreateOrderResult {
  final String docId;        // Firestore order doc id (used by admin/dashboard)
  final int wooOrderId;      // WooCommerce order id
  final String orderKey;     // Woo order key
  final Uri payUrl;          // Hosted Woo pay URL (useful for COD or retries)
  final String? total;
  final String? currency;

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

  HttpsCallable _call(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  /// 1) Create an UNPAID Woo order on server → server writes Firestore → returns docId/payUrl.
  Future<CreateOrderResult> createWooOrderAuthorized({
    required String userId,
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic> address,
    required String paymentMethodSlug, // 'stripe' or 'cod'
    Map<String, dynamic>? meta,
  }) async {
    final items = cartItems.map((it) {
      final prodId = it['id'] ?? it['product']?.id;
      return {
        'id': prodId.toString(),
        'name': it['name'] ?? it['product']?.name ?? '',
        'brand': it['brand'] ?? it['product']?.brand ?? '',
        'price': it['price'] ?? it['product']?.price ?? 0.0,
        'imageUrl': it['imageUrl'] ?? it['product']?.imageUrl ?? '',
        'quantity': (it['quantity'] as num?)?.toInt() ?? 1,
      };
    }).toList();


    final res = await _call('createWooOrderFromCart').call({
      'userId': userId,
      'cartItems': items,
      'address': address,
      'paymentMethod': paymentMethodSlug,
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
  }

  /// 2) Create the Stripe PaymentSheet for THAT order (manual-capture PI).
  Future<Map<String, dynamic>> createStripePaymentSheet({
    required String orderId,
    required String mode, // 'subscription' or 'one_time' (purely for your analytics/metadata)
  }) async {
    final res = await _call('createPaymentSheet').call({'orderId': orderId, 'mode': mode});
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// COD helper remains for COD flow.
  Future<CreateOrderResult> placeCodOrderFromCart({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> address,
    required Map<String, dynamic> meta,
  }) async {
    final shaped = items.map((it) {
      final prodId = it['id'] ?? it['product']?.id;
      return {
        'id': prodId.toString(),
        'name': it['name'] ?? it['product']?.name ?? '',
        'brand': it['brand'] ?? it['product']?.brand ?? '',
        'price': it['price'] ?? it['product']?.price ?? 0.0,
        'imageUrl': it['imageUrl'] ?? it['product']?.imageUrl ?? '',
        'quantity': (it['quantity'] as num?)?.toInt() ?? 1,
      };
    }).toList();


    final res = await _call('placeCodOrderFromCart').call({
      'cartItems': shaped,
      'address': address,
      'meta': meta,
    });

    final data = Map<String, dynamic>.from(res.data as Map);
    return CreateOrderResult(
      docId: (data['docId'] ?? '').toString(),
      wooOrderId: (data['wooOrderId'] as num?)?.toInt() ?? 0,
      orderKey: (data['orderKey'] ?? '').toString(),
      payUrl: Uri.parse((data['payUrl'] ?? '') as String),
      total: data['total']?.toString(),
      currency: data['currency']?.toString(),
    );
  }

  /// Quick debug (optional).
  Future<Map<String, dynamic>> debugWhoAmI() async {
    final res = await _call('debugWhoAmI').call();
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<List<Map<String, dynamic>>> listPaymentMethods() async {
    final res = await _call('listPaymentMethods').call();
    final rawList = res.data as List;
    return rawList
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<Map<String, dynamic>> createSetupIntent() async {
    final res = await _call('addPaymentMethod').call();
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deletePaymentMethod(String id) async {
    await _call('deletePaymentMethod').call({'id': id});
  }

}


