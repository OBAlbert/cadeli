import 'package:flutter/material.dart';
import '../models/product.dart';

class MiniProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const MiniProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSale = product.onSale;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 110,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          product.imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 30),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),

                    if (isSale)
                      Text(
                        '€${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          decoration: TextDecoration.lineThrough,
                          color: Colors.grey,
                        ),
                      ),

                    Text(
                      product.displayPrice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSale ? Colors.red : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              if (isSale)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.red[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'SALE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              Positioned(
                bottom: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onAddTap,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2D3D),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

