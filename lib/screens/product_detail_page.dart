// lib/screens/product_detail_page.dart
import 'package:cadeli/models/cart_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cadeli/models/product.dart';


class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String selectedSize = "500ml";
  String selectedPackage = "Single";
  int quantity = 1;

  void adjustQuantity(bool increase) {
    setState(() {
      if (increase) {
        quantity++;
      } else if (quantity > 1) {
        quantity--;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        backgroundColor: const Color(0xFF102027),
      ),
      backgroundColor: const Color(0xFFA1BDC7), // palette bg
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(p.imagePath, height: 200),
            ),
            const SizedBox(height: 20),

            Text(
              p.brand,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            Text(
              p.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),

            const SizedBox(height: 20),

            // Size selection
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: p.sizes.map((size) {
                return ChoiceChip(
                  label: Text(size),
                  selected: selectedSize == size,
                  onSelected: (_) => setState(() => selectedSize = size),
                  selectedColor: Colors.blueAccent,
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Package selection
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: p.packages.map((pack) {
                return ChoiceChip(
                  label: Text(pack),
                  selected: selectedPackage == pack,
                  onSelected: (_) => setState(() => selectedPackage = pack),
                  selectedColor: Colors.blueAccent,
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Quantity
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: () => adjustQuantity(false),
                ),
                Text(
                  '$quantity',
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => adjustQuantity(true),
                ),
              ],
            ),

            const SizedBox(height: 30),

            ElevatedButton.icon(
              icon: const Icon(Icons.shopping_cart),
              label: const Text("Add to Cart"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
              ),
              onPressed: () {
                final cart = Provider.of<CartProvider>(context, listen: false);
                cart.addToCart(widget.product, selectedSize, selectedPackage, quantity);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Added to cart")),
                );
              },

            ),
          ],
        ),
      ),
    );
  }
}
