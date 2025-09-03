import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import '../screens/checkout_page.dart';
import '../screens/product_detail_page.dart';
import '../widget/app_scaffold.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final cartItems = cartProvider.cartItems;

    return AppScaffold(
      currentIndex: 0,
      hideNavigationBar: true,
      onTabSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Text(
                'Cart',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2D3D),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Back to products
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(40),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                      BoxShadow(color: Colors.white30, offset: Offset(0, -2), blurRadius: 2),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 18, color: Colors.black),
                      SizedBox(width: 6),
                      Text('Back to Products', style: TextStyle(color: Colors.black)),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Center(
              child: Text(
                'Your Cart Items',
                style: TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 10),

// Items list
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
                      padding: const EdgeInsets.all(12),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              product.imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.broken_image, color: Colors.red, size: 40),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // middle text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if ((item['size']?.toString().isNotEmpty ?? false) ||
                                    (item['package']?.toString().isNotEmpty ?? false))
                                  Text(
                                    '${item['size'] ?? ''}'
                                        '${(item['size'] ?? '').toString().isNotEmpty && (item['package'] ?? '').toString().isNotEmpty ? ' • ' : ''}'
                                        '${item['package'] ?? ''}',
                                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  '€${unitPrice.toStringAsFixed(2)} × $quantity = €${totalPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          // qty & delete (index-based, like before)
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline),
                                    onPressed: () {
                                      if (quantity > 1) {
                                        cartProvider.updateQuantity(index, quantity - 1);
                                      }
                                      // ❌ do nothing if quantity == 1
                                    },
                                    color: Colors.black54,
                                  ),
                                  Text(
                                    '$quantity',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline),
                                    onPressed: () =>
                                        cartProvider.updateQuantity(index, quantity + 1),
                                    color: Colors.black54,
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => cartProvider.removeFromCart(index),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),


            // Totals + proceed
            if (cartItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(thickness: 1, color: Colors.black26),
                    const SizedBox(height: 6),

                    // Totals (keep shipping synced with Woo order creation)
                    Builder(builder: (context) {
                      final subtotal = cartProvider.subtotal;
                      const double shippingFlat = 2.50;
                      final grand = subtotal + shippingFlat;

                      return Column(
                        children: [
                          _totalsRow('Subtotal', subtotal),
                          const SizedBox(height: 6),
                          _totalsRow('Shipping', shippingFlat),
                          const SizedBox(height: 10),
                          _totalsRow('Total', grand, isBold: true, big: true),
                        ],
                      );
                    }),

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
                            BoxShadow(color: Colors.black38, offset: Offset(0, 8), blurRadius: 24),
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
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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

Widget _totalsRow(String label, double amount, {bool isBold = false, bool big = false}) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: big ? 18 : 14,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          color: const Color(0xFF1A2D3D),
        ),
      ),
      Text(
        '€${amount.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: big ? 18 : 14,
          fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
          color: const Color(0xFF1A2D3D),
        ),
      ),
    ],
  );
}
