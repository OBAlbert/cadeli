// lib/pages/home_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'product_detail_page.dart';
import '../widget/product_card.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/woocommerce_service.dart';

const kCadeliBlue = Color(0xFF1A233D);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ---- UI state ----
  final PageController _pageController = PageController();
  late Timer _timer;
  int _currentIndex = 0;

  // ---- Data state ----
  final WooCommerceService wooService = WooCommerceService();
  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  List<Category> beverageCategories = []; // pills = children of parent 96
  bool isLoading = true;
  int? selectedCategoryId; // null = All

  // Parent category for "Beverage Type"
  static const int beverageParentId = 96;

  // ---- Slides ----
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
    _fetchProducts();
    _fetchPillCategories(); // only children under parent 96
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

  // ---- Data loads ----

  Future<void> _fetchProducts() async {
    try {
      final raw = await wooService.fetchProducts();
      final catMap = await wooService.fetchAllCategoriesMap();
      final parsed = raw
          .map<Product>((j) => Product.fromWooJson(j as Map<String, dynamic>, catMap))
          .toList();

      if (!mounted) return;
      setState(() {
        allProducts = parsed;
        filteredProducts = parsed;
        isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchPillCategories() async {
    try {
      final children = await wooService.fetchCategories(
        perPage: 100,
        parent: beverageParentId, // only categories under 96
        hideEmpty: false,
      );

      children.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      if (!mounted) return;
      setState(() => beverageCategories = children);
    } catch (_) {
      // swallow for production; UI remains usable
    }
  }

  // ---- Filtering ----

  void _filterByCategoryId(int? id) {
    setState(() {
      selectedCategoryId = id;
      filteredProducts = (id == null)
          ? allProducts
          : allProducts.where((p) => p.categoryIds.contains(id)).toList();
    });
  }

  // ---- UI ----

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
              _buildCategoryScroll(),
              const SizedBox(height: 20),
              _buildProductGrid(),
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
                onPageChanged: (index) => setState(() => _currentIndex = index),
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

  Widget _buildCategoryScroll() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('All'),
                selected: selectedCategoryId == null,
                onSelected: (_) => _filterByCategoryId(null),
                showCheckmark: false,
                selectedColor: kCadeliBlue,                       // ✅ dark blue when selected
                backgroundColor: Colors.white,                    // ✅ white when not
                side: BorderSide(
                  color: (selectedCategoryId == null)
                      ? kCadeliBlue
                      : Colors.grey.shade300,
                ),
                labelStyle: TextStyle(
                  color: (selectedCategoryId == null)
                      ? Colors.white
                      : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...beverageCategories.map((c) {
              final isSelected = selectedCategoryId == c.id;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.name),
                  selected: isSelected,
                  onSelected: (_) => _filterByCategoryId(isSelected ? null : c.id),
                  showCheckmark: false,
                  selectedColor: kCadeliBlue,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: isSelected ? kCadeliBlue : Colors.grey.shade300),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
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
            MaterialPageRoute(builder: (_) => ProductDetailPage(product: product)),
          ),
          child: ProductCard(product: product),
        );
      },
    );
  }
}
