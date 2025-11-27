import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/cart_provider.dart';
import '../models/product.dart';
import 'chat_thread_page.dart';
import 'package:cloud_functions/cloud_functions.dart';


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
        children: [
          _OrdersStream(statuses: _OrdersPageState.activeStatuses,  mode: _OrdersMode.active),
          _OrdersStream(statuses: _OrdersPageState.historyStatuses, mode: _OrdersMode.history),
        ],
      ),
    );
  }
}

enum _OrdersMode { active, history }

class _OrdersStream extends StatelessWidget {
  _OrdersStream({required this.statuses, required this.mode});
  final List<String> statuses;
  final _OrdersMode mode;
  final ValueNotifier<String> sortMode = ValueNotifier('newest');


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

            // ---- MERGE QUERIES SAFELY ----
            final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
            for (final d in a.data?.docs ?? const []) byId[d.id] = d;
            for (final d in b.data?.docs ?? const []) byId[d.id] = d;

            final merged = byId.values.toList();

// ---- FILTER PARENT / CHILD LOGIC ----
            List<QueryDocumentSnapshot<Map<String, dynamic>>> filtered = [];

            for (final doc in merged) {
              final m = doc.data();

              final bool isSubscription = m['isSubscription'] == true;
              final String? parentId = (m['parentId'] ?? m['subscription_parent'])?.toString();
              final bool isChild = isSubscription && parentId != null && parentId.trim().isNotEmpty;

              if (mode == _OrdersMode.active) {
                // ⭐ ACTIVE TAB RULES:
                // - show parent subscription orders only
                // - show normal orders (not subscription)
                if (isSubscription) {
                  if (!isChild) filtered.add(doc);     // parent only
                } else {
                  filtered.add(doc);                  // normal order
                }
              } else {
                // ⭐ HISTORY TAB RULES:
                // - show delivered/complete child cycles
                // - show delivered normal orders
                if (isSubscription) {
                  if (isChild) filtered.add(doc);     // only child cycles in history
                } else {
                  filtered.add(doc);                  // normal delivered orders
                }
              }
            }

            // ---- SORT WITH DROPDOWN OPTIONS ----
            filtered.sort((x, y) {
              final mX = x.data();
              final mY = y.data();

              double totalX = double.tryParse(mX['total']?.toString() ?? '') ?? 0.0;
              double totalY = double.tryParse(mY['total']?.toString() ?? '') ?? 0.0;


              int cycleX = mX['cycle_number'] ?? 0;
              int cycleY = mY['cycle_number'] ?? 0;

              DateTime toDT(dynamic v) {
                if (v is Timestamp) return v.toDate();
                if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
                if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
                return DateTime.now();
              }

              final dateX = toDT(mX['updatedAt'] ?? mX['timestamp']);
              final dateY = toDT(mY['updatedAt'] ?? mY['timestamp']);

              switch (sortMode.value) {
                case 'oldest':
                  return dateX.compareTo(dateY);
                case 'high_total':
                  return totalY.compareTo(totalX);
                case 'low_total':
                  return totalX.compareTo(totalY);
                case 'cycle':
                  return cycleY.compareTo(cycleX);
                default: // newest
                  return dateY.compareTo(dateX);
              }
            });

            if (filtered.isEmpty) {
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

            return Column(
              children: [
                if (mode == _OrdersMode.history)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child:DropdownButtonFormField<String>(
                      value: sortMode.value,
                      dropdownColor: Colors.white, // menu background
                      style: const TextStyle(
                        color: Color(0xFF0E1A36), // dark blue text
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Sort by',
                        labelStyle: const TextStyle(
                          color: Color(0xFF0E1A36),
                          fontWeight: FontWeight.w600,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0E1A36), width: 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFF0E1A36), width: 1.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'newest', child: Text('Newest')),
                        DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                        DropdownMenuItem(value: 'high_total', child: Text('Highest Total')),
                        DropdownMenuItem(value: 'low_total', child: Text('Lowest Total')),
                        DropdownMenuItem(value: 'cycle', child: Text('Cycle Number')),
                      ],
                      onChanged: (v) => sortMode.value = v ?? 'newest',
                    )

                  ),

                const SizedBox(height: 10),

                Expanded(                               // ✔️ FIX: wrap list in Expanded
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final m = filtered[i].data();
                      final orderId = filtered[i].id;
                      return _OrderCard(orderId: orderId, data: m, mode: mode);
                    },
                  ),
                ),
              ],
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

  // --------- BASIC HELPERS ---------

  bool get _isSubscription => data['isSubscription'] == true;

  String? get _parentId {
    final v = data['parentId'] ?? data['subscription_parent'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  bool get _isChildCycle => _isSubscription && _parentId != null;

  int get _cycleNumber {
    final raw = data['cycle_number'] ?? data['cycleNumber'] ?? data['meta']?['cycle_number'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 1;
  }

  String get _status => (data['status'] ?? '').toString();

  String _shortId(String id) => id.length <= 6 ? id : id.substring(0, 6);

  /// For chat we ALWAYS want to attach to the parent subscription,
  /// so all cycles share one thread. One-off orders use their own id.
  String get _chatOrderId {
    if (_isChildCycle && _parentId != null) return _parentId!;
    return orderId;
  }

  String _fmtDate(dynamic tsOrMs) {
    DateTime d;
    if (tsOrMs is Timestamp) {
      d = tsOrMs.toDate();
    } else if (tsOrMs is int) {
      d = DateTime.fromMillisecondsSinceEpoch(tsOrMs);
    } else if (tsOrMs is String) {
      d = DateTime.tryParse(tsOrMs) ?? DateTime.now();
    } else {
      d = DateTime.now();
    }
    return DateFormat('dd/MM').format(d);
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFFE9C6);
      case 'processing':
      case 'active':
        return const Color(0xFFDFF7E3);
      case 'out_for_delivery':
        return const Color(0xFFE6D9FF);
      case 'delivered':
      case 'completed':
        return const Color(0xFFDFF7E3);
      case 'rejected':
      case 'cancelled':
        return const Color(0xFFFDE2E1);
      default:
        return const Color(0xFFEFEFEF);
    }
  }

  Color _statusFg(String s) {
    switch (s.toLowerCase()) {
      case 'pending':
        return const Color(0xFFBE7A00);
      case 'active':
        return const Color(0xFF116C3E);
      case 'out_for_delivery':
        return const Color(0xFF5C3ABF);
      case 'delivered':
      case 'completed':
        return const Color(0xFF116C3E);
      case 'cancelled':
        return const Color(0xFFAA1D1D);
      default:
        return const Color(0xFF444444);
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
    final direct = data['total'] ??
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

  Future<bool?> _confirmDialog(
      BuildContext context, {
        required String title,
        required String message,
        String yesText = "Yes",
        String noText = "No",
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                const SizedBox(height: 12),
                Text(message,
                    style: const TextStyle(
                        fontSize: 15, height: 1.4, color: Colors.black87)),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // NO BUTTON
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.black87),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(noText,
                          style: const TextStyle(color: Colors.black87)),
                    ),
                    const SizedBox(width: 12),

                    // YES BUTTON
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(yesText),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }



  // --------- WIDGET BUILD ---------

  @override
  Widget build(BuildContext context) {
    final updatedAt = data['updatedAt'] ??
        data['timestamp'] ??
        data['meta']?['order_placed_at_ms'];
    final address = data['address']?['address_1'] ??
        data['meta']?['address_line'] ??
        '';
    final slot = data['timeSlot'] ?? data['meta']?['delivery_type'];
    final preview = _previewItems();

    // Title logic changes depending on parent/child/mode
    String title;
    if (_isSubscription) {
      if (_isChildCycle) {
        // Child cycle (mostly appears in History tab)
        title = 'Cycle $_cycleNumber • Subscription';
      } else {
        // Parent subscription (Active tab)
        title = 'Subscription • Cycle $_cycleNumber';
      }
    } else {
      title = 'Order #$orderId';
    }

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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left icon / thumbnail
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
                if (items.isNotEmpty &&
                    (items.first['imageUrl'] ?? '')
                        .toString()
                        .startsWith('http')) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      items.first['imageUrl'],
                      fit: BoxFit.cover,
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) =>
                      const Icon(Icons.local_mall_outlined,
                          size: 28, color: _ink),
                    ),
                  );
                }
                return const Icon(Icons.local_mall_outlined,
                    size: 28, color: _ink);
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: _ink,
                        ),
                      ),
                    ),
                    Text(
                      _fmtDate(updatedAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: _ink,
                      ),
                    ),
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
                        if (address.toString().isNotEmpty)
                          _chip(Icons.place, address, dense: true),
                        if (slot != null)
                          _chip(Icons.schedule, slot.toString(), dense: true),
                        if (_isChildCycle && _parentId != null)
                          _chip(
                            Icons.link,
                            'Parent #${_shortId(_parentId!)}',
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Right column
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _statusPill(_status),
                const SizedBox(height: 8),

                Text(
                  '€${_totalAmount().toStringAsFixed(2)}',
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(
                    color: _ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (mode == _OrdersMode.active && _isSubscription && !_isChildCycle)
                  IconButton(
                    icon: const Icon(Icons.list_alt, size: 20, color: _ink),
                    splashRadius: 20,
                    onPressed: () => _showCyclesSheet(context, orderId),
                  ),

                if (mode == _OrdersMode.active && _isSubscription && !_isChildCycle)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    splashRadius: 20,
                    onPressed: () => _cancelSubscription(context, orderId),
                  ),

                if (mode == _OrdersMode.active)
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline, size: 20, color: _ink),
                    splashRadius: 20,
                    onPressed: () {
                      final customerId = (data['userId'] ?? data['customerId'])?.toString() ?? '';
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatThreadPage(
                            orderId: _chatOrderId,
                            customerId: customerId,
                            isAdminView: false,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // --------- SMALL UI HELPERS ---------

  String _itemsPreview(List<Map<String, dynamic>> items) {
    final parts = items
        .take(2)
        .map((e) => '${(e['name'] ?? 'Item')} x${e['quantity'] ?? 1}')
        .toList();
    final more = items.length - parts.length;
    final s = parts.join(', ') + (more > 0 ? '  +$more more' : '');
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
      child: Text(
        s.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String text, {bool dense = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
        ],
      ),
    );
  }

  String? _pidOfItem(Map it) {
    final pid = (it['product_id'] ?? it['productId'] ?? it['id']);
    return pid?.toString();
  }

  String? _thumbFromImmediate(Map it) {
    if (it['image'] is Map &&
        (it['image']['src'] ?? '').toString().isNotEmpty) {
      return it['image']['src'].toString();
    }
    if (it['image'] is String &&
        (it['image'] as String).startsWith('http')) {
      return it['image'].toString();
    }
    if (it['images'] is List && (it['images'] as List).isNotEmpty) {
      final m = (it['images'] as List).first;
      if (m is Map && (m['src'] ?? '').toString().isNotEmpty) {
        return m['src'].toString();
      }
    }
    if ((it['imageUrl'] ?? '').toString().startsWith('http')) {
      return it['imageUrl'].toString();
    }
    return null;
  }

  Widget _itemThumb(Map it, {double size = 44}) {
    // Primary: direct Firestore imageUrl (your current order schema)
    final img = (it['imageUrl'] ?? '').toString();
    if (img.isNotEmpty && img.startsWith('http')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          img,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.local_mall_outlined,
            size: 28,
            color: _ink,
          ),
        ),
      );
    }

    // WooCommerce-style "image": { src: ... }
    if (it['image'] is Map &&
        (it['image']['src'] ?? '').toString().isNotEmpty) {
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

    // WooCommerce "images": [ {src: ...} ]
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

    // Fallback: query Firestore product doc for its image
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

// ================= CYCLES LIST SHEET =================
  void _showCyclesSheet(BuildContext context, String parentId) async {
    final qs = await FirebaseFirestore.instance
        .collection('orders')
        .where('parentId', isEqualTo: parentId)
        .orderBy('cycle_number')
        .get();

    final cycles = qs.docs;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Subscription Cycles',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),

              ...cycles.map((c) {
                final m = c.data();
                final cycleNum = m['cycle_number'] ?? 1;
                final delivered = m['updatedAt'] ?? m['timestamp'];

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Cycle $cycleNum'),
                  subtitle: Text(_fmtDate(delivered)),
                  trailing: const Icon(Icons.receipt_long),
                  onTap: () {
                    Navigator.pop(context);
                    _showReceiptSheet(context, c.id, m, (m['items'] as List?)?.cast<Map<String, dynamic>>() ?? []);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ================= CANCEL SUBSCRIPTION =================
  void _cancelSubscription(BuildContext context, String parentId) async {
    final ok = await _confirmDialog(
      context,
      title: "Cancel Subscription?",
      message: "Future cycles will stop. This cannot be undone.",
      yesText: "Yes, cancel",
      noText: "No",
    );


    if (ok != true) return;

    try {
      final callable =
      FirebaseFunctions.instance.httpsCallable('cancelSubscription');
      await callable.call(<String, dynamic>{
        'docId': parentId,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subscription cancelled')),
      );
    } on FirebaseFunctionsException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel: ${e.message ?? 'Unknown error'}'),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong, please try again.'),
        ),
      );
    }
  }



  // ===== SHEETS =====
// Active Order Details Sheet
  void _showDetailsSheet(
      BuildContext context,
      String orderId,
      Map<String, dynamic> data,
      List<Map<String, dynamic>> preview,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Order Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${orderId.substring(0, 6)}',
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // ITEMS LIST
              ...preview.map((item) => Row(
                children: [
                  _itemThumb(item, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item["name"]} x${item["quantity"]}',
                      style: const TextStyle(fontSize: 14, color: _ink),
                    ),
                  )
                ],
              )),

              const SizedBox(height: 20),

              // TOTAL
              Text(
                'Total: €${_totalAmount().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

// History Receipt Sheet
  void _showReceiptSheet(
      BuildContext context,
      String orderId,
      Map<String, dynamic> data,
      List<Map<String, dynamic>> preview,
      ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Receipt',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 16),

              ...preview.map((item) => Row(
                children: [
                  _itemThumb(item, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item["name"]} x${item["quantity"]}',
                      style: const TextStyle(fontSize: 14, color: _ink),
                    ),
                  ),
                ],
              )),

              const SizedBox(height: 16),
              Text(
                'Paid: €${_totalAmount().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

}
