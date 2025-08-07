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
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  bool isLoading = true;
  String? error;
  List<Category> allCategories = [];
  int waterCategoryParentId = 96; // 🔧 Change this to your actual "Water Type" parent ID


  List<String> get categories {
    return [
      'All',
      ...allCategories
          .where((c) => c.parent == waterCategoryParentId)
          .map((c) => c.name)
    ];
  }
  String selectedCategory = 'All';

  List<Map<String, String>> brandList = [];       // ✅ brands from Woo
  String? selectedBrandId;                        // ✅ used for filtering


  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchBrands();
    fetchCategories();
  }

  Future<void> fetchProducts() async {
    try {
      final raw = await wooService.fetchProducts();
      final parsed = raw.map((json) => Product.fromWooJson(json)).toList();

      setState(() {
        allProducts = parsed;
        filteredProducts = parsed;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> fetchBrands() async {
    try {
      final fetchedBrands = await wooService.fetchBrands();
      setState(() {
        brandList = fetchedBrands;
      });
    } catch (e) {
      print("❌ Error fetching brands: $e");
    }
  }

  Future<void> fetchCategories() async {
    try {
      final fetched = await wooService.fetchBeverageTypeCategories(); // 🚀 only subcategories now
      setState(() {
        allCategories = fetched;
      });
    } catch (e) {
      print("❌ Error fetching categories: $e");
    }
  }

  void filterByCategory(String cat) {
    setState(() {
      selectedCategory = cat;
      applyCombinedFilters(); // ✅ apply combined filter instead
    });
  }

  void filterByBrand(String? brandId) {
    setState(() {
      selectedBrandId = brandId;
      applyCombinedFilters();
    });
  }

// New optimized combined filter method
  void applyCombinedFilters() {
    if (selectedCategory == 'All' && selectedBrandId == null) {
      filteredProducts = allProducts;
      return;
    }

    filteredProducts = allProducts.where((p) {
      // Category filter
      final matchesCategory = selectedCategory == 'All' ||
          allCategories
              .where((cat) => p.categoryIds.contains(cat.id))
              .any((cat) => cat.name.toLowerCase().contains(selectedCategory.toLowerCase()));

      // Brand filter
      final matchesBrand = selectedBrandId == null || p.brandId == selectedBrandId;

      return matchesCategory && matchesBrand;
    }).toList();
  }







  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PRODUCTS TITLE (MOVED HIGHER)
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

            // 2. BRANDS SECTION
            if (brandList.isNotEmpty) ...[
              // Remove the "WATER BRANDS" label by deleting this Padding widget
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  'WATER BRANDS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700, // Bolder weight
                    color: Colors.black,
                  ),
                ),
              ),
              SizedBox(
                height: 100,
                child: BrandScrollRow(
                  brandData: brandList,
                  selectedBrandId: selectedBrandId,
                  onBrandTap: (brandId) {
                    setState(() {
                      // FIX: Proper brand deselection logic
                      selectedBrandId = selectedBrandId == brandId ? null : brandId;
                      applyCombinedFilters();
                    });
                  },
                ),
              ),
              const SizedBox(height: 8), // Reduced spacing
            ],

            // 3. CATEGORIES SECTION
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'WATER CATEGORIES',
                style: TextStyle(
                  fontSize: 12, // Smaller font
                  fontWeight: FontWeight.w700, // Bolder weight
                  color: Colors.black,
                ),
              ),
            ),
            Container(
              height: 42, // Reduced height
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8), // Smaller gap
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = cat == selectedCategory;
                  return GestureDetector(
                    onTap: () => filterByCategory(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFE1EFFE) : Colors.white, // Lighter blue
                        borderRadius: BorderRadius.circular(12), // Smaller radius
                        border: Border.all(
                          color: isSelected ? const Color(0xFF3B82F6) : Colors.grey[300]!, // Blue border
                          width: 1.0, // Thinner border
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? const Color(0xFF1E40AF) : Colors.black, // Darker blue
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 4. PRODUCT GRID
            const SizedBox(height: 12), // Reduced spacing

            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(child: Text('Error: $error'))
                  : GridView.builder(padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                      left: MediaQuery.of(context).size.width * 0.01,
                      right: MediaQuery.of(context).size.width * 0.01,
                    ),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: MediaQuery.of(context).size.width > 600 ? 280 : 200,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: MediaQuery.of(context).size.width > 600 ? 0.75 : 0.72,
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
