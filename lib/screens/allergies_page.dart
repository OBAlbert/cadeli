import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AllergiesPage extends StatefulWidget {
  const AllergiesPage({super.key});
  @override
  State<AllergiesPage> createState() => _AllergiesPageState();
}

class _AllergiesPageState extends State<AllergiesPage> {
  final user = FirebaseAuth.instance.currentUser!;
  CollectionReference<Map<String, dynamic>> get col =>
      FirebaseFirestore.instance.collection('users').doc(user.uid).collection('allergies');

  Future<void> _delete(String id) async => col.doc(id).delete();

  Future<void> _add() async {
    final allergy = await _showAddDialog();
    if (allergy == null || allergy.trim().isEmpty) return;
    await col.add({'name': allergy.trim(), 'timestamp': FieldValue.serverTimestamp()});
  }

  Future<String?> _showAddDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Add Allergy',
          style: TextStyle(
            color: Color(0xFF0E1A36),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "e.g. peanuts, dairy, gluten...",
            hintStyle: TextStyle(color: Colors.black54),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFC70418), width: 2),
            ),
          ),
          style: const TextStyle(color: Color(0xFF0E1A36)),
        ),
        actionsPadding: const EdgeInsets.only(right: 12, bottom: 6),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF0E1A36), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC70418),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(String id, String current) async {
    final controller = TextEditingController(text: current);
    final updated = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Edit Allergy',
          style: TextStyle(
            color: Color(0xFF0E1A36),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFF0E1A36)),
          decoration: const InputDecoration(
            hintText: "Update allergy",
            hintStyle: TextStyle(color: Colors.black54),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFC70418), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF0E1A36), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC70418),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("Save", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (updated != null && updated.trim().isNotEmpty && updated != current) {
      await col.doc(id).update({'name': updated.trim()});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        title: const Text('My Allergies',
            style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0E1A36))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0E1A36)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: col.orderBy('timestamp', descending: true).snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;

              if (docs.isEmpty) {
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.medical_information, size: 40, color: Colors.black45),
                    const SizedBox(height: 10),
                    const Text('No allergies yet',
                        style: TextStyle(
                            color: Color(0xFF0E1A36), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Allergy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC70418),
                        foregroundColor: Colors.white,
                      ),
                    ),
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
                  final name = (data['name'] ?? '').toString();

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9FC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.7)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      leading: const Icon(Icons.medical_services_outlined,
                          color: Color(0xFF254573)),
                      title: Text(
                        name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Color(0xFF0E1A36)),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') await _edit(d.id, name);
                          if (v == 'delete') await _delete(d.id);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
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
        label: const Text('Add Allergy'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
