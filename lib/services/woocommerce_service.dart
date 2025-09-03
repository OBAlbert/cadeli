// lib/services/woocommerce_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/category.dart';

/// Lightweight metadata used to map category IDs -> name/parent/image.
class WooCategoryMeta {
  final int id;
  final String name;
  final int parent;
  final String image; // absolute URL or ''

  WooCategoryMeta({
    required this.id,
    required this.name,
    required this.parent,
    required this.image,
  });
}

class WooCommerceService {
  /// Public site root (with trailing slash).
  final String baseUrl = 'https://lightsalmon-okapi-161109.hostingersite.com/';

  /// Woo REST credentials (read scope).
  final String consumerKey = 'ck_d27a39b0086e946fbb734f7d61af026b11cfcb25';
  final String consumerSecret = 'cs_92b4661b7f110883e3c2869a50b909d01114cea3';

  /// In-memory category cache for fast ID lookups.
  static Map<int, WooCategoryMeta>? _categoryCache;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Ensure any Woo image src is absolute.
  String _absUrl(String? src) {
    if (src == null || src.isEmpty) return '';
    if (src.startsWith('http')) return src;
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (src.startsWith('/')) return '$root$src';
    return '$root/$src';
  }

  // ---------------------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------------------

  /// Fetch ALL products by paging until the API returns an empty page.
  Future<List<dynamic>> fetchProducts({
    int perPage = 100,
    String status = 'publish',
  }) async {
    final List<dynamic> all = [];
    final Set<int> seen = {};
    int page = 1;

    while (true) {
      final url = Uri.parse(
        '$baseUrl/wp-json/wc/v3/products'
            '?status=$status&per_page=$perPage&page=$page'
            '&consumer_key=$consumerKey&consumer_secret=$consumerSecret',
      );

      final resp = await http.get(url);
      if (resp.statusCode != 200) {
        throw Exception('❌ Failed to load products page $page: ${resp.statusCode}');
      }

      final List<dynamic> data = json.decode(resp.body);
      if (data.isEmpty) break;

      int newCount = 0;
      for (final j in data) {
        final id = (j['id'] as num).toInt();
        if (seen.add(id)) {
          all.add(j);
          newCount++;
        }
      }

      debugPrint('PRODS page=$page -> got=${data.length}, new=$newCount, total=${all.length}');
      if (newCount == 0) break; // server ignored page -> stop
      page++;
      if (page > 200) break;    // safety
    }

    debugPrint('✅ PRODUCTS total=${all.length}');
    return all;
  }

  /// Fetch a single product by Woo ID.
  Future<Map<String, dynamic>?> fetchProductById(String id) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/$id'
          '?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      return Map<String, dynamic>.from(json.decode(resp.body) as Map);
    }
    debugPrint('❌ fetchProductById($id) -> ${resp.statusCode}');
    return null;
  }

  // ---------------------------------------------------------------------------
  // Brands (taxonomy)
  // ---------------------------------------------------------------------------

  /// Fetch all brands with absolute image URLs.
  Future<List<Map<String, String>>> fetchBrands() async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/brands'
          '?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      throw Exception('❌ Failed to load brands: ${resp.statusCode}');
    }

    final List<dynamic> data = jsonDecode(resp.body);
    return data.map<Map<String, String>>((raw) {
      final img = (raw['image'] is Map) ? (raw['image']['src']?.toString() ?? '') : '';
      return {
        'id': raw['id'].toString(),
        'name': (raw['name'] ?? '').toString(),
        'image': _absUrl(img),
      };
    }).toList();
  }

  /// Convenience: fetch brand by ID.
  Future<Map<String, String>?> fetchBrandById(String brandId) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/brands/$brandId'
          '?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final resp = await http.get(url);
    if (resp.statusCode != 200) {
      debugPrint('❌ fetchBrandById($brandId) -> ${resp.statusCode}');
      return null;
    }

    final Map<String, dynamic> raw = jsonDecode(resp.body);
    final img = (raw['image'] is Map) ? (raw['image']['src']?.toString() ?? '') : '';
    return {
      'id': raw['id'].toString(),
      'name': (raw['name'] ?? '').toString(),
      'image': _absUrl(img),
    };
  }

  // ---------------------------------------------------------------------------
  // Categories
  // ---------------------------------------------------------------------------

  /// Fetch ALL categories by paging; supports optional parent + hideEmpty.
  Future<List<Category>> fetchCategories({
    int perPage = 100,
    int? parent,
    bool hideEmpty = false,
  }) async {
    final List<Category> all = [];
    final Set<int> seen = {};
    int page = 1;

    while (true) {
      final qs = [
        'per_page=$perPage',
        'page=$page',
        'hide_empty=$hideEmpty',
        if (parent != null) 'parent=$parent',
        'consumer_key=$consumerKey',
        'consumer_secret=$consumerSecret',
      ].join('&');

      final url = Uri.parse('$baseUrl/wp-json/wc/v3/products/categories?$qs');
      final resp = await http.get(url);
      if (resp.statusCode != 200) {
        throw Exception('❌ Failed to load categories page $page: ${resp.statusCode}');
      }

      final List<dynamic> data = jsonDecode(resp.body);
      if (data.isEmpty) break;

      int newCount = 0;
      for (final item in data) {
        final cat = Category.fromJson(item as Map<String, dynamic>);
        if (seen.add(cat.id)) {
          all.add(cat);
          newCount++;
        }
      }

      debugPrint('CATS page=$page -> got=${data.length}, new=$newCount, total=${all.length}');
      if (newCount == 0) break; // server repeated page -> stop
      page++;
      if (page > 200) break;    // safety
    }

    all.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    debugPrint('✅ CATEGORIES total=${all.length}');
    return all;
  }

  /// Build/return a cached map of all categories with absolute images.
  Future<Map<int, WooCategoryMeta>> fetchAllCategoriesMap({bool forceRefresh = false}) async {
    if (!forceRefresh && _categoryCache != null) return _categoryCache!;

    final categories = await fetchCategories(perPage: 100, hideEmpty: false);
    final map = <int, WooCategoryMeta>{};

    for (final c in categories) {
      final absImg = _absUrl(c.imageUrl);
      map[c.id] = WooCategoryMeta(
        id: c.id,
        name: c.name,
        parent: c.parent ?? 0,
        image: absImg,
      );
    }

    _categoryCache = map;
    return map;
  }
}
