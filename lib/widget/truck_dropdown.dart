import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/pick_truck_location_page.dart';

class TruckDropdown extends StatefulWidget {
  const TruckDropdown({super.key});

  @override
  State<TruckDropdown> createState() => _TruckDropdownState();
}

class _TruckDropdownState extends State<TruckDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlay;

  final _activeRef =
  FirebaseFirestore.instance.collection('config').doc('truckLocation');

  CollectionReference<Map<String, dynamic>> get _savedCol =>
      FirebaseFirestore.instance
          .collection('config')
          .doc('truckLocations')
          .collection('list');

  // ---- helpers -----------------------------------------------------

  Future<void> _setActiveFromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data();
    await _activeRef.set({
      'lat': data['lat'],
      'lng': data['lng'],
      'address': data['address'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addTruckFlow() async {
    _remove();
    await Future.delayed(const Duration(milliseconds: 80));
    final ok = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PickTruckLocationPage()),
    );
    if (ok == true && mounted) setState(() {});
  }

  void _toggle() => _overlay == null ? _show() : _remove();

  void _remove() {
    _overlay?.remove();
    _overlay = null;
  }

  void _show() {
    if (_overlay != null) return;

    final box = context.findRenderObject() as RenderBox;
    final width = box.size.width.clamp(220.0, 340.0);

    _overlay = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // dim & blur background
          Positioned.fill(
            child: GestureDetector(
              onTap: _remove,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(color: Colors.black.withOpacity(0.08)),
              ),
            ),
          ),

          // attached dropdown panel
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, box.size.height + 6),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: width,
                padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.6)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _TruckDropdownList(
                  onPickNew: _addTruckFlow,
                  onPickExisting: (doc) async {
                    await _setActiveFromDoc(doc);
                    _remove();
                  },
                  onClose: _remove,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  // -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _activeRef.snapshots(),
      builder: (_, snap) {
        String label = "Set truck location";

        if (snap.hasData && snap.data!.exists) {
          final data = snap.data!.data();
          if (data != null && (data['address'] ?? '').toString().isNotEmpty) {
            label = (data['address'] as String).trim();
          }
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: _Shell(
            label: label,
            onTap: _toggle,
            leading: const Icon(Icons.local_shipping,
                size: 18, color: Color(0xFF1A233D)),
          ),
        );
      },
    );
  }
}

// same visual shell as AddressDropdown
class _Shell extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  final Widget leading;

  const _Shell({
    required this.onTap,
    required this.label,
    required this.leading,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF1A233D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: Color(0xFF1A233D)),
          ],
        ),
      ),
    );
  }
}

// dropdown list content
class _TruckDropdownList extends StatelessWidget {
  final VoidCallback onPickNew;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onPickExisting;
  final VoidCallback onClose;

  const _TruckDropdownList({
    required this.onPickNew,
    required this.onPickExisting,
    required this.onClose,
  });

  CollectionReference<Map<String, dynamic>> get _savedCol =>
      FirebaseFirestore.instance
          .collection('config')
          .doc('truckLocations')
          .collection('list');

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _savedCol.orderBy('timestamp', descending: true).snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < docs.length; i++) ...[
              InkWell(
                onTap: () => onPickExisting(docs[i]),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Color(0xFF1A233D),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (docs[i].data()['address'] ?? '').toString(),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF1A233D),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Colors.redAccent,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Remove location?'),
                              content: const Text(
                                'This will remove the truck location from the saved list.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await docs[i].reference.delete();
                          }
                        },
                      ),
                    ],
                  ),

                ),
              ),
              if (i != docs.length - 1)
                const Divider(height: 12, color: Colors.black26),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onPickNew,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add truck location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D2952),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
