import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widget/mini_product_card.dart';
import 'product_detail_page.dart';
import '../widget/product_card.dart';

import '../models/product.dart';
import '../services/sync_service.dart';
import '../services/woocommerce_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  List<Product> allProducts = [];
  List<Product> filteredProducts = [];
  String selectedCategory = 'All';
  bool isLoading = true;


  // 📸 Slides shown in the carousel
  final List<Map<String, String>>
  slides = [
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

   List<Map<String, String>> categories = [
    {'name': 'Sparkling', 'image': 'assets/categories/sparkling.png'},
    {'name': 'Mineral', 'image': 'assets/categories/mineral.png'},
    {'name': 'ITEO', 'image': 'assets/categories/iteo.png'},
    {'name': 'Evian Glass', 'image': 'assets/categories/evian.png'},
  ];


  final WooCommerceService wooService = WooCommerceService();


  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 2), (timer) {
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
        isLoading = false;
      });
      print('❌ Failed to fetch products: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🔵 Background layer (extendable)

        // 🟩 Foreground scroll content
        SingleChildScrollView(
          child: Column(
            children: [
              // 🔄 Auto-scrolling slideshow
              Padding(
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

                      // 🔘 Slide indicators (within rounded container)
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
              ),

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

              // 🧊 Categories scroll (horizontal logos)
              buildCategoryScroll(),

              const SizedBox(height: 20),

              // 🧺 Product grid (product cards)
              buildProductGrid(),

            ],
          ),
        ),
      ],
    );
  }

  Widget buildCategoryScroll() {
    final List<String> allCategories = ['All', 'Sparkling', 'Spring', 'Uncategorized'];

    return Padding(
      padding: const EdgeInsets.only(left: 16.0, top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: allCategories.map((cat) {
            final bool isSelected = selectedCategory == cat;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    selectedCategory = cat;
                    filteredProducts = cat == 'All'
                        ? allProducts
                        : allProducts.where((p) => p.categories.contains(cat)).toList();
                  });
                },
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
      return const Center(child: CircularProgressIndicator());
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
        return ProductCard(product: product);
      },
    );
  }


}
