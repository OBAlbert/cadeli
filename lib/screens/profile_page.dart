import 'package:cadeli/screens/login_page.dart';
import 'package:cadeli/screens/orders_page.dart';
import 'package:cadeli/screens/addresses_page.dart';
import 'package:cadeli/screens/favorites_page.dart';
import 'package:cadeli/screens/ratings_page.dart';
import 'package:cadeli/screens/payment_methods_page.dart';
import 'package:cadeli/screens/contact_page.dart';
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
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController notesController = TextEditingController();
  final TextEditingController oldPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool isLoading = true;
  bool isEditing = false;
  bool showPasswordSection = false;
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
        // Fresh schema for new user
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
      } else {
        // If document exists but missing fields, patch it
        final existingData = doc.data()!;
        final Map<String, dynamic> patchedData = {
          'email': existingData['email'] ?? user.email ?? '',
          'fullName': existingData['fullName'] ?? '',
          'phone': existingData['phone'] ?? '',
          'notes': existingData['notes'] ?? '',
          'favourites': existingData['favourites'] ?? [],
          'orderHistory': existingData['orderHistory'] ?? [],
          'activeOrders': existingData['activeOrders'] ?? [],
          'createdAt': existingData['createdAt'] ?? Timestamp.now(),
        };
        await docRef.update(patchedData);
      }

      userData = (await docRef.get()).data();

      nameController.text = userData?['name'] ?? '';
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

  Future<void> changePassword() async {
    final oldPass = oldPasswordController.text.trim();
    final newPass = newPasswordController.text.trim();
    final confirmPass = confirmPasswordController.text.trim();

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    try {
      final cred = EmailAuthProvider.credential(email: user.email!, password: oldPass);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPass);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password changed successfully")),
      );
      setState(() => showPasswordSection = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Widget buildTextField(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE4EDF2),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
          ),
          margin: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            enabled: isEditing,
            style: const TextStyle(               // 👈 ADD THIS
              color: Colors.black,                // or any color that contrasts well
              fontSize: 16,
            ),
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
        const Text("Favourites", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                color: const Color(0xFF97CFE6),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Center(child: Text("Item", style: TextStyle(color: Colors.black))),
            ),
          ),
        )
      ],
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
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || userData == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF254573),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            buildTextField("Full Name", nameController),
            buildTextField("Phone", phoneController),
            buildTextField("Delivery Notes", notesController, maxLines: 2),
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
