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
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses');

  Future<void> _setDefault(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _col(uid);
    final batch = FirebaseFirestore.instance.batch();
    final all = await ref.get();
    for (final d in all.docs) {
      batch.update(d.reference, {'isDefault': d.id == id});
    }
    await batch.commit();
  }

  Future<void> _addAddressFlow() async {
    final label = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PickLocationPage()),
    );
    if (label is! String || label.trim().isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _col(uid);
    final hasDefault = (await ref.where('isDefault', isEqualTo: true).limit(1).get()).docs.isNotEmpty;

    final doc = await ref.add({
      'label': label.trim(),
      'isDefault': !hasDefault,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!hasDefault) await _setDefault(doc.id);
  }

  void _toggle() => _overlay == null ? _show() : _remove();

  void _show() {
    if (_overlay != null) return;
    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width.clamp(220.0, 340.0);

    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Tap outside to close with soft blur
          Positioned.fill(
            child: GestureDetector(
              onTap: _remove,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.08)),
              ),
            ),
          ),

          // Anchor the panel to the field
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, box.size.height + 6),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 14, offset: const Offset(0, 8)),
                  ],
                ),
                child: _DropdownList(
                  onPickNew: () async { _remove(); await _addAddressFlow(); },
                  onClose: _remove, // <-- close overlay, never Navigator.pop
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlay!);
    debugPrint('[AddressDropdown] overlay shown');
  }

  void _remove() {
    _overlay?.remove();
    _overlay = null;
    debugPrint('[AddressDropdown] overlay removed');
  }

  @override
  void dispose() {
    _remove(); // avoid leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _col(user.uid)
          .orderBy('isDefault', descending: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return _Shell(onTap: () {}, label: 'Loading...');
        }
        final docs = snap.data!.docs;
        debugPrint('[AddressDropdown] docs=${docs.length}');
        if (docs.isEmpty) {
          return _Shell(
            onTap: () async => _addAddressFlow(),
            label: 'Add address',
            showChevron: false,
            leading: const Icon(Icons.add_location_alt_outlined, size: 18, color: Color(0xFF1A233D)),
          );
        }

        // Find default (without firstWhere/orElse type mismatch)
        QueryDocumentSnapshot<Map<String, dynamic>> defaultDoc = docs.first;
        for (final d in docs) {
          if ((d.data()['isDefault'] ?? false) == true) { defaultDoc = d; break; }
        }
        final defaultLabel = (defaultDoc.data()['label'] ?? '').toString();

        return CompositedTransformTarget(
          link: _layerLink,
          child: _Shell(onTap: _toggle, label: defaultLabel),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final bool showChevron;
  final Widget? leading;
  const _Shell({
    required this.onTap,
    required this.label,
    this.showChevron = true,
    this.leading,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        constraints: const BoxConstraints(maxWidth: 280),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          leading ?? const Icon(Icons.location_on, size: 18, color: Color(0xFF1A233D)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A233D), fontWeight: FontWeight.w600),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF1A233D)),
          ],
        ]),
      ),
    );
  }
}

class _DropdownList extends StatelessWidget {
  final VoidCallback onPickNew;
  final VoidCallback onClose; // <-- NEW
  const _DropdownList({required this.onPickNew, required this.onClose});

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('addresses');

  Future<void> _setDefault(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final ref = _col(uid);
    final batch = FirebaseFirestore.instance.batch();
    final all = await ref.get();
    for (final d in all.docs) {
      batch.update(d.reference, {'isDefault': d.id == id});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _col(uid)
          .orderBy('isDefault', descending: true)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < docs.length; i++) ...[
              InkWell(
                onTap: () async {
                  await _setDefault(docs[i].id);
                  onClose(); // <-- close overlay (no Navigator.pop)
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Icon(
                      (docs[i].data()['isDefault'] ?? false)
                          ? Icons.star
                          : Icons.location_on_outlined,
                      size: 18,
                      color: const Color(0xFF1A233D),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (docs[i].data()['label'] ?? '').toString(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF1A233D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              if (i != docs.length - 1) const Divider(height: 12, color: Colors.black26),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPickNew,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add new address'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2952),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
