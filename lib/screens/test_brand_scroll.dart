import 'package:flutter/material.dart';
import '../services/woocommerce_service.dart';
import '../widget/brand_scroll_row.dart';

class TestBrandScrollPage extends StatefulWidget {
  const TestBrandScrollPage({super.key});

  @override
  State<TestBrandScrollPage> createState() => _TestBrandScrollPageState();
}

class _TestBrandScrollPageState extends State<TestBrandScrollPage> {
  final WooCommerceService wooService = WooCommerceService();
  List<Map<String, String>> brands = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBrands();
  }

  Future<void> loadBrands() async {
    try {
      final fetched = await wooService.fetchBrands();
      print('✅ Brands fetched:');
      for (var b in fetched) {
        print('${b['name']} - ${b['image']}');
      }
      setState(() {
        brands = fetched;
        isLoading = false;
      });
    } catch (e) {
      print("❌ Error loading brands: $e");
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Brand Scroll Test")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.only(top: 20),
        child: BrandScrollRow(
          brandData: brands,
          onBrandTap: (id) {
            print("👉 Brand tapped: ID $id");
          },
        ),
      ),
    );
  }
}
