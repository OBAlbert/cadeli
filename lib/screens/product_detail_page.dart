// 📄 product_detail_page.dart
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/woocommerce_service.dart';
import '../widget/app_scaffold.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_provider.dart';


class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  String brandImageUrl = '';
  String brandName = '';
  bool _isHttp(String s) => s.startsWith('http');
  int qty = 1;
  bool isFavorite = false;


  Widget _thumb(String path) {
    if (path.isEmpty) return const Icon(Icons.image_not_supported);
    if (_isHttp(path)) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
      );
    } else {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported),
      );
    }
  }

  // ===== Volume lookup support (paste below _thumb, above initState) =====
  static const int kVolumeParentId = 121;
  static const int kWaterTypeParentId = 96; // e.g. "Water Type" / "Beverage Type"
  static const int kTargetUseParentId = 115; // e.g. "Target Use"
  static const int kSustainabilityParentId = 111; // e.g. "Sustainability"


  /// Finds the first child category under the given parent id and returns its name/image
  /// using the product's category arrays (already populated from Woo).
  Map<String, String?> _categoryByParent(int parentId) {
    final parents = widget.product.categoryParents ?? [];
    final i = parents.indexWhere((p) => p == parentId);

    final name = (i != -1 && i < widget.product.categoryNames.length)
        ? widget.product.categoryNames[i]
        : null;

    final img = (i != -1 && i < widget.product.categoryImages.length)
        ? widget.product.categoryImages[i]
        : null;

    // 🔎 Debug: see what matched and if the image is a network URL
    print('🔎 parent=$parentId → index=$i | name=$name | img=$img | http=${(img ?? '').startsWith("http")}');

    return {'name': name, 'image': img};
  }
  // ===== end Volume lookup support =====




  @override
  void initState() {
    super.initState();
    _fetchBrandData();
    _checkFavoriteStatus();

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
    if (!mounted) return; // ✅ safety


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

  Future<void> _checkFavoriteStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.product.id.toString());
    final snap = await favRef.get();
    if (!mounted) return;
    setState(() => isFavorite = snap.exists);
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final favRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(widget.product.id.toString());

    if (isFavorite) {
      await favRef.delete();
    } else {
      await favRef.set({
        'productId': widget.product.id,
        'name': widget.product.name,
        'brand': widget.product.brand ?? '',
        'imageUrl': widget.product.imageUrl,
        'price': widget.product.price,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    if (!mounted) return;
    setState(() => isFavorite = !isFavorite);
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
            // ⬅️ Back button
            InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_back, color: Colors.black, size: 22),
                  SizedBox(width: 6),
                  Text(
                    "Back",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12), // small spacing after back button


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
                      child: _thumb(
                        widget.product.imageUrl.isNotEmpty
                            ? widget.product.imageUrl
                            : 'assets/background/fade_base.jpg', // keep or change to your fallback
                      ),
                    ),

                    // SALE badge
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

                    // ❤️ Favourite toggle (top-right over image)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: _toggleFavorite,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0,2)),
                            ],
                          ),
                          child: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.redAccent : Colors.black54,
                            size: 22,
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
            // 🔢 Attributes Grid (slightly shorter tiles)
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,     // was 1 → a bit more breathing room inside rows
              crossAxisSpacing: 6,    // was 1
              childAspectRatio: 1.15, // >1 makes each tile a bit shorter (brings Quantity closer)
              children: [
                _buildAttributeCell(
                  imagePath: brandImageUrl.isNotEmpty ? brandImageUrl : 'assets/icons/paypal.png',
                  title: brandName,
                  label: 'Brand',
                ),
                _buildAttributeCell(
                  imagePath: (widget.product.packagingImage?.isNotEmpty ?? false)
                      ? widget.product.packagingImage!
                      : 'assets/icons/paypal.png',
                  title: widget.product.packagingName ?? 'Packaging',
                  label: 'Packaging',
                ),
                (() {
                  final vol = _categoryByParent(kVolumeParentId);
                  return _buildAttributeCell(
                    imagePath: (vol['image']?.isNotEmpty ?? false) ? vol['image']! : 'assets/icons/paypal.png',
                    title: vol['name'] ?? 'Volume',
                    label: 'Volume',
                  );
                })(),
                (() {
                  final wt = _categoryByParent(kWaterTypeParentId);
                  return _buildAttributeCell(
                    imagePath: (wt['image']?.isNotEmpty ?? false) ? wt['image']! : 'assets/icons/paypal.png',
                    title: wt['name'] ?? 'Water Type',
                    label: 'Water Type',
                  );
                })(),
                (() {
                  final tu = _categoryByParent(kTargetUseParentId);
                  return _buildAttributeCell(
                    imagePath: (tu['image']?.isNotEmpty ?? false) ? tu['image']! : 'assets/icons/paypal.png',
                    title: tu['name'] ?? 'Target Use',
                    label: 'Target Use',
                  );
                })(),
                (() {
                  final sus = _categoryByParent(kSustainabilityParentId);
                  return _buildAttributeCell(
                    imagePath: (sus['image']?.isNotEmpty ?? false) ? sus['image']! : 'assets/icons/paypal.png',
                    title: sus['name'] ?? 'Sustainability',
                    label: 'Sustainability',
                  );
                })(),
              ],
            ),


            // 🔢 Quantity (centered, bigger, bold, dark blue)
            Center(
              child: Column(
                children: [
                  const Text(
                    'Quantity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2D3D), // dark blue
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Color(0xFF1A2D3D), width: 1.2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => setState(() { if (qty > 1) qty--; }),
                          icon: const Icon(Icons.remove_rounded),
                          iconSize: 24,
                          color: const Color(0xFF1A2D3D),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          visualDensity: VisualDensity.compact,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2D3D),
                            ),
                          ),
                        ),
                        IconButton
                          (
                          onPressed: () => setState(() { qty++; }),
                          icon: const Icon(Icons.add_rounded),
                          iconSize: 24,
                          color: const Color(0xFF1A2D3D),
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),


            // 🛒 Add to Cart
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.shopping_cart_outlined, size: 22),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Add to Cart',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2D3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
                onPressed: () {
                  context.read<CartProvider>().add(widget.product, qty: qty);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${widget.product.name} x$qty to cart'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),




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
          Expanded(child: _thumb(imagePath)),
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
