// 📄 product_detail_page.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/woocommerce_service.dart';
import '../widget/app_scaffold.dart';

class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String brandImageUrl = '';
  String brandName = '';

  @override
  void initState() {
    super.initState();
    _fetchBrandData();

    // ✅ Debug: Print full category info to console
    final names = widget.product.categoryNames;
    final parents = widget.product.categoryParents ?? [];
    final images = widget.product.categoryImages;

    for (int i = 0; i < names.length; i++) {
      print('📦 Category[$i]: ${names[i]} | Parent: ${parents.length > i ? parents[i] : 'N/A'} | Image: ${images.length > i ? images[i] : 'N/A'}');
    }

    print('🔢 All category IDs: ${widget.product.categoryIds}');
    print('👨‍👩‍👧‍👦 All category Parents: ${widget.product.categoryParents}');
  }


  Future<void> _fetchBrandData() async {
    final service = WooCommerceService();
    final brand = await service.fetchBrandById(widget.product.brandId);

    if (brand != null) {
      setState(() {
        brandImageUrl = brand['image'] ?? '';
        brandName = brand['name'] ?? 'Unknown';
      });
    } else {
      setState(() {
        brandImageUrl = '';
        brandName = 'Unknown';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🖼️ Brand Image URL: $brandImageUrl');

    return AppScaffold(
      currentIndex: 1,
      onTabSelected: (index) {},
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ Product image
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ],
              ),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        widget.product.imageUrl ?? '',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_not_supported),
                      ),
                    ),
                    if (widget.product.onSale)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'SALE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 🧾 Product name
            Text(
              widget.product.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF123456),
              ),
            ),

            const SizedBox(height: 8),

            // 💸 Price
            if (widget.product.onSale)
              Row(
                children: [
                  Text(
                    '€${widget.product.salePrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF123456),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '€${widget.product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.red,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              )
            else
              Text(
                '€${widget.product.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF123456),
                ),
              ),

            const SizedBox(height: 24),

            // ℹ️ Section Title
            const Text(
              'Information',
              style: TextStyle(
                color: Color(0xFF123456),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // 🔢 Attributes Grid
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 1,
              crossAxisSpacing: 1,
              children: [
                // 1🏷️ Brand (dynamic fetch)
                _buildAttributeCell(
                  imagePath: brandImageUrl.isNotEmpty
                      ? brandImageUrl
                      : 'assets/icons/paypal.png',
                  title: brandName,
                  label: 'Brand',
                ),

                // 2📦 Packaging
                (() {
                  final packagingIndex = (widget.product.categoryParents ?? []).indexWhere((p) => p == 103);
                  final packagingName = packagingIndex != -1
                      ? widget.product.categoryNames[packagingIndex]
                      : 'Unknown';
                  final packagingImage = packagingIndex != -1
                      ? widget.product.categoryImages[packagingIndex]
                      : 'assets/icons/paypal.png';

                  // ✅ Extra debug:
                  print('📦 Packaging Match → index: $packagingIndex');
                  print('📦 Packaging Name: $packagingName');
                  print('📦 Packaging Image: $packagingImage');
                  print('🧪 Packaging Name: ${widget.product.packagingName}');
                  print('🧪 Packaging Image: ${widget.product.packagingImage}');


                  return _buildAttributeCell(
                    imagePath: widget.product.packagingImage?.isNotEmpty == true
                        ? widget.product.packagingImage!
                        : 'assets/icons/paypal.png',
                    title: widget.product.packagingName ?? 'N/A',
                    label: 'Packaging',
                  );
                })(),



              ],
            ),

            const SizedBox(height: 24),



            // 📄 Description placeholder
            const Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This is a placeholder for the product description.',
              style: TextStyle(fontSize: 14, height: 1.5),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🧱 Attribute card builder
  Widget _buildAttributeCell({
    required String imagePath,
    required String title,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200, width: 0.9),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Image.network(
              imagePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.image_not_supported),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
