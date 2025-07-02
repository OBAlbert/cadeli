import 'package:cadeli/screens/login_page.dart';
import 'package:cadeli/screens/orders_page.dart';
import 'package:cadeli/screens/addresses_page.dart';
import 'package:cadeli/screens/favorites_page.dart';
import 'package:cadeli/screens/product_detail_page.dart';
import 'package:cadeli/screens/ratings_page.dart';
import 'package:cadeli/screens/payment_methods_page.dart';
import 'package:cadeli/screens/contact_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cadeli/models/product.dart';

import '../services/woocommerce_service.dart';


class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User user = FirebaseAuth.instance.currentUser!;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = true;
  bool isEditing = false;
  bool showPasswordSection = false;
  Map<String, dynamic>? userData;
  List<Map<String, dynamic>> favoriteProducts = [];


  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'name': user.displayName,
        'phone': user.phoneNumber,
        'notes': '',
        'favourites': [],
        'orderHistory': [],
        'activeOrders': [],
        'createdAt': Timestamp.now(),
      });
    }

    final data = (await docRef.get()).data();
    userData = data;
    nameController.text = data?['fullName'] ?? '';
    phoneController.text = data?['phone'] ?? '';
    notesController.text = data?['notes'] ?? '';
    setState(() => isLoading = false);
  }

  Future<void> saveProfile() async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': nameController.text.trim(),
        'phone': phoneController.text.trim(),
        'notes': notesController.text.trim(),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated")));
      setState(() => isEditing = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update profile")));
    }
  }

  void loadFavoriteProducts() {
    _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .snapshots()
        .listen((snapshot) async {
      List<Map<String, dynamic>> updatedFavorites = [];

      for (var doc in snapshot.docs) {
        final productId = doc.id;

        // Try fetching from products collection first
        final productDoc = await _firestore.collection('products').doc(productId).get();

        if (productDoc.exists) {
          updatedFavorites.add(productDoc.data()!..['id'] = productId);
        } else {
          final data = doc.data();
          updatedFavorites.add({
            'id': productId,
            'name': data['name'] ?? '',
            'brand': data['brand'] ?? '',
            'imageUrl': data['imageUrl'] ?? '',
            'price': data['price'] ?? 0.0,
            'sizeOptions': data['sizeOptions'] ?? [],
            'packOptions': data['packOptions'] ?? [],
            'categories': data['categories'] ?? [],
          });
        }
      }

      setState(() {
        favoriteProducts = updatedFavorites;
      });
    });
  }

  Future<void> changePassword() async {
    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: oldPass);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password changed successfully")));
      setState(() => showPasswordSection = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
  }

  Widget buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF1A233D),
            )),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            enabled: isEditing,
            style: const TextStyle(color: Color(0xFF1A233D), fontSize: 15),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildFavourites() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Favourites",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF1A233D),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('users')
                .doc(user.uid)
                .collection('favorites')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Text(
                    "No favourite products yet.\nTap ❤️ on a product to add it here.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                );
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final productId = doc.id;

                  final product = Product(
                    id: productId,
                    name: data['name'] ?? '',
                    brand: data['brand'] ?? '',
                    price: (data['price'] ?? 0).toDouble(),
                    imageUrl: data['imageUrl'] ?? '',
                    sizeOptions: List<String>.from(data['sizeOptions'] ?? []),
                    packOptions: List<String>.from(data['packOptions'] ?? []),
                    categories: List<String>.from(data['categories'] ?? []),
                  );

                  return GestureDetector(
                    onTap: () async {
                      final wooService = WooCommerceService();
                      final wooProducts = await wooService.fetchProducts();

                      final matched = wooProducts.firstWhere(
                            (p) => p['id'].toString() == product.id,
                        orElse: () => null,
                      );

                      if (matched != null) {
                        final fullProduct = Product.fromWooJson(matched);

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('recentlyViewed')
                            .doc(fullProduct.id)
                            .set({'viewedAt': Timestamp.now()});

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailPage(product: fullProduct),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Product info could not be loaded.')),
                        );
                      }
                    },
                    child: buildGlassCard(product),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget buildGlassCard(Product product) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Image.network(
                product.imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 40);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            product.brand,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }



  Widget buildQuickLinks() {
    return Column(
      children: [
        buildTile(Icons.shopping_basket, "Orders", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrdersPage()))),
        buildTile(Icons.location_on, "Addresses", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressesPage()))),
        buildTile(Icons.favorite_border, "Favorites", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()))),
        buildTile(Icons.star_border, "Ratings", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RatingsPage()))),
        buildTile(Icons.payment, "Payment Methods", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodsPage()))),
        buildTile(Icons.info_outline, "About Cadeli"),
        buildTile(Icons.contact_mail, "Contact", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactPage()))),
      ],
    );
  }

  Widget buildTile(IconData icon, String text, [VoidCallback? onTap]) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF254573)),
      title: Text(text, style: const TextStyle(color: Color(0xFF1A233D))),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔓 Logout top right
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.grey),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                },
              ),
            ),

            // 👤 Avatar & Email
            const Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.purple,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
            Center(
              child: Text(user.email ?? "No email", style: const TextStyle(color: Colors.black54)),
            ),
            const SizedBox(height: 20),

            // ✏️ Editable fields
            buildTextField("Full Name", nameController),
            buildTextField("Phone", phoneController),
            buildTextField("Delivery Notes", notesController, maxLines: 2),

            // 🔘 Edit/Save
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(isEditing ? Icons.save : Icons.edit),
                label: Text(isEditing ? "Save" : "Edit Profile"),
                onPressed: () {
                  if (isEditing) {
                    saveProfile();
                  } else {
                    setState(() => isEditing = true);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC70418),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),

            // 🔒 Change password
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => showPasswordSection = !showPasswordSection),
              child: Text(
                showPasswordSection ? "Hide Password Section" : "Change Password",
                style: const TextStyle(color: Color(0xFF254573), fontWeight: FontWeight.w600),
              ),
            ),
            if (showPasswordSection)
              Column(
                children: [
                  buildTextField("Old Password", oldPasswordController),
                  buildTextField("New Password", newPasswordController),
                  buildTextField("Confirm New Password", confirmPasswordController),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF254573),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Update Password"),
                  )
                ],
              ),

            // 🌟 Favourites & Quick Links
            const SizedBox(height: 30),
            buildFavourites(),
            const SizedBox(height: 30),
            buildQuickLinks(),
          ],
        ),
      ),
    );
  }
}
