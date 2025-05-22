import 'package:flutter/material.dart';
import 'product.dart';

class CartProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _cartItems = [];

  List<Map<String, dynamic>> get cartItems => _cartItems;

  void addToCart(Product product, String size, String package, int quantity) {
    final existingIndex = _cartItems.indexWhere((item) =>
    item['product'].name == product.name &&
        item['size'] == size &&
        item['package'] == package);

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

  void removeFromCart(int index) {
    _cartItems.removeAt(index);
    notifyListeners();
  }

  void updateQuantity(int index, int newQuantity) {
    if (newQuantity > 0) {
      _cartItems[index]['quantity'] = newQuantity;
      notifyListeners();
    }
  }

  int get totalItems => _cartItems.fold(0, (sum, item) => sum + item['quantity'] as int);
}
