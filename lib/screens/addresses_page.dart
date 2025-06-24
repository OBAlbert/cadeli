import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cadeli/screens/pick_location_page.dart';

class AddressesPage extends StatefulWidget {
  const AddressesPage({super.key});

  @override
  State<AddressesPage> createState() => _AddressesPageState();
}

class _AddressesPageState extends State<AddressesPage> {
  final User user = FirebaseAuth.instance.currentUser!;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<QueryDocumentSnapshot>> _loadAddresses() async {
    final snap = await _firestore
        .collection("users")
        .doc(user.uid)
        .collection("addresses")
        .orderBy("isDefault", descending: true)
        .get();
    return snap.docs;
  }

  Future<void> _setDefault(String id) async {
    final ref = _firestore.collection("users").doc(user.uid).collection("addresses");
    final batch = _firestore.batch();
    final allDocs = await ref.get();

    for (var doc in allDocs.docs) {
      batch.update(doc.reference, {"isDefault": doc.id == id});
    }
    await batch.commit();
    setState(() {});
  }

  Future<void> _deleteAddress(String id) async {
    await _firestore.collection("users").doc(user.uid).collection("addresses").doc(id).delete();
    setState(() {});
  }

  Future<void> _addNewAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PickLocationPage()),
    );
    if (result is String && result.isNotEmpty) {
      await _firestore.collection("users").doc(user.uid).collection("addresses").add({
        "label": result,
        "isDefault": false,
        "timestamp": Timestamp.now(),
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("My Addresses", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<QueryDocumentSnapshot>>(
        future: _loadAddresses(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final addresses = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final doc = addresses[index];
              final data = doc.data() as Map<String, dynamic>;

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Icon(
                    data['isDefault'] == true ? Icons.star : Icons.location_on,
                    color: const Color(0xFF254573),
                  ),
                  title: Text(data['label'] ?? "No address",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: data['isDefault'] == true
                      ? const Text("Default address", style: TextStyle(color: Colors.green))
                      : null,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'default') {
                        _setDefault(doc.id);
                      } else if (value == 'delete') {
                        _deleteAddress(doc.id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'default', child: Text("Set as default")),
                      const PopupMenuItem(value: 'delete', child: Text("Delete")),
                    ],
                    icon: const Icon(Icons.more_vert),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewAddress,
        backgroundColor: const Color(0xFFC70418),
        label: const Text("Add Address"),
        icon: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }
}
