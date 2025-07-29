import 'dart:convert';
import 'package:http/http.dart' as http;

class WooCommerceService {
  final String baseUrl = 'https://lightsalmon-okapi-161109.hostingersite.com/'; // ✅ your WooCommerce URL
  final String consumerKey = 'ck_d27a39b0086e946fbb734f7d61af026b11cfcb25';              // ✅ paste yours
  final String consumerSecret = 'cs_92b4661b7f110883e3c2869a50b909d01114cea3';           // ✅ paste yours

  Future<List<dynamic>> fetchProducts() async {

    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/products?consumer_key=$consumerKey&consumer_secret=$consumerSecret&per_page=100',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List products = json.decode(response.body);
      return products;
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

  Future<Map<String, dynamic>?> createOrder({
    required String customerEmail,
    required List<Map<String, dynamic>> lineItems,
    required String paymentMethod,
    required String paymentTitle,
    required bool setPaid,
  }) async {
    final url = Uri.parse(
      '$baseUrl/wp-json/wc/v3/orders?consumer_key=$consumerKey&consumer_secret=$consumerSecret',
    );

    final body = json.encode({
      'payment_method': paymentMethod,
      'payment_method_title': paymentTitle,
      'set_paid': setPaid,
      'billing': {
        'email': customerEmail,
      },
      'line_items': lineItems,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else {
      print('Failed to create order: ${response.body}');
      return null;
    }
  }


}
