class Product {
  final String id;
  final String name;
  final String brand;
  final double price;
  final double? salePrice;
  final String imageUrl;
  final List<String> sizeOptions;
  final List<String> packOptions;
  final List<String> categories;
  final List<String> variants;
  final bool isFeatured;
  int quantity;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    this.salePrice,
    required this.imageUrl,
    this.sizeOptions = const ['500ml', '1.5L'],
    this.packOptions = const ['Single', '6-Pack'],
    required this.categories,
    this.variants = const [],
    this.isFeatured = false,
    this.quantity = 1,
  });

  factory Product.fromWooJson(Map<String, dynamic> json) {
    // Extract variants from WooCommerce attributes
    final variants = json['attributes']?.isNotEmpty ?? false
        ? (json['attributes'][0]['options'] as List<dynamic>)
        .map((opt) => opt.toString())
        .toList()
        : ['0.5L', '1L', '1.5L'];

    return Product(
      id: json['id'].toString(),
      name: json['name'],
      brand: json['name'], // Temporary - replace with actual brand field when available
      price: double.tryParse(json['price'].toString()) ?? 0.0,
      salePrice: json['sale_price']?.toString().isNotEmpty ?? false
          ? double.tryParse(json['sale_price'].toString())
          : null,
      imageUrl: json['images'].isNotEmpty
          ? _fixUrl(json['images'][0]['src'])
          : 'assets/products/default.jpg',
      sizeOptions: variants,
      packOptions: ['Single', '6-pack', '12-pack'],
      categories: (json['categories'] as List<dynamic>)
          .map((cat) => cat['name'] as String)
          .toList(),
      variants: variants,
      isFeatured: json['featured'] ?? false,
    );
  }

  factory Product.empty() {
    return Product(
      id: '',
      name: '',
      brand: '',
      price: 0.0,
      salePrice: null,
      imageUrl: '',
      categories: [],
      variants: [],
    );
  }

  bool get isEmpty => id.isEmpty;
  bool get onSale => salePrice != null && salePrice! < price;

  String get formattedVariants {
    if (variants.isEmpty) return '0.5L, 1L, 1.5L';
    return variants.join(', ');
  }

  String get displayPrice {
    return onSale
        ? '€${salePrice!.toStringAsFixed(2)}'
        : '€${price.toStringAsFixed(2)}';
  }

  static String _fixUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://lightsalmon-okapi-161109.hostingersite.com$url';
  }
}