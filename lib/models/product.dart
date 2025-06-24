// ✅ FIXED: lib/models/product.dart
class Product {
  final String id;
  final String name;
  final String brand;
  final double price;
  final String imageUrl;
  final List<String> sizeOptions;
  final List<String> packOptions;
  final List<String> categories; // 👈 ADD THIS LINE

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
    required this.categories, // 👈 ADD THIS TOO

  });

  factory Product.fromWooJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'],
      brand: json['name'], // using name as brand for now
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      imageUrl: json['images'].isNotEmpty
          ? _fixUrl(json['images'][0]['src'])
          : 'assets/products/default.jpg',
      sizeOptions: ['500ml', '1L', '1.5L', '2L'], // default for now
      packOptions: ['Single', '6-pack', '12-pack'],
      categories: (json['categories'] as List<dynamic>)
          .map((cat) => cat['name'] as String)
          .toList(), // 👈 THIS EXTRACTS CATEGORY NAMES// default for now
    );
  }

}

String _fixUrl(String url) {
  if (url.startsWith('http')) return url;
  return 'https://lightsalmon-okapi-161109.hostingersite.com$url';
}

