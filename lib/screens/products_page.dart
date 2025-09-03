import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/woocommerce_service.dart';
import 'product_detail_page.dart';
import '../widget/product_card.dart';
import '../widget/brand_scroll_row.dart';
import '../models/category.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final WooCommerceService wooService = WooCommerceService();

  // Data
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Category> waterCategories = []; // direct children of parent 96
  List<Map<String, String>> brandList = [];

  // UI/State
  bool isLoading = true;
  String? error;

  // Filters
  static const int waterCategoryParentId = 96; // ✅ your parent ID
  int? selectedCategoryId;                     // null = All
  String? selectedBrandId;                     // null = All brands

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      // products
      final raw = await wooService.fetchProducts(perPage: 100, status: 'publish');
      final catMap = await wooService.fetchAllCategoriesMap();
      final parsed = raw
          .map<Product>((j) => Product.fromWooJson(j as Map<String, dynamic>, catMap))
          .toList();

      // categories: only children under parent 96
      final cats = await wooService.fetchCategories(
        parent: waterCategoryParentId, // 96
        perPage: 100,
        hideEmpty: false,
      );
      cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      // brands (no params)
      final brands = await wooService.fetchBrands();

      setState(() {
        allProducts = parsed;
        filteredProducts = parsed;
        waterCategories = cats;
        brandList = brands;
        isLoading = false;
        error = null;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        error = e.toString();
      });
    }
  }



  // --------------- Filters ----------------

  void _onTapAllCategories() {
    setState(() {
      selectedCategoryId = null; // All
      _applyCombinedFilters();
    });
  }

  void _onTapCategory(Category c) {
    setState(() {
      selectedCategoryId = (selectedCategoryId == c.id) ? null : c.id; // toggle
      _applyCombinedFilters();
    });
  }

  void _onTapBrand(String? brandId) {
    setState(() {
      selectedBrandId = (selectedBrandId == brandId) ? null : brandId; // toggle
      _applyCombinedFilters();
    });
  }

  void _applyCombinedFilters() {
    // Quick exit
    if (selectedCategoryId == null && selectedBrandId == null) {
      filteredProducts = allProducts;
      return;
    }

    filteredProducts = allProducts.where((p) {
      // Category: match by numeric ID
      final catOk = (selectedCategoryId == null)
          ? true
          : p.categoryIds.contains(selectedCategoryId);

      // Brand: your Product model already exposes brandId as String
      final brandOk = (selectedBrandId == null)
          ? true
          : p.brandId == selectedBrandId;

      return catOk && brandOk;
    }).toList();
  }

  // --------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Text(
                'Products',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A2D3D),
                ),
              ),
            ),

            // BRANDS
            if (brandList.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  'WATER BRANDS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(
                height: 100,
                child: BrandScrollRow(
                  brandData: brandList,
                  selectedBrandId: selectedBrandId,
                  onBrandTap: _onTapBrand,
                ),
              ),
              const SizedBox(height: 8),
            ],

            // CATEGORIES
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'WATER CATEGORIES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            Container(
              height: 42,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 1 + waterCategories.length, // All + each category
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = selectedCategoryId == null;
                    return _ChipButton(
                      label: 'All',
                      selected: isSelected,
                      onTap: _onTapAllCategories,
                    );
                  }

                  final cat = waterCategories[index - 1];

                  final isSelected = selectedCategoryId == cat.id;
                  return _ChipButton(
                    label: cat.name,
                    selected: isSelected,
                    onTap: () => _onTapCategory(cat),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // GRID
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(child: Text('Error: $error'))
                  : GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent:
                  MediaQuery.of(context).size.width > 600 ? 280 : 200,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                  MediaQuery.of(context).size.width > 600 ? 0.75 : 0.72,
                ),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  return ProductCard(
                    product: product,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProductDetailPage(product: product),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Small local widget for chips
class _ChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE1EFFE) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF3B82F6) : Colors.grey[300]!,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? const Color(0xFF1E40AF) : Colors.black,
          ),
        ),
      ),
    );
  }
}
