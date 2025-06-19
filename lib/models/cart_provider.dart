import 'package:flutter/material.dart';
import 'product.dart';

class CartProvider extends ChangeNotifier {
  // Private list storing each cart item as a map
  final List<Map<String, dynamic>> _cartItems = [];

  // Public getter to expose cart items to the UI
  List<Map<String, dynamic>> get cartItems => _cartItems;

  /// Adds a product to the cart, or updates the quantity if it already exists
  void addToCart(Product product, String size, String package, int quantity) {
    final existingIndex = _cartItems.indexWhere((item) =>
    item['product'].id == product.id &&
        item['size'] == size &&
        item['package'] == package
    );

    if (existingIndex != -1) {
      _cartItems[existingIndex]['quantity'] += quantity;
    } else {
      _cartItems.add({
        'product': product,
        'size': size,
        'package': package,
        'quantity': quantity,
      });
    }

    notifyListeners();
  }

  /// Removes a product at a given index
  void removeFromCart(int index) {
    _cartItems.removeAt(index);
    notifyListeners();
  }

  /// Updates the quantity of an item at the specified index
  void updateQuantity(int index, int newQty) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index]['quantity'] = newQty;
      notifyListeners();
    }
  }

  /// Clears the entire cart
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  /// Returns the total number of items in the cart
  int get totalItems =>
      _cartItems.fold(0, (sum, item) => sum + item['quantity'] as int);

  /// Returns the total cost of the cart
  double get totalCost => _cartItems.fold(0.0, (sum, item) {
    final product = item['product'] as Product;
    final int qty = item['quantity'];
    return sum + (product.price * qty);
  });
}
