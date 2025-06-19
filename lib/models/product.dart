// ✅ FIXED: lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final List<String> sizeOptions;
  final List<String> packOptions;
  int quantity;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    required this.imageUrl,
    this.sizeOptions = const ['500ml', '1.5L'],
    this.packOptions = const ['Single', '6-Pack'],
    this.quantity = 1,
  });

  factory Product.fromMap(Map<String, dynamic> data) {
    return Product(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      brand: data['brand'] ?? '',
      price: (data['price'] ?? 0).toDouble(),
      imageUrl: data['imageUrl'] ?? 'assets/products/default.jpg',
      sizeOptions: List<String>.from(data['sizeOptions'] ?? []),
      packOptions: List<String>.from(data['packOptions'] ?? []),
    );
  }
}
