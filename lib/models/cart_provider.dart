import 'package:flutter/material.dart';
import 'product.dart';

class CartProvider extends ChangeNotifier {
  // We keep the existing Map structure to avoid breaking other files for now.
  // Each item map has: { 'product': Product, 'size': String, 'package': String, 'quantity': int }
  final List<Map<String, dynamic>> _cartItems = [];

  // Public, read-only view
  List<Map<String, dynamic>> get cartItems => List.unmodifiable(_cartItems);

  /// ✅ NEW: Simple add for SIMPLE products (no size/package needed).
  /// Merges by product.id only.
  void add(Product product, {int qty = 1}) {
    if (qty < 1) qty = 1; // ✅ clamp on adds
    final idx = _cartItems.indexWhere((it) => (it['product'] as Product).id == product.id);

    if (idx != -1) {
      _cartItems[idx]['quantity'] = (_cartItems[idx]['quantity'] as int) + qty;
    } else {
      _cartItems.add({
        'product': product,
        'size': '',      // kept for backward compatibility
        'package': '',   // kept for backward compatibility
        'quantity': qty,
      });
    }
    notifyListeners();
  }

  /// ✅ Backward-compatible: if other code still calls addToCart(...),
  /// we IGNORE size/package for merging (simple products).
  void addToCart(Product product, String size, String package, int quantity) {
    if (quantity < 1) quantity = 1; // ✅ clamp on legacy adds
    final idx = _cartItems.indexWhere((it) => (it['product'] as Product).id == product.id);

    if (idx != -1) {
      _cartItems[idx]['quantity'] = (_cartItems[idx]['quantity'] as int) + quantity;
    } else {
      _cartItems.add({
        'product': product,
        'size': size,         // stored for display if you want
        'package': package,   // stored for display if you want
        'quantity': quantity,
      });
    }
    notifyListeners();
  }

  /// Remove by list index (existing behavior)
  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  /// ✅ NEW: Remove by productId (easier for simple products)
  void remove(int productId) {
    _cartItems.removeWhere((it) => (it['product'] as Product).id == productId);
    notifyListeners();
  }

  /// Update quantity by list index (existing behavior)
  void updateQuantity(int index, int newQty) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index]['quantity'] = newQty.clamp(1, 9999);
      notifyListeners();
    }
  }

  /// ✅ NEW: Update quantity by productId (preferred going forward)
  void updateQty(int productId, int newQty) {
    final idx = _cartItems.indexWhere((it) => (it['product'] as Product).id == productId);
    if (idx != -1) {
      _cartItems[idx]['quantity'] = newQty.clamp(1, 9999);
      notifyListeners();
    }
  }

  /// Clear entire cart
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  /// Count of units in cart
  int get totalItems => _cartItems.fold<int>(0, (sum, it) => sum + (it['quantity'] as int));

  /// Subtotal (price * qty)
  double get subtotal => _cartItems.fold<double>(0.0, (sum, it) {
    final p = it['product'] as Product;
    final q = it['quantity'] as int;
    return sum + (p.price * q);
  });

  /// Backward name kept for now; same as subtotal (we'll add shipping/tax later)
  double get totalCost => subtotal;

  /// ✅ Handy: get current qty of a product (or 0 if not in cart)
  int qtyOf(int productId) {
    final idx = _cartItems.indexWhere((it) => (it['product'] as Product).id == productId);
    if (idx == -1) return 0;
    return _cartItems[idx]['quantity'] as int;
  }
}
