import 'dart:async';
import 'package:flutter/material.dart';

import '../services/sync_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

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
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 🟦 Background image from AppBar-down to bottom

        // 🟩 Foreground scroll content
        SingleChildScrollView(
          child: Column(
            children: [
              // 🔁 Slideshow
              SizedBox(
                height: 250,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
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
                              Text(slide['title']!,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text(slide['text']!,
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),

              // 🔷 Welcome Text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Text("Welcome to Cadeli",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
                    SizedBox(height: 16),
                    Text(
                      "We provide sustainable, clean, and affordable water. Delivered to your home every week. No stress, just hydration.",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 30),
                  ],
                ),
              ),

              // 🛒 Button
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Add navigation logic
                },
                icon: const Icon(Icons.shopping_basket),
                label: const Text("Browse Products"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),


              const SizedBox(height: 50),
            ],
          ),
        ),
      ],
    );
  }



}
