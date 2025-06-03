import 'package:cadeli/screens/login_page.dart';
import 'package:cadeli/screens/pick_location_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User user = FirebaseAuth.instance.currentUser!;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  bool isLoading = true;
  bool isEditing = false;
  Map<String, dynamic>? userData;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        await docRef.set({
          'email': user.email ?? '',
          'fullName': '',
          'address': '',
          'phone': '',
          'notes': '',
          'favourites': [],
          'orderHistory': [],
          'activeOrders': [],
          'createdAt': Timestamp.now(),
        });
      }

      userData = (await docRef.get()).data();

      nameController.text = userData?['fullName'] ?? '';
      addressController.text = userData?['address'] ?? '';
      phoneController.text = userData?['phone'] ?? '';
      notesController.text = userData?['notes'] ?? '';
    } catch (e) {
      print("Error loading profile: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to load profile")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> saveProfile() async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': nameController.text.trim(),
        'address': addressController.text.trim(),
        'phone': phoneController.text.trim(),
        'notes': notesController.text.trim(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Profile updated")),
      );

      setState(() => isEditing = false);
    } catch (e) {
      print("Update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to update profile")),
      );
    }
  }

  Widget buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE4EDF2),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              enabled: isEditing,
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF254573),
          ),
        ),
      ),
    );
  }

  Widget buildSectionItem(IconData icon, String title, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: const Color(0xFF254573)),
      title: Text(title, style: const TextStyle(color: Colors.black)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ?? () {},
    );
  }

  Widget buildQuickLinks() {
    return Column(
      children: [
        buildSectionItem(Icons.shopping_basket, "Orders"),
        buildSectionItem(Icons.location_on, "Addresses", onTap: () async {
          final selectedAddress = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PickLocationPage()),
          );
          if (selectedAddress != null && selectedAddress is String) {
            setState(() {
              addressController.text = selectedAddress;
            });
          }
        }),
        buildSectionItem(Icons.favorite_border, "Favorites"),
        buildSectionItem(Icons.star_border, "Ratings"),
        buildSectionItem(Icons.payment, "Payment Methods"),
        buildSectionItem(Icons.info_outline, "About Cadeli"),
        buildSectionItem(Icons.contact_mail, "Contact"),
      ],
    );
  }

  Widget buildFavouritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle("Favourites"),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) => Container(
              width: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF97CFE6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Center(
                child: Text("Item", style: TextStyle(color: Colors.black)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildOrderSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle("Order Summary"),
        const SizedBox(height: 10),
        ListTile(
          leading: const Icon(Icons.shopping_bag, color: Color(0xFF254573)),
          title: const Text("Order History", style: TextStyle(color: Colors.black)),
          subtitle: Text(
            "${userData?['orderHistory']?.length ?? 0} orders",
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.local_shipping, color: Color(0xFF254573)),
          title: const Text("Active Orders", style: TextStyle(color: Colors.black)),
          subtitle: Text(
            "${userData?['activeOrders']?.length ?? 0} in progress",
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF254573),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.logout, color: Colors.grey),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
              ),
            ),
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.purple,
              child: Icon(Icons.person, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              user.email ?? "No email",
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),

            buildTextField("Full Name", nameController),
            buildTextField("Phone", phoneController),
            buildTextField("Address", addressController),
            buildTextField("Delivery Notes", notesController, maxLines: 2),
            const SizedBox(height: 10),

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
            const SizedBox(height: 30),
            buildFavouritesSection(),
            const SizedBox(height: 30),
            buildOrderSummary(),
            const SizedBox(height: 30),
            buildQuickLinks(),
          ],
        ),
      ),
    );
  }
}
