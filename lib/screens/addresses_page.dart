import 'dart:ui';
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
  final user = FirebaseAuth.instance.currentUser!;
  CollectionReference<Map<String, dynamic>> get col =>
      FirebaseFirestore.instance.collection('users').doc(user.uid).collection('addresses');

  Future<void> _setDefault(String id) async {
    final batch = FirebaseFirestore.instance.batch();
    final all = await col.get();
    for (final d in all.docs) {
      batch.update(d.reference, {'isDefault': d.id == id});
    }
    await batch.commit();
  }

  Future<void> _delete(String id) async => col.doc(id).delete();

  Future<void> _add() async {
    final label = await Navigator.push(context, MaterialPageRoute(builder: (_) => const PickLocationPage()));
    if (label is! String || label.trim().isEmpty) return;
    final hasDefault = (await col.where('isDefault', isEqualTo: true).limit(1).get()).docs.isNotEmpty;
    final doc = await col.add({
      'label': label.trim(),
      'isDefault': !hasDefault,
      'timestamp': FieldValue.serverTimestamp(),
    });
    if (!hasDefault) await _setDefault(doc.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: const Text('My Addresses', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E1A36))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0E1A36)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: col.orderBy('isDefault', descending: true).orderBy('timestamp', descending: true).snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.location_off, size: 40, color: Colors.black45),
                    const SizedBox(height: 10),
                    const Text('No addresses yet', style: TextStyle(color: Color(0xFF0E1A36), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(onPressed: _add, icon: const Icon(Icons.add_location_alt_outlined), label: const Text('Add Address')),
                  ]),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final d = docs[i];
                  final data = d.data();
                  final isDefault = (data['isDefault'] ?? false) as bool;
                  final label = (data['label'] ?? '').toString();

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.7)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, 8))],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: Icon(isDefault ? Icons.star : Icons.location_on, color: const Color(0xFF254573)),
                      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0E1A36))),
                      subtitle: isDefault ? const Text('Default address', style: TextStyle(color: Colors.green)) : null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'default') await _setDefault(d.id);
                          if (v == 'delete') await _delete(d.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'default', child: Text('Set as default')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        icon: const Icon(Icons.more_vert, color: Color(0xFF0E1A36)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: const Color(0xFFC70418),
        foregroundColor: Colors.white,
        label: const Text('Add Address'),
        icon: const Icon(Icons.add_location_alt_outlined),
      ),
    );
  }
}
