import 'dart:async';
import 'package:cadeli/screens/register_page.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';


class IndexPage extends StatefulWidget {
  const IndexPage({super.key});

  @override
  State<IndexPage> createState() => _IndexPageState();
}

class _IndexPageState extends State<IndexPage> {
  final PageController _controller = PageController(viewportFraction: 0.95);
  int _currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      'image': 'assets/index/index1.jpg',
      'title': 'Fast Delivery',
      'subtitle': 'Get water delivered to your door in minutes.',
    },
    {
      'image': 'assets/index/index2.jpg',
      'title': 'Multiple Sizes',
      'subtitle': 'Choose bottles that suit your needs.',
    },
    {
      'image': 'assets/index/index3.jpg',
      'title': 'Easy Reordering',
      'subtitle': 'Repeat orders with one tap.',
    },
    {
      'image': 'assets/index/index4.jpg',
      'title': 'Fresh Sources',
      'subtitle': 'Water sourced from trusted springs.',
    },
  ];

  Timer? _autoSlideTimer;

  @override
  void initState() {
    super.initState();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_controller.hasClients) {
        int nextPage = (_currentPage + 1) % slides.length;
        _controller.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _autoSlideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA1BDC7),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            // Slide content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: slides.length,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 400,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              slides[index]['image']!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          slides[index]['title']!,
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          slides[index]['subtitle']!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                    (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  width: _currentPage == index ? 12 : 8,
                  height: _currentPage == index ? 12 : 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index ? Colors.blueAccent : Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Login and Register buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text("Login"),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Register",
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
