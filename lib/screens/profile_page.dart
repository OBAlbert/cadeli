import 'package:cadeli/screens/login_page.dart';
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
  final TextEditingController bioController = TextEditingController();

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
          'bio': '',
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
      bioController.text = userData?['bio'] ?? '';
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
        'bio': bioController.text.trim(),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: isEditing,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[300]),
          filled: true,
          fillColor: isEditing ? Colors.grey[850] : Colors.grey[800],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget buildFavouritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle("Favourites"),
        const SizedBox(height: 10),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            itemBuilder: (context, index) => Container(
              width: 100,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text("Item", style: TextStyle(color:Color(0xFF060606))),
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
          leading: const Icon(Icons.shopping_bag, color: Colors.grey),
          title: const Text("Order History", style: TextStyle(color: Color(0xFF060606))),
          subtitle: Text(
            "${userData?['orderHistory']?.length ?? 0} orders",
            style: const TextStyle(color: Colors.black26),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.local_shipping, color: Colors.grey),
          title: const Text("Active Orders", style: TextStyle(color: Color(0xFF060606))),
          subtitle: Text(
            "${userData?['activeOrders']?.length ?? 0} in progress",
            style: const TextStyle(color: Colors.black26),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.grey),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  );
                },
              )
            ],
          ),

          const CircleAvatar(
            radius: 40,
            backgroundColor: Colors.purple,
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 15),

          Text(
            user.email ?? "No email",
            style: TextStyle(color: Colors.grey[300]),
          ),
          const SizedBox(height: 20),

          buildTextField("Full Name", nameController),
          buildTextField("Phone", phoneController),
          buildTextField("Address", addressController),
          buildTextField("Bio", bioController, maxLines: 2),

          const SizedBox(height: 10),

          ElevatedButton.icon(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            label: Text(isEditing ? "Save" : "Edit Profile"),
            onPressed: () {
              if (isEditing) {
                saveProfile();
              } else {
                setState(() => isEditing = true);
              }
            },
          ),

          const SizedBox(height: 30),
          buildFavouritesSection(),
          const SizedBox(height: 30),
          buildOrderSummary(),
        ],
      ),
    );
  }
}
