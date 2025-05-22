// lib/screens/cart_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Your Cart"),
        backgroundColor: const Color(0xFF102027),
      ),
      backgroundColor: const Color(0xFFA1BDC7),
      body: cart.cartItems.isEmpty
          ? const Center(child: Text("Your cart is empty."))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: cart.cartItems.length,
              itemBuilder: (context, index) {
                final item = cart.cartItems[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(item['product'].name),
                    subtitle: Text(
                        "${item['size']} - ${item['package']} | Qty: ${item['quantity']}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: () {
                            final newQty = item['quantity'] - 1;
                            if (newQty > 0) {
                              cart.updateQuantity(index, newQty);
                            } else {
                              cart.removeFromCart(index);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () {
                            cart.updateQuantity(index, item['quantity'] + 1);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            cart.removeFromCart(index);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  "Total Items: ${cart.totalItems}",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Checkout coming soon...")),
                    );
                  },
                  icon: const Icon(Icons.payment),
                  label: const Text("Checkout"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
