import 'package:cadeli/models/product.dart';
import 'package:cadeli/screens/product_detail_page.dart';
import 'package:cadeli/services/woocommerce_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cadeli/widget/product_card.dart';
import '../widget/app_scaffold.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final WooCommerceService wooService = WooCommerceService();
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Product> recentViewed = [];

  bool isLoading = true;
  String? error;
  String searchQuery = '';
  bool showRecentlyViewed = true;

  final List<String> keywords = ['Mineral', 'Sparkling', 'ITEO', 'Evian', 'Glass']; // ✅ Keywords List

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
      fetchRecentlyViewed(parsed);
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void onSearch(String query) {
    setState(() {
      searchQuery = query;
      if (query.isEmpty) {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts.where((p) {
          return p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.brand.toLowerCase().contains(query.toLowerCase()) ||
              p.categories.any((c) => c.toLowerCase().contains(query.toLowerCase()));
        }).toList();
      }
    });
  }

  void onKeywordTap(String keyword) {
    onSearch(keyword); // ✅ Keyword pill tap triggers search
  }

  Future<void> fetchRecentlyViewed(List<Product> products) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final List<dynamic>? recentList = doc.data()?['recentlyViewed'];

    if (recentList != null) {
      final List<Product> fetched = [];
      for (var id in recentList.reversed.toList()) {
        final match = products.firstWhere((p) => p.id == id.toString(), orElse: () => Product.empty());
        if (!match.isEmpty()) fetched.add(match);
      }
      setState(() => recentViewed = fetched);
    }
  }

  Future<void> addToRecentlyViewed(String productId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await docRef.get();
    final existing = List<String>.from(doc.data()?['recentlyViewed'] ?? []);

    existing.remove(productId);
    existing.insert(0, productId);
    if (existing.length > 10) existing.removeLast();

    await docRef.update({'recentlyViewed': existing});
    fetchRecentlyViewed(allProducts);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 1,
      onTabSelected: (index) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ✅ Glassy Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.black12),
                ),
                child: TextField(
                  onChanged: onSearch,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                  decoration: const InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(color: Colors.black54),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.black54),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ✅ Keyword Chips
              Wrap(
                spacing: 8,
                children: keywords.map((word) {
                  return GestureDetector(
                    onTap: () => onKeywordTap(word),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1A2D3D)),
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                      ),
                      child: Text(
                        word,
                        style: const TextStyle(color: Color(0xFF1A2D3D), fontWeight: FontWeight.w600),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 18),

              // ✅ Recently Viewed Toggle + Scroll
              if (recentViewed.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => showRecentlyViewed = !showRecentlyViewed),
                  child: Row(
                    children: const [
                      Icon(Icons.remove_red_eye_outlined, color: Color(0xFF1A2D3D)),
                      SizedBox(width: 6),
                      Text(
                        'Recently Viewed',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A2D3D)),
                      ),
                      Spacer(),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1A2D3D)),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: showRecentlyViewed
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentViewed.length,
                      itemBuilder: (context, index) {
                        final product = recentViewed[index];
                        return Padding(
                          padding: const EdgeInsets.only(left: 6, right: 12),
                          child: SizedBox(
                            width: 120, // ✅ Smaller square card
                            child: ProductCard(
                              product: product,
                              onTap: () {
                                addToRecentlyViewed(product.id);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Colors.black26),
                const SizedBox(height: 4),
                const Text('Results:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A2D3D))),
                const SizedBox(height: 8),
              ],

              // ✅ Search Results Grid
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(child: Text('Error: $error'))
                    : GridView.builder(
                  itemCount: filteredProducts.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  padding: const EdgeInsets.only(bottom: 16),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return ProductCard(
                      product: product,
                      onTap: () {
                        addToRecentlyViewed(product.id);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
