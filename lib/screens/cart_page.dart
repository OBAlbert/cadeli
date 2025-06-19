import 'dart:ui';
import 'package:cadeli/models/cart_provider.dart';
import 'package:cadeli/screens/checkout_page.dart';
import 'package:cadeli/screens/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widget/app_scaffold.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;

    return AppScaffold(
      currentIndex: 2,
      onTabSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD2E4EC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A2D3D),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Back to Products', style: TextStyle(color: Colors.white)),
        ),
        body: Column(
          children: [
            Expanded(
              child: cartItems.isEmpty
                  ? const Center(child: Text("Your cart is empty"))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final item = cartItems[index];
                  final product = item['product'];
                  final int quantity = item['quantity'];
                  final double unitPrice = product.price;
                  final double totalPrice = unitPrice * quantity;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(product: product),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6)),
                          BoxShadow(color: Colors.white30, offset: Offset(0, -2), blurRadius: 4),
                        ],
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(
                              'assets/products/${product.imageUrl}',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, color: Colors.red, size: 40),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black)),
                                const SizedBox(height: 4),
                                Text('${item['size']} - ${item['package']}',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.black87)),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline),
                                      onPressed: () => cartProvider.updateQuantity(index, quantity - 1),
                                      color: Colors.black54,
                                    ),
                                    Text('$quantity',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black)),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => cartProvider.updateQuantity(index, quantity + 1),
                                      color: Colors.black54,
                                    ),
                                  ],
                                ),
                                Text('Unit: €${unitPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600)),
                                Text('Subtotal: €${totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () => cartProvider.removeFromCart(index),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (cartItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(thickness: 1, color: Colors.black26),
                    const SizedBox(height: 6),
                    Text(
                      'Total: €${cartProvider.totalCost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A2D3D),
                      ),
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CheckoutPage()),
                      ),
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A2D3D),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              offset: Offset(0, 8),
                              blurRadius: 24,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.payment, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'Proceed to Checkout',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
