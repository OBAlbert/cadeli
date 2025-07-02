// 🔧 lib/services/sync_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cadeli/models/product.dart';
import 'package:cadeli/services/woocommerce_service.dart';

class SyncService {
  static Future<void> syncWooProductsToFirestore() async {
    final firestore = FirebaseFirestore.instance;
    final wooProducts = await WooCommerceService().fetchProducts();

    final batch = firestore.batch();
    final productsCollection = firestore.collection('products');

    // 1. Clear existing Firestore products
    final existingDocs = await productsCollection.get();
    for (final doc in existingDocs.docs) {
      batch.delete(doc.reference);
    }

    // 2. Add WooCommerce products
    for (final productJson in wooProducts) {
      final product = Product.fromWooJson(productJson);
      final docRef = productsCollection.doc(product.id); // Woo ID as doc ID

      batch.set(docRef, {
        'id': product.id,
        'name': product.name,
        'brand': product.brand,
        'price': product.price,
        'imageUrl': product.imageUrl,
        'sizeOptions': product.sizeOptions,
        'packOptions': product.packOptions,
        'categories': product.categories,
      });
    }

    await batch.commit();
    print('✅ Synced WooCommerce products to Firestore.');
  }
}
