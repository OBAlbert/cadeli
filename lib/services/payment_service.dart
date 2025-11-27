// lib/services/payment_service.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// What we receive after the backend creates the Woo + Firestore order.
class CreateOrderResult {
  final String docId;          // Firestore order doc ID
  final int wooOrderId;        // WooCommerce order ID
  final String orderKey;       // Woo order key
  final Uri payUrl;            // Woo hosted payment URL
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
  final FirebaseFunctions _functions =
  FirebaseFunctions.instanceFor(app: Firebase.app(), region: 'us-central1');

  HttpsCallable _call(String name) => _functions.httpsCallable(
    name,
    options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
  );

  // ---------------------------------------------------------------
  // 1) Create Woo order + Firestore subscription (always subscriptions)
  // ---------------------------------------------------------------
  Future<CreateOrderResult> createWooOrderAuthorized({
    required List<Map<String, dynamic>> cartItems,
    required Map<String, dynamic> address,
    Map<String, dynamic>? meta,
  }) async {
    // Shape items as simple maps
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
      'cartItems': items,
      'address': address,
      'meta': meta ?? {},
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

  // ---------------------------------------------------------------
  // 2) Create Stripe PaymentSheet (manual-capture flow)
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> createStripePaymentSheet({
    required String orderId,
    required String mode, // keep for analytics/debug
  }) async {
    final res = await _call('createPaymentSheet')
        .call({'orderId': orderId, 'mode': mode});

    return Map<String, dynamic>.from(res.data as Map);
  }

  // ---------------------------------------------------------------
  // 3) Payment method management (saved cards)
  // ---------------------------------------------------------------
  Future<List<Map<String, dynamic>>> listPaymentMethods() async {
    final res = await _call('listPaymentMethods').call();
    final rawList = res.data as List;
    return rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> createSetupIntent() async {
    final res = await _call('addPaymentMethod').call();
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> deletePaymentMethod(String id) async {
    await _call('deletePaymentMethod').call({'id': id});
  }

  Future<void> setDefaultPaymentMethod(String id) async {
    await _call('setDefaultPaymentMethod').call({'id': id});
  }

  // ---------------------------------------------------------------
  // Debug helper
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> debugWhoAmI() async {
    final res = await _call('debugWhoAmI').call();
    return Map<String, dynamic>.from(res.data as Map);
  }
}
