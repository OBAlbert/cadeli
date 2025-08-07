import 'Category.dart';

class Product {
  final String id;
  final String name;
  final String brand;

  final double price;
  final double? salePrice;
  final String imageUrl;
  final List<int> categoryIds;
  final List<String> categoryNames;
  final List<String> categoryImages;
  final List<int>? categoryParents;



  final bool isFeatured;
  final String brandId;
  final String brandImage;
  int quantity;

  Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.price,
    this.salePrice,
    required this.imageUrl,
    this.isFeatured = false,
    required this.brandId,
    this.quantity = 1,
    required this.categoryIds,
    required this.categoryNames,
    required this.categoryImages,
    this.categoryParents,

    required this.brandImage,
  });

  factory Product.fromWooJson(Map<String, dynamic> json) {
    if ((json['brands'] as List?)?.isNotEmpty ?? false) {
      print('✅ Brand image: ${json['brands'][0]['image']?['src']}');
    }
    // ✅ Calculate category data first
    final categories = (json['categories'] as List<dynamic>)
        .map((cat) => Category.fromJson(cat))
        .toList();


    return Product(
      id: json['id'].toString(),
      name: json['name'],
      brand: (json['brands'] as List?)?.isNotEmpty ?? false
          ? json['brands'][0]['name']
          : '',
      brandId: (json['brands'] as List?)?.isNotEmpty ?? false
          ? json['brands'][0]['id'].toString()
          : '0',
      brandImage: (json['brands'] as List?)?.isNotEmpty ?? false
          ? Product._fixUrl(json['brands'][0]['image']?['src'] ?? '')
          : '',

      price: double.tryParse(json['regular_price'].toString()) ?? 0.0,
      salePrice: json['sale_price']?.toString().isNotEmpty ?? false
          ? double.tryParse(json['sale_price'].toString())
          : null,
      imageUrl: json['images'].isNotEmpty
          ? _fixUrl(json['images'][0]['src'])
          : 'assets/products/default.jpg',

      categoryIds: categories.map((cat) => cat.id).toList(),
      categoryParents: categories.map((cat) => cat.parent ?? 0).toList(),
      categoryNames: categories.map((cat) => cat.name).toList(),
      categoryImages: categories.map((cat) => cat.imageUrl ?? 'assets/icons/default_icon.png').toList(),



      isFeatured: json['featured'] ?? false,
    );
  }

  factory Product.empty() {
    return Product(
      id: '',
      name: '',
      brand: '',
      brandId: '0',
      brandImage: '',

      price: 0.0,
      salePrice: null,
      imageUrl: '',
      categoryIds: [],
      categoryParents: [],
      categoryNames: [],
      categoryImages: [],

    );
  }

  bool get isEmpty => id.isEmpty;
  bool get onSale => salePrice != null && salePrice! < price;


  String get displayPrice {
    return onSale
        ? '€${salePrice!.toStringAsFixed(2)}'
        : '€${price.toStringAsFixed(2)}';
  }

  static String _fixUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    if (!url.startsWith('/')) url = '/$url';
    return 'https://lightsalmon-okapi-161109.hostingersite.com$url';
  }

  // 📦 Returns the packaging name based on categoryParents
  String? get packagingName {
    if (categoryParents == null || categoryNames.isEmpty) return null;
    final index = categoryParents!.indexWhere((p) => p == 103);
    return (index != -1 && index < categoryNames.length) ? categoryNames[index] : null;
  }

// 🖼️ Returns the packaging image based on categoryParents
  String? get packagingImage {
    if (categoryParents == null || categoryImages.isEmpty) return null;
    final index = categoryParents!.indexWhere((p) => p == 103);
    return (index != -1 && index < categoryImages.length) ? categoryImages[index] : null;
  }


}