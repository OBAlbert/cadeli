import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/cart_provider.dart';
import '../models/product.dart';
import 'chat_thread_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // THEME
  static const _ink = Color(0xFF0E1A36);
  static const _cardBg = Color(0xFFF7F9FC);

  // Status groups
  static const activeStatuses  = ['pending', 'processing', 'out_for_delivery', 'active'];
  static const historyStatuses = ['delivered', 'completed', 'rejected', 'cancelled'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('My Orders', style: TextStyle(color: _ink, fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _ink,
          unselectedLabelColor: _ink.withOpacity(0.55),
          indicatorColor: _ink,
          tabs: const [Tab(text: 'Active'), Tab(text: 'History')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _OrdersStream(statuses: _OrdersPageState.activeStatuses,  mode: _OrdersMode.active),
          _OrdersStream(statuses: _OrdersPageState.historyStatuses, mode: _OrdersMode.history),
        ],
      ),
    );
  }
}

enum _OrdersMode { active, history }

class _OrdersStream extends StatelessWidget {
  const _OrdersStream({required this.statuses, required this.mode});
  final List<String> statuses;
  final _OrdersMode mode;

  static const _ink = _OrdersPageState._ink;
  static const _cardBg = _OrdersPageState._cardBg;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Please sign in to view orders', style: TextStyle(color: _ink)));
    }

    // IMPORTANT: only query fields allowed by your rules (userId / customerId).
    final base = FirebaseFirestore.instance.collection('orders');
    final sUser = base.where('userId', isEqualTo: user.uid).where('status', whereIn: statuses).snapshots();
    final sCust = base.where('customerId', isEqualTo: user.uid).where('status', whereIn: statuses).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: sUser,
      builder: (context, a) {
        if (a.hasError) {
          return _err(a.error);
        }
        if (a.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: sCust,
          builder: (context, b) {
            if (b.hasError) {
              return _err(b.error);
            }
            if (b.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // Merge A and B by doc id (avoid duplicates), then sort by updatedAt/timestamp desc.
            final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final d in a.data?.docs ?? const []) byId[d.id] = d;
            for (final d in b.data?.docs ?? const []) byId[d.id] = d;

            final docs = byId.values.toList()
              ..sort((x, y) {
                DateTime toDT(dynamic v) {
                  if (v is Timestamp) return v.toDate();
                  if (v is int)       return DateTime.fromMillisecondsSinceEpoch(v);
                  if (v is String)    return DateTime.tryParse(v) ?? DateTime.fromMillisecondsSinceEpoch(0);
                  return DateTime.fromMillisecondsSinceEpoch(0);
                }
                final ux = x.data()['updatedAt'] ?? x.data()['timestamp'];
                final uy = y.data()['updatedAt'] ?? y.data()['timestamp'];
                return toDT(uy).compareTo(toDT(ux));
              });

            if (docs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long, size: 64, color: _ink),
                      const SizedBox(height: 12),
                      Text(
                        mode == _OrdersMode.active ? 'No active orders yet' : 'No order history',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final m = docs[i].data();
                  final orderId = docs[i].id;
                  return _OrderCard(orderId: orderId, data: m, mode: mode);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _err(Object? e) => Center(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Text('Orders error: $e', style: const TextStyle(color: Colors.red)),
    ),
  );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.orderId, required this.data, required this.mode});
  final String orderId;
  final Map<String, dynamic> data;
  final _OrdersMode mode;

  static const _ink = _OrdersPageState._ink;
  static const _cardBg = _OrdersPageState._cardBg;

  static final Map<String, String?> _imgCache = {};

  String _fmtDate(dynamic tsOrMs) {
    DateTime d;
    if (tsOrMs is Timestamp) d = tsOrMs.toDate();
    else if (tsOrMs is int)  d = DateTime.fromMillisecondsSinceEpoch(tsOrMs);
    else if (tsOrMs is String) d = DateTime.tryParse(tsOrMs) ?? DateTime.now();
    else d = DateTime.now();
    return DateFormat('dd/MM').format(d);
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return const Color(0xFFFFE9C6);
      case 'processing':
      case 'active':  return const Color(0xFFDFF7E3);
      case 'out_for_delivery': return const Color(0xFFE6D9FF);
      case 'delivered':
      case 'completed': return const Color(0xFFDFF7E3);
      case 'rejected':
      case 'cancelled': return const Color(0xFFFDE2E1);
      default: return const Color(0xFFEFEFEF);
    }
  }
  Color _statusFg(String s) {
    switch (s.toLowerCase()) {
      case 'pending': return const Color(0xFFBE7A00);
      case 'active':  return const Color(0xFF116C3E);
      case 'out_for_delivery': return const Color(0xFF5C3ABF);
      case 'delivered':
      case 'completed': return const Color(0xFF116C3E);
      case 'cancelled': return const Color(0xFFAA1D1D);
      default: return const Color(0xFF444444);
    }
  }

  List<Map<String, dynamic>> _previewItems() {
    final woo = (data['wooLineItems'] as List?)?.cast<Map<String, dynamic>>();
    if (woo != null && woo.isNotEmpty) return woo;
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  }

  List<Map<String, dynamic>> _reorderItems() {
    return (data['items'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];
  }

  Future<String?> _firstImageUrl() async {
    final items = _previewItems();
    if (items.isEmpty) return null;
    final first = items.first;

    // 1) Woo line item: image: { src: 'https://...' }
    if (first['image'] is Map && (first['image']['src'] ?? '').toString().isNotEmpty) {
      return first['image']['src'].toString();
    }

    // 2) Sometimes a plain string URL
    if (first['image'] is String && (first['image'] as String).startsWith('http')) {
      return first['image'] as String;
    }

    // 3) Sometimes an "images" array
    if (first['images'] is List && (first['images'] as List).isNotEmpty) {
      final m = (first['images'] as List).first;
      if (m is Map && (m['src'] ?? '').toString().isNotEmpty) {
        return m['src'].toString();
      }
    }

    // 4) Fallback: look up product doc for its imageUrl
    final pid = (first['id'] ?? first['productId'])?.toString();
    if (pid == null) return null;
    if (_imgCache.containsKey(pid)) return _imgCache[pid];

    final snap = await FirebaseFirestore.instance.collection('products').doc(pid).get();
    String? url;
    if (snap.exists) {
      final m = snap.data();
      final s = (m?['imageUrl'] ?? m?['image'] ?? '').toString();
      url = s.isNotEmpty ? s : null;
    }
    _imgCache[pid] = url;
    return url;
  }

  double _totalAmount() {
    // Most reliable first: single-value totals commonly used by your checkout
    final direct =
        data['total'] ??
            data['amount'] ??
            data['grandTotal'] ??
            data['totalInclVat'] ??
            data['total_incl_vat'];

    double? _toD(v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final d = _toD(direct);
    if (d != null) return d;

    // Map-style totals fallbacks
    final totals = data['totals'] as Map<String, dynamic>?;
    if (totals != null) {
      final t = _toD(totals['totalInclVat']) ??
          _toD(totals['grandTotal']) ??
          _toD(totals['total']);
      if (t != null) return t;
    }

    // Timeline (older docs)
    final timeline = (data['timeline'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    if (timeline.isNotEmpty) {
      final t = _toD(timeline.first['total']);
      if (t != null) return t;
    }

    // Very old field names
    final legacy = _toD(data['totalCost']);
    return legacy ?? 0.0;
  }

  String get _status => (data['status'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final updatedAt = data['updatedAt'] ?? data['timestamp'] ?? data['meta']?['order_placed_at_ms'];
    final address   = data['address']?['address_1'] ?? data['meta']?['address_line'] ?? '';
    final slot      = data['timeSlot'] ?? data['meta']?['delivery_type'];
    final preview   = _previewItems();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (mode == _OrdersMode.active) {
          _showDetailsSheet(context, orderId, data, preview);
        } else {
          _showReceiptSheet(context, orderId, data, preview);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(minHeight: 108),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.7)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Static shopping-style icon for order list
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Builder(builder: (_) {
                final items = _previewItems();
                if (items.isNotEmpty && (items.first['imageUrl'] ?? '').toString().startsWith('http')) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      items.first['imageUrl'],
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.local_mall_outlined, size: 28, color: _ink),
                    ),
                  );
                }
                return const Icon(Icons.local_mall_outlined, size: 28, color: _ink);
              }),
            ),




            const SizedBox(width: 12),

            // Middle column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        'Order #$orderId',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _ink),
                      ),
                    ),
                    Text(_fmtDate(updatedAt), style: const TextStyle(fontSize: 12, color: _ink)),
                  ]),
                  const SizedBox(height: 6),
                  if (preview.isNotEmpty)
                    Text(
                      _itemsPreview(preview),
                      maxLines: 2,
                      softWrap: true,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _ink,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),

                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (address.toString().isNotEmpty) _chip(Icons.place, address, dense: true),
                        if (slot != null) _chip(Icons.schedule, slot.toString(), dense: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Right column (responsive, no fixed width)
            Flexible(
              flex: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statusPill(_status),
                  const SizedBox(height: 8),
                  Text(
                    '€${_totalAmount().toStringAsFixed(2)}',
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
                  ),
                  if (mode == _OrdersMode.active) const SizedBox(height: 8),
                  if (mode == _OrdersMode.active)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 90),
                      child: TextButton.icon(
                        onPressed: () {
                          final customerId = (data['userId'] ?? data['customerId'])?.toString() ?? '';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatThreadPage(orderId: orderId, customerId: customerId, isAdminView: false),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline, size: 15),
                        label: const Flexible(
                          child: Text(
                            'Chat',
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: _ink,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }

  String _itemsPreview(List<Map<String, dynamic>> items) {
    final parts = items.take(2).map((e) => '${(e['name'] ?? 'Item')} x${e['quantity'] ?? 1}').toList();
    final more  = items.length - parts.length;
    final s     = parts.join(', ') + (more > 0 ? '  +$more more' : '');
    return s.length > 90 ? '${s.substring(0, 87)}…' : s;
  }

  Widget _statusPill(String s) {
    final bg = _statusBg(s);
    final fg = _statusFg(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: fg.withOpacity(0.7), width: .6),
      ),
      child: Text(s.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _chip(IconData icon, String text, {bool dense = false}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: dense ? 14 : 16, color: _ink),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink, fontSize: 12),
          ),
        ),
      ]),
    );
  }


  String? _pidOfItem(Map it) {
    final pid = (it['product_id'] ?? it['productId'] ?? it['id']);
    return pid?.toString();
  }

  String? _thumbFromImmediate(Map it) {
    if (it['image'] is Map && (it['image']['src'] ?? '').toString().isNotEmpty) {
      return it['image']['src'].toString();
    }
    if (it['image'] is String && (it['image'] as String).startsWith('http')) {
      return it['image'].toString();
    }
    if (it['images'] is List && (it['images'] as List).isNotEmpty) {
      final m = (it['images'] as List).first;
      if (m is Map && (m['src'] ?? '').toString().isNotEmpty) return m['src'].toString();
    }
    if ((it['imageUrl'] ?? '').toString().startsWith('http')) return it['imageUrl'].toString();
    return null;
  }

  /// Builds a 44x44 image thumbnail for each product.
  /// Uses Firestore `imageUrl` first, then WooCommerce fallbacks.
  Widget _itemThumb(Map it, {double size = 44}) {
    // ✅ Primary: direct Firestore imageUrl (your current order schema)
    final img = (it['imageUrl'] ?? '').toString();
    if (img.isNotEmpty && img.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          img,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.local_mall_outlined, size: 28, color: _ink),
        ),
      );
    }

    // 🧩 WooCommerce-style "image": { src: ... }
    if (it['image'] is Map && (it['image']['src'] ?? '').toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          it['image']['src'].toString(),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    // 🖼 WooCommerce "images": [ {src: ...} ]
    if (it['images'] is List && (it['images'] as List).isNotEmpty) {
      final first = (it['images'] as List).first;
      if (first is Map && (first['src'] ?? '').toString().isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            first['src'].toString(),
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    // 🔎 Fallback: query Firestore product doc for its image
    final pid = (it['id'] ?? it['productId'])?.toString();
    if (pid == null) {
      return const Icon(Icons.local_mall_outlined, size: 28, color: _ink);
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('products').doc(pid).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final fallbackImg = (data?['imageUrl'] ?? '').toString();
        if (fallbackImg.isNotEmpty && fallbackImg.startsWith('http')) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              fallbackImg,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
        return const Icon(Icons.local_mall_outlined, size: 28, color: _ink);
      },
    );
  }

  // ===== SHEETS =====

  void _showDetailsSheet(BuildContext context, String orderId, Map<String, dynamic> data, List<Map<String, dynamic>> items) {
    final rawItems = (data['items'] ?? data['wooLineItems'] ?? []) as List;
    final items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();

    final address = data['address']?['address_1'] ?? data['meta']?['address_line'] ?? '';
    final method  = data['paymentMethod'] ?? data['payment']?['method'] ?? '—';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8, maxChildSize: 0.94, minChildSize: 0.5, expand: false,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: _grabber()),
              const SizedBox(height: 14),
              Text('Order #$orderId', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 8),
              _statusPill(_status),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _chip(Icons.place, address.toString()),
                  if (data['timeSlot'] != null) _chip(Icons.schedule, data['timeSlot'].toString()),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Items', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _ink)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it    = items[i];
                    final qty   = (it['quantity'] ?? 1) as num;
                    final price = (it['price'] is num) ? (it['price'] as num).toDouble()
                        : double.tryParse('${it['price']}') ?? 0.0;
                    final total = it['total'] is num ? (it['total'] as num).toDouble() : (qty * price);
                    final sym = _currencySymbolOf(data);
                    final unitPrice = _numFrom(it['price']) ?? 0;
                    final lineTotal = _numFrom(it['total']) ?? (qty > 0 ? unitPrice * qty : 0);
                    final displayUnit = unitPrice > 0 ? unitPrice : (qty > 0 ? lineTotal / qty : 0);
                    final thumb = _thumbFromItem(it);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      leading: _itemThumb(it, size: 44),

                      minVerticalPadding: 8,
                      visualDensity: VisualDensity.compact,

                      title: Text(
                        (it['name'] ?? 'Item').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      subtitle: Text(
                        '$sym${displayUnit.toStringAsFixed(2)} • x$qty',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        '$sym${lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Payment: ${method.toString().toUpperCase()}', style: const TextStyle(color: _ink)),
                Text('Total: €${_totalAmount().toStringAsFixed(2)}', style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: orderId));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order ID copied')));
                    },
                    icon: const Icon(Icons.copy, color: _ink),
                    label: const Text('Copy ID', style: TextStyle(color: _ink)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _ink),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final customerId = (data['userId'] ?? data['customerId'])?.toString() ?? '';
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatThreadPage(orderId: orderId, customerId: customerId, isAdminView: false),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ink,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ]),
            ]),
          );
        },
      ),
    );
  }

  double? _numFrom(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.').trim();
    return double.tryParse(s);
  }

  String? _thumbFromItem(Map it) {
    if (it['image'] is Map && (it['image']['src'] ?? '').toString().isNotEmpty) {
      return it['image']['src'].toString();
    }
    if (it['image'] is String && (it['image'] as String).startsWith('http')) {
      return it['image'].toString();
    }
    if (it['images'] is List && (it['images'] as List).isNotEmpty) {
      final m = (it['images'] as List).first;
      if (m is Map && (m['src'] ?? '').toString().isNotEmpty) return m['src'].toString();
    }
    if ((it['imageUrl'] ?? '').toString().startsWith('http')) return it['imageUrl'].toString();
    return null;
  }

  String _currencySymbolOf(Map<String, dynamic> order) {
    final c = (order['currency'] ?? order['meta']?['currency'] ?? 'EUR').toString().toUpperCase();
    switch (c) {
      case 'USD': return '\$';
      case 'GBP': return '£';
      case 'EUR': default: return '€';
    }
  }


  void _showReceiptSheet(BuildContext context, String orderId, Map<String, dynamic> data, List<Map<String, dynamic>> items) {
    final rawItems = (data['items'] ?? data['wooLineItems'] ?? []) as List;
    final items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();

    final subtotal = _computeSubtotal(items);
    final total    = _totalAmount();
    final vat      = (total - subtotal).clamp(0, total);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white, // 👈 force white

      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7, maxChildSize: 0.92, minChildSize: 0.5, expand: false,
        builder: (context, controller) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: _grabber()),
              const SizedBox(height: 14),
              Text('Receipt • #$orderId', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _ink)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it    = items[i];
                    final qty   = (it['quantity'] ?? 1) as num;
                    final price = (it['price'] is num)
                        ? (it['price'] as num).toDouble()
                        : double.tryParse('${it['price']}')
                        ?? (double.tryParse('${it['total']}') ?? 0.0) / (qty == 0 ? 1 : qty);
                    final totalLine = (it['total'] is num) ? (it['total'] as num).toDouble() : qty * price;
                    final sym = _currencySymbolOf(data);
                    final unitPrice = _numFrom(it['price']) ?? 0;
                    final lineTotal = _numFrom(it['total']) ?? (qty > 0 ? unitPrice * qty : 0);
                    final displayUnit = unitPrice > 0 ? unitPrice : (qty > 0 ? lineTotal / qty : 0);
                    final thumb = _thumbFromItem(it);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      leading: _itemThumb(it, size: 40),

                      title: Text(
                        (it['name'] ?? 'Item').toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      subtitle: Text(
                        '$sym${displayUnit.toStringAsFixed(2)} • x$qty',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w600),
                      ),
                      trailing: Text(
                        '$sym${lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    );
                  },
                ),
              ),
              const Divider(),

              _row('Subtotal', '€${subtotal.toStringAsFixed(2)}'),
              _row('VAT',      '€${vat.toStringAsFixed(2)}'),
              _rowBold('Total','€${total.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async { await _reorderToCart(context); },
                icon: const Icon(Icons.refresh),
                label: const Text('Re-order'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: _ink,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  double _computeSubtotal(List<Map<String, dynamic>> items) {
    double s = 0;
    for (final it in items) {
      final qty   = (it['quantity'] ?? 1) as num;
      final price = (it['price'] is num)
          ? (it['price'] as num).toDouble()
          : double.tryParse('${it['price']}')
          ?? (double.tryParse('${it['total']}') ?? 0.0) / (qty == 0 ? 1 : qty);
      s += price * qty;
    }
    return s;
  }

  Widget _row(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(a, style: const TextStyle(color: _ink)),
      Text(b, style: const TextStyle(color: _ink)),
    ]),
  );

  Widget _rowBold(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(a, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
      Text(b, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800)),
    ]),
  );

  Widget _grabber() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(2)),
  );

  // ===== ACTIONS =====

  Future<void> _reorderToCart(BuildContext context) async {
    final rawItems = _reorderItems();
    if (rawItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No items to re-order')));
      return;
    }

    final cart = context.read<CartProvider>();
    int added = 0;

    for (final it in rawItems) {
      final pid = (it['id'] ?? it['productId'])?.toString();
      final qty = (it['quantity'] ?? 1) as num;
      if (pid == null) continue;

      final snap = await FirebaseFirestore.instance.collection('products').doc(pid).get();
      if (!snap.exists) continue;
      final m = snap.data()!;

      final p = Product(
        id: (m['id'] ?? pid).toString(),
        name: (m['name'] ?? it['name'] ?? 'Product').toString(),
        brand: (m['brand'] ?? '').toString(),
        price: (m['price'] is num) ? (m['price'] as num).toDouble() : double.tryParse('${m['price']}') ?? 0.0,
        imageUrl: (m['imageUrl'] ?? m['image'] ?? '').toString(),
        brandId: (m['brandId'] ?? '0').toString(),
        brandImage: (m['brandImage'] ?? '').toString(),
        categoryIds: (m['categoryIds'] as List?)?.map((e) => int.tryParse('$e') ?? 0).toList() ?? const [],
        categoryNames: (m['categoryNames'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        categoryImages: (m['categoryImages'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        categoryParents: (m['categoryParents'] as List?)?.map((e) => int.tryParse('$e') ?? 0).toList(),
        salePrice: (m['salePrice'] is num) ? (m['salePrice'] as num).toDouble() : double.tryParse('${m['salePrice']}'),
      );

      cart.add(p, qty: qty.toInt());
      added += qty.toInt();
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added $added item(s) to cart')));
  }
}
