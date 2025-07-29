import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/woocommerce_service.dart';
import 'product_detail_page.dart';
import '../widget/product_card.dart';


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

  List<String> categories = ['All', 'Sparkling', 'Spring', 'Uncategorized'];
  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    fetchProducts();
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

  void filterByCategory(String category) {
    setState(() {
      selectedCategory = category;
      if (category == 'All') {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts
            .where((p) => p.categories.any(
                (c) => c.toLowerCase().contains(category.toLowerCase())))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔵 PAGE TITLE
            Padding(
              padding: EdgeInsets.fromLTRB(
                MediaQuery.of(context).size.width * 0.05,
                MediaQuery.of(context).size.height * 0.02,
                MediaQuery.of(context).size.width * 0.05,
                10
              ),
              child: Text(
                'Products',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 400 ? 24 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A2D3D),
                ),
              ),
            ),

            // 🟣 CATEGORY FILTER TABS
            Container(
              height: 50,
              margin: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.03,
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final isSelected = cat == selectedCategory;
                  return GestureDetector(
                    onTap: () => filterByCategory(cat),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.05,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF1A2D3D) : Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF1A2D3D), width: 1.5),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: MediaQuery.of(context).size.width > 360 ? 14 : 12,
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // 🟢 PRODUCT GRID
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                  ? Center(child: Text('Error: $error'))
                  : GridView.builder( // <-- Wrap in GridView.builder
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240, // adapts columns automatically
                        mainAxisExtent: 260,     // controls height per card
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
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
