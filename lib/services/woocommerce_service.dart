import 'dart:convert';
import 'package:http/http.dart' as http;

class WooCommerceService {
  final String baseUrl = 'https://lightsalmon-okapi-161109.hostingersite.com/'; // ✅ your WooCommerce URL
  final String consumerKey = 'ck_7c268a0db3e2cbb02a6da0ac54fe2fd303dd6920';              // ✅ paste yours
  final String consumerSecret = 'cs_511ddc5109e0cdbf1ba6ab50e985ec2f09ef9a66';           // ✅ paste yours

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
}
