import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';


class WooCommerceService {
  final String baseUrl = 'https://lightsalmon-okapi-161109.hostingersite.com/';
  final String consumerKey = 'ck_d27a39b0086e946fbb734f7d61af026b11cfcb25';
  final String consumerSecret = 'cs_92b4661b7f110883e3c2869a50b909d01114cea3';

  get image => null;           // ✅ paste yours

  Future<List<dynamic>> fetchProducts() async {


    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products?consumer_key=$consumerKey&consumer_secret=$consumerSecret&per_page=100',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {

      try {
        final List<dynamic> products = json.decode(response.body);
        print("Fetched ${products.length} products");
        return products;
      } catch (e) {
        print('JSON decode error: $e');
        print('Raw response: ${response.body}');
        throw Exception('Failed to parse products');
      }


    } else {
      throw Exception('Failed to load products: ${response.statusCode}');
    }

  }

  Future<Map<String, dynamic>?> fetchProductById(String id) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/$id?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      print('Error fetching product by ID: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, dynamic>> createWooOrder(
      List<dynamic> cartItems,
      Map<String, dynamic> address,
      String paymentMethod, {
        bool setPaid = false,
      }) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/orders?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final lineItems = cartItems.map<Map<String, dynamic>>((item) {
      return {
        'product_id': int.tryParse(item.id) ?? 0,
        'quantity': item.quantity,
      };
    }).toList();

    final billingShipping = {
      'first_name': (address['name'] ?? '').split(' ').first,
      'last_name': (address['name'] ?? '').split(' ').skip(1).join(' '),
      'address_1': address['line1'] ?? '',
      'city': address['city'] ?? '',
      'state': '',
      'postcode': '',
      'country': 'CY',
      'email': address['email'] ?? '',
      'phone': address['phone'] ?? '',

    };

    final body = jsonEncode({
      'payment_method': paymentMethod.toLowerCase().replaceAll(' ', '_'),
      'payment_method_title': paymentMethod,
      'set_paid': setPaid,
      'billing': billingShipping,
      'shipping': billingShipping,
      'line_items': lineItems,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 201) {
      final result = jsonDecode(response.body);
      print("✅ Woo order created: ${result['id']}");
      return result;
    } else {
      print("❌ Woo order failed: ${response.statusCode}");
      print(response.body);
      return {'status': 'failed'};
    }
  }

  Future<bool> capturePaymentForOrder(int orderId) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/orders/$orderId?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'set_paid': true}),
    );

    if (response.statusCode == 200) {
      print("✅ Payment captured for order $orderId");
      return true;
    } else {
      print("❌ Failed to capture payment: ${response.statusCode}");
      print(response.body);
      return false;
    }
  }


  // 📡 Fetch brand images (as logo URLs)
  Future<List<Map<String, String>>> fetchBrands() async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/brands?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map<Map<String, String>>((brand) {
        final brandImage = brand['image'];
        final String fullImageUrl = brandImage != null && brandImage['src'] != null
            ? '$baseUrl${brandImage['src'].toString().replaceFirst(RegExp(r'^/'), '')}' // ensure no double slashes
            : '';

        return {
          'id': brand['id'].toString(),
          'name': brand['name'] ?? '',
          'image': fullImageUrl,
        };
      }).toList();
    } else {
      throw Exception('❌ Failed to load brands: ${response.statusCode}');
    }
  }

  Future<Map<String, String>?> fetchBrandById(String brandId) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/brands/$brandId?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final brand = jsonDecode(response.body);

        return {
          'id': brand['id'].toString(),
          'name': brand['name'] ?? '',
          'image': brand['image'] != null && brand['image']['src'] != null
              ? '$baseUrl${brand['image']['src'].toString().replaceFirst(RegExp(r'^/'), '')}'
              : '',
        };
      } else {
        print('❌ Failed to fetch brand: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error fetching brand by ID: $e');
      return null;
    }
  }


  Future<List<Category>> fetchCategories() async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/categories?consumer_key=$consumerKey&consumer_secret=$consumerSecret&per_page=100',
    );

    final response = await http.get(url);

    print("🔍 Categories fetched:");

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Category.fromJson(item)).toList();
    } else {
      throw Exception('❌ Failed to load categories: ${response.statusCode}');
    }

  }

  // 📦 Fetch only 'Beverage Type' subcategories (parent = 96)
  Future<List<Category>> fetchBeverageTypeCategories() async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products/categories?consumer_key=$consumerKey&consumer_secret=$consumerSecret&parent=96&per_page=100',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print("✅ Beverage Type categories fetched: ${data.length}");
        return data.map((item) => Category.fromJson(item)).toList();
      } else {
        print('❌ Failed to load beverage type categories: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error fetching beverage type categories: $e');
      return [];
    }
  }



}
