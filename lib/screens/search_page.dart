import 'package:flutter/material.dart';
import 'package:cadeli/models/product.dart';
import 'package:cadeli/screens/product_detail_page.dart';
import 'package:cadeli/services/woocommerce_service.dart';
import 'package:cadeli/widget/product_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cadeli/widget/mini_product_card.dart';


import '../models/Category.dart';


class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final WooCommerceService wooService = WooCommerceService();
  final TextEditingController _searchController = TextEditingController();

  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Product> recentViewed = [];


  bool isLoading = true;
  String? error;
  bool showRecentlyViewed = true;

  final List<String> keywords = ['Mineral', 'Sparkling', 'ITEO', 'Evian Glass'];

  @override
  void initState() {
    super.initState();
    fetchProducts();

  }

  // Fetch all products from WooCommerce
  Future<void> fetchProducts() async {
    try {
      final raw = await wooService.fetchProducts();
      final catMap = await wooService.fetchAllCategoriesMap();
      final parsed = raw.map((j) => Product.fromWooJson(j, catMap)).toList();
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

  // Handle search logic
  void onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = allProducts;
      } else {
        filteredProducts = allProducts.where((p) {
          return p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.brand.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }


  // Fetch recently viewed product list from Firestore
  Future<void> fetchRecentlyViewed(List<Product> products) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final List<dynamic>? recentList = doc.data()?['recentlyViewed'];

    if (recentList != null) {
      final List<Product> fetched = [];
      for (var id in recentList.reversed) {
        final match = products.firstWhere(
              (p) => p.id == id.toString(),
          orElse: () => Product.empty(),
        );
        if (!match.isEmpty) fetched.add(match);
      }
      setState(() => recentViewed = fetched);
    }
  }

  // Add a product to recently viewed list in Firestore
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A233D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Search',
          style: TextStyle(
            color: Color(0xFF1A233D),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MediaQuery.of(context).size.width * 0.04,
            8,
            MediaQuery.of(context).size.width * 0.04,
            0
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔍 Styled Search Bar (Rounded 15px, soft glass style)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade300, // or .shade300 for slightly darker
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.grey.shade500),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: onSearch,
                  decoration: const InputDecoration(
                    hintText: 'Search anything...',
                    hintStyle: TextStyle(
                      color: Colors.black12,
                      fontWeight: FontWeight.bold,
                    ),
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: Colors.black),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,         // ✅ USER TYPING TEXT = BLACK
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 👁️ Recently Viewed Section (Toggleable)
              if (recentViewed.isNotEmpty) ...[
                GestureDetector(
                  onTap: () => setState(() => showRecentlyViewed = !showRecentlyViewed),
                  child: const Row(
                    children: [
                      Icon(Icons.remove_red_eye_outlined, color: Color(0xFF1A2D3D)),
                      SizedBox(width: 6),
                      Text('Recently Viewed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF1A2D3D))),
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
                  firstChild: SizedBox(
                    height: 180,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentViewed.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        final product = recentViewed[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: MiniProductCard(
                            product: product,
                            onTap: () {
                              addToRecentlyViewed(product.id);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailPage(product: product),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  secondChild: const SizedBox.shrink(),
                ),
                const Divider(height: 24),
              ],

              const Text(
                'Results:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2D3D)),
              ),
              const SizedBox(height: 8),

              // 📦 Product Results Grid
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : error != null
                    ? Center(child: Text('Error: $error'))
                    : GridView.builder(
                  padding: EdgeInsets.only(
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
                        addToRecentlyViewed(product.id);
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
      ),
    );
  }
}
