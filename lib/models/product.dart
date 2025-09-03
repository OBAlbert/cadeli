import 'category.dart';
import '../services/woocommerce_service.dart' show WooCategoryMeta;


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

  factory Product.fromWooJson(
      Map<String, dynamic> json,
      Map<int, WooCategoryMeta> catMap, // <-- pass in from service
      ) {

    // Build category arrays using the authoritative category map
    final prodCats = (json['categories'] as List<dynamic>? ?? []);
    final List<int> catIds = [];
    final List<int> catParents = [];
    final List<String> catNames = [];
    final List<String> catImages = [];

    for (final c in prodCats) {
      final id = (c['id'] ?? 0) as int;
      catIds.add(id);

      final meta = catMap[id];
      catParents.add(meta?.parent ?? 0);
      catNames.add(meta?.name ?? (c['name']?.toString() ?? ''));
      final img = meta?.image ?? '';
      catImages.add(_fixUrl(img));
    }

// ---- brand safe parsing ----
    final hasBrand = (json['brands'] as List?)?.isNotEmpty ?? false;
    final String brandName   = hasBrand ? (json['brands'][0]['name'] ?? '') : (json['brand'] ?? '');
    final String brandIdStr  = hasBrand ? (json['brands'][0]['id']?.toString() ?? '0') : '0';
    final String brandImgUrl = hasBrand ? _fixUrl(json['brands'][0]['image']?['src'] ?? '') : '';

// ---- price parsing (robust) ----
    final String rawPriceStr = '${json['price'] ?? json['regular_price'] ?? 0}';
    final double priceFromWoo = double.tryParse(rawPriceStr) ?? 0.0;

    final String rawRegularStr = '${json['regular_price'] ?? rawPriceStr}';
    final double regularFromWoo = double.tryParse(rawRegularStr) ?? priceFromWoo;

    final bool onSaleFlag = json['on_sale'] == true;

// sale_price can be '', null, or string. If missing but on_sale is true, infer from price vs regular.
    final String? rawSaleStr = (json['sale_price']?.toString().isNotEmpty ?? false)
        ? json['sale_price'].toString()
        : null;
    double? saleFromWoo = rawSaleStr != null ? double.tryParse(rawSaleStr) : null;

// If Woo says on_sale, but sale_price is empty,
// AND the current price is lower than regular, treat price as the sale and regular as original.
    double effectiveRegular = regularFromWoo;
    double effectiveSale = saleFromWoo ?? 0.0;
    double effectivePrice = priceFromWoo;

    if (onSaleFlag) {
      final bool saleMissing = (saleFromWoo == null || saleFromWoo == 0.0);
      final bool priceLooksDiscounted = (priceFromWoo > 0 && priceFromWoo < regularFromWoo);

      if (saleMissing && priceLooksDiscounted) {
        effectiveSale = priceFromWoo;
        effectivePrice = regularFromWoo;
      } else if (saleFromWoo != null && saleFromWoo > 0 && saleFromWoo < regularFromWoo) {
        // Normal case: both regular & sale provided
        effectiveSale = saleFromWoo;
        effectivePrice = regularFromWoo;
      }
    } else {
      // not on sale -> keep as-is (price = regular)
      effectivePrice = regularFromWoo != 0 ? regularFromWoo : priceFromWoo;
      effectiveSale = 0.0;
    }

// ---- image (first image or empty) ----
    final images = (json['images'] is List) ? (json['images'] as List) : const [];
    final String firstImage = images.isNotEmpty ? _fixUrl(images[0]['src'] ?? '') : '';

    return Product(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      brand: brandName,
      brandId: brandIdStr,
      brandImage: brandImgUrl,

      price: effectivePrice,
      salePrice: (effectiveSale > 0 && effectiveSale < effectivePrice) ? effectiveSale : null,


      imageUrl: firstImage,

      // this is what we’ll filter on
      categoryIds: catIds,
      categoryParents: catParents,
      categoryNames: catNames,
      categoryImages: catImages,

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

  bool hasCategory(int id) => categoryIds.contains(id);

}