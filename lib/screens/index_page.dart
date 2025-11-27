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
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> slides = [
    {
      'image': 'assets/index/cadeli-account.png',
      'title': 'Create Account',
      'subtitle':
      'Set up your profile in seconds. Add your basic details and get ready to order your water quickly and easily.',
    },
    {
      'image': 'assets/index/cadeli-autosubscribe.png',
      'title': 'Set Your Order',
      'subtitle':
      'Auto Reorder and let the app repeat your water automatically. If you’d like to cancel it, just cancel the order..',
    },
    {
      'image': 'assets/index/cadeli-time.png',
      'title': 'Set Delivery Time',
      'subtitle':
      'Pick the exact day and time you want your delivery. Once you submit it, your order goes for approval.',
    },
    {
      'image': 'assets/index/cadeli-drive.png',
      'title': 'Free Delivery',
      'subtitle':
      'After approval, the Cadeli truck heads your way — always with free delivery.',
    },
    {
      'image': 'assets/index/cadeli-deliver.png',
      'title': 'Delivered to You',
      'subtitle':
      'Our delivery team brings your packs right to your doorstep. Fresh water, on time, every time.',
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
      body: Stack(
        fit: StackFit.expand,
        children: [
        Image.asset(
        'assets/background/fade_base.jpg',
        fit: BoxFit.cover,
      ),
      SafeArea(
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
                    double opacity = index == _currentPage ? 1.0 : 0.4;

                    return AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: Column(
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.45,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: double.infinity,
                                  height: double.infinity,
                                  color: Colors.white, // prevents leaks behind transparent PNGs
                                  child: Image.asset(
                                    slides[index]['image']!,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
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
                      ),
                    );
                  }

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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Create an account",
                      style: TextStyle(
                        color: Color(0xFF2C3E50),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/login');
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      minimumSize: const Size.fromHeight(55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      "Sign in",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
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
        ],
      )

    );
  }
}
