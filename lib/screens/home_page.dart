import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widget/mini_product_card.dart';
import 'product_detail_page.dart';
import '../widget/product_card.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/woocommerce_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentIndex = 0;

  final WooCommerceService wooService = WooCommerceService();
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Category> beverageCategories = [];
  bool isLoading = true;

  String selectedCategory = 'All';
  int beverageParentId = 96;

  final List<Map<String, String>> slides = [
    {
      "image": "assets/background/bottle_back.jpg",
      "title": "Who We Are",
      "text": "Cadeli makes water delivery fast, simple, and smart — built for modern life."
    },
    {
      "image": "assets/background/clear_back.jpg",
      "title": "The Problem",
      "text": "People waste time buying water every week — lifting, driving, and forgetting."
    },
    {
      "image": "assets/background/clearflow_back.jpg",
      "title": "Our Solution",
      "text": "One subscription. Weekly delivery. Always hydrated. No hassle."
    },
    {
      "image": "assets/background/coral_back.jpg",
      "title": "What Makes Us Different",
      "text": "We’re Cyprus’s first true water subscription service — tech-first and eco-friendly."
    },
    {
      "image": "assets/background/bottle_back.jpg",
      "title": "Our Mission",
      "text": "To make hydration effortless — for families, students, and businesses alike."
    },
    {
      "image": "assets/background/clear_back.jpg",
      "title": "Our Culture",
      "text": "We deliver with care. We recycle. We support each other like a crew."
    },
  ];

  @override
  void initState() {
    super.initState();
    _startSlideTimer();
    fetchProducts();
    fetchBeverageCategories();
  }

  void _startSlideTimer() {
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % slides.length;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
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
      print('❌ Failed to fetch products: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchBeverageCategories() async {
    try {
      final fetched = await wooService.fetchBeverageTypeCategories();
      setState(() {
        beverageCategories = fetched;
      });
    } catch (e) {
      print("❌ Error fetching beverage categories: $e");
    }
  }

  void filterByCategory(String name) {
    setState(() {
      selectedCategory = name;
      if (name == 'All') {
        filteredProducts = allProducts;
      } else {
        final matchedCategory = beverageCategories.firstWhere(
              (cat) => cat.name == name,
          orElse: () => Category(id: -1, name: '', slug: '', parent: -1),
        );
        filteredProducts = allProducts
            .where((p) => p.categoryIds.contains(matchedCategory.id))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            children: [
              _buildSlideCarousel(),
              const SizedBox(height: 10),
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
              buildCategoryScroll(),
              const SizedBox(height: 20),
              buildProductGrid(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSlideCarousel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox(
              height: 240,
              child: PageView.builder(
                controller: _pageController,
                itemCount: slides.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final slide = slides[index];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(slide['image']!, fit: BoxFit.cover),
                      Container(color: Colors.black.withOpacity(0.5)),
                      Positioned(
                        left: 16,
                        right: 16,
                        top: 40,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slide['title']!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              slide['text']!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  slides.length,
                      (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentIndex == index ? 12 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCategoryScroll() {
    final List<String> categories = ['All', ...beverageCategories.map((c) => c.name)];

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((cat) {
            final bool isSelected = selectedCategory == cat;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => filterByCategory(cat),
                selectedColor: Colors.blue.shade100,
                backgroundColor: Colors.grey.shade200,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget buildProductGrid() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (filteredProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text('No products found in this category.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: filteredProducts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.6,
      ),
      itemBuilder: (context, index) {
        final product = filteredProducts[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(product: product),
            ),
          ),
          child: ProductCard(product: product),
        );
      },
    );
  }
}
