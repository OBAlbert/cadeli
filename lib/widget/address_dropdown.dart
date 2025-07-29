import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/pick_location_page.dart';

class AddressDropdown extends StatefulWidget {
  const AddressDropdown({super.key});

  @override
  State<AddressDropdown> createState() => _AddressDropdownState();
}

class _AddressDropdownState extends State<AddressDropdown> {
  String? selectedAddress;
  List<String> addresses = [];
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? dropdownOverlay;

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
            (label) => snapshot.docs
            .firstWhere((doc) => doc['label'] == label)['isDefault'] == true,
        orElse: () => addresses.isNotEmpty ? addresses.first : '',
      );
    });
  }

  void toggleDropdown() {
    if (dropdownOverlay == null) {
      _showDropdown();
    } else {
      _removeDropdown();
    }
  }

  void _showDropdown() {
    final overlay = Overlay.of(context);
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final Offset offset = renderBox.localToGlobal(Offset.zero);
    final Size size = renderBox.size;

    final appBarBottom = Scaffold.of(context).appBarMaxHeight!;
    final bottomNavTop = MediaQuery.of(context).size.height - kBottomNavigationBarHeight;

    dropdownOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            top: appBarBottom,
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height - bottomNavTop,
            child: GestureDetector(
              onTap: _removeDropdown,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.1)),
              ),
            ),
          ),
          Positioned(
            top: offset.dy + size.height + 6,
            left: offset.dx,
            width: size.width,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var address in addresses) ...[
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedAddress = address;
                          });
                          _removeDropdown();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A233D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      if (address != addresses.last)
                        const Divider(color: Colors.black26),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _removeDropdown();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const PickLocationPage()),
                          );
                        },
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text("Add new Address"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D2952),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(dropdownOverlay!);
  }

  void _removeDropdown() {
    dropdownOverlay?.remove();
    dropdownOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    if (selectedAddress == null) return const SizedBox();

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: toggleDropdown,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black12),
            color: Colors.white,
          ),
          constraints: const BoxConstraints(maxWidth: 200),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on,
                  size: 18, color: Color(0xFF1A233D)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  selectedAddress!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF1A233D),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down,
                  size: 18, color: Color(0xFF1A233D)),
            ],
          ),
        ),
      ),
    );
  }
}

