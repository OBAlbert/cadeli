// lib/screens/products_page.dart
import 'package:cadeli/screens/product_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:cadeli/models/product.dart';


class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  // Dummy local product data (can later pull from Firebase or WooCommerce)
  List<Product> get sampleProducts => [
    Product(
      name: "Agios Nikolaos 500ml",
      brand: "Agios Nikolaos",
      imagePath: "assets/products/keo1.jpg",
    ),
    Product(
      name: "Kykkos 1.5L",
      brand: "Kykkos",
      imagePath: "assets/products/bottle1.jpg",
    ),
    Product(
      name: "Saint Nicholas 6-Pack",
      brand: "Saint Nicholas",
      imagePath: "assets/products/sn6.jpg",
    ),
    Product(
      name: "Agios Nikolaos 6-Pack",
      brand: "Agios Nikolaos",
      imagePath: "assets/products/iteo6.jpg",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: sampleProducts.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, // Two columns
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (context, index) {
          final product = sampleProducts[index];

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
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.asset(
                        product.imagePath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          product.brand,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
