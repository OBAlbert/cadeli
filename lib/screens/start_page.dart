import 'dart:async';
import 'package:flutter/material.dart';
import 'index_page.dart';

class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Wait 3 seconds and navigate to IndexPage
    _timer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const IndexPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/background/startpic.jpg'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
