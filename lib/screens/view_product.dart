import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../services/woocommerce_service.dart';
import '../widget/app_scaffold.dart';

class ViewProductPage extends StatefulWidget {
  final Product product;
  final List<Category> allCategories;

  const ViewProductPage({
    super.key,
    required this.product,
    required this.allCategories,
  });

  @override
  State<ViewProductPage> createState() => _ViewProductPageState();
}

class _ViewProductPageState extends State<ViewProductPage> {
  late List<Category> productCategories;

  @override
  void initState() {
    super.initState();

    productCategories = widget.allCategories
        .where((cat) => widget.product.categoryIds.contains(cat.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      currentIndex: 0, // This page is separate — doesn't use nav bar
      hideNavigationBar: true,
      onTabSelected: (_) {},
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Text(
              widget.product.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }
}
