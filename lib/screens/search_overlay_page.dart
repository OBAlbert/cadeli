import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/product.dart';
import '../screens/product_detail_page.dart';

class SearchOverlayPage extends StatefulWidget {
  const SearchOverlayPage({Key? key}) : super(key: key);

  @override
  _SearchOverlayPageState createState() => _SearchOverlayPageState();
}

class _SearchOverlayPageState extends State<SearchOverlayPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> keywordSuggestions = [
    'Zanatzia', 'Kykko', 'Sparkling', 'Spring', 'Lanitis'
  ];
  List<Product> searchResults = [];
  List<Product> recentViewed = [];
  bool isLoading = false;
  String? errorMessage;

  // Replace with your WooCommerce API base URL and keys
  final String baseUrl = 'https://lightsalmon-okapi-161109.hostingersite.com/'; // ✅ your WooCommerce URL
  final String consumerKey = 'ck_7c268a0db3e2cbb02a6da0ac54fe2fd303dd6920';              // ✅ paste yours
  final String consumerSecret = 'cs_511ddc5109e0cdbf1ba6ab50e985ec2f09ef9a66';           // ✅ paste yours


  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _onSearchChanged(_searchController.text));
    _loadRecentViewed();
  }

  void _onSearchChanged(String value) async {
    if (value.isEmpty) {
      setState(() {
        searchResults.clear();
        errorMessage = null;
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(Uri.parse(
        '$baseUrl?search=$value&consumer_key=$consumerKey&consumer_secret=$consumerSecret',
      ));

      if (response.statusCode == 200) {
        final List productsJson = json.decode(response.body);
        setState(() {
          searchResults = productsJson.map((json) => Product.fromWooJson(json)).toList();
          isLoading = false;
          errorMessage = searchResults.isEmpty ? 'No results found for "$value".' : null;
        });
      } else {
        throw Exception('Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Something went wrong. Please try again later.';
      });
    }
  }

  Future<void> _loadRecentViewed() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final recentIds = List<String>.from(doc.data()?['recentlyViewed'] ?? []);

    if (recentIds.isEmpty) return;

    try {
      final response = await http.get(Uri.parse(
        '$baseUrl?include[]=${recentIds.join('&include[]=')}&consumer_key=$consumerKey&consumer_secret=$consumerSecret',
      ));
      if (response.statusCode == 200) {
        final List productsJson = json.decode(response.body);
        setState(() {
          recentViewed = productsJson.map((json) => Product.fromWooJson(json)).toList();
        });
      }
    } catch (_) {
      // ignore errors for recent
    }
  }

  Future<void> _addToRecentlyViewed(Product product) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await ref.get();
    final List<String> current = List<String>.from(doc.data()?['recentlyViewed'] ?? []);

    // remove if already exists, then add to front
    current.remove(product.id);
    current.insert(0, product.id);

    // keep only last 10
    if (current.length > 10) current.removeRange(10, current.length);

    await ref.set({'recentlyViewed': current}, SetOptions(merge: true));
  }

  Widget _buildProductCard(Product product) {
    return GestureDetector(
      onTap: () {
        _addToRecentlyViewed(product);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(product: product),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                product.imageUrl,
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(product.name, maxLines: 2, textAlign: TextAlign.center),
                  SizedBox(height: 4),
                  Text('€${product.price}', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search for products...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: keywordSuggestions
                    .map((word) => ActionChip(
                  label: Text(word),
                  onPressed: () {
                    _searchController.text = word;
                    _onSearchChanged(word);
                  },
                ))
                    .toList(),
              ),
            ),
            if (recentViewed.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text('Recently Viewed', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                height: 180,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: recentViewed.map(_buildProductCard).toList(),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text('All Results', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            if (isLoading)
              Center(child: CircularProgressIndicator())
            else if (errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(errorMessage!, style: TextStyle(color: Colors.grey)),
              )
            else
              Expanded(
                child: ListView(
                  children: searchResults.map(_buildProductCard).toList(),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue[900],
        onPressed: () => Navigator.pop(context),
        child: Icon(Icons.close, color: Colors.white),
      ),
    );
  }
}
