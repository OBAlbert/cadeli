import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddressDropdown extends StatefulWidget {
  const AddressDropdown({super.key});

  @override
  State<AddressDropdown> createState() => _AddressDropdownState();
}

class _AddressDropdownState extends State<AddressDropdown> {
  String? selectedAddress;
  List<String> addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses')
        .orderBy('timestamp', descending: true)
        .get();

    setState(() {
      addresses = snapshot.docs.map((doc) => doc['label'] as String).toList();
      selectedAddress = addresses.firstWhere(
            (label) => snapshot.docs.firstWhere((doc) => doc['label'] == label)['isDefault'] == true,
        orElse: () => addresses.isNotEmpty ? addresses.first : '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (selectedAddress == null) return const SizedBox();

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedAddress,
        icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF1A233D), size: 20),
        isDense: true,
        isExpanded: true, // 👈 this is crucial!
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A233D),
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: Colors.white,
        onChanged: (String? newVal) {
          setState(() {
            selectedAddress = newVal;
          });
        },
        items: addresses.map((address) {
          return DropdownMenuItem(
            value: address,
            child: Text(
              address,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
    );
  }



}
