import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'chat_thread_page.dart';

/// Theme constants (same as OrdersPage)
const _kInk = Color(0xFF0E1A36);
const _kCardBg = Color(0xFFF7F9FC);

class AdminOrderHistoryPage extends StatefulWidget {
  const AdminOrderHistoryPage({super.key});

  @override
  State<AdminOrderHistoryPage> createState() => _AdminOrderHistoryPageState();
}

class _AdminOrderHistoryPageState extends State<AdminOrderHistoryPage> {
  /// Sort options
// e.g. 'date_desc', 'cost_asc' etc.
  String _sortMode = 'date_desc';
  static const List<String> _historyStatuses = [
    'delivered',
    'completed',
    'rejected',
    'cancelled',
  ];

  @override
  Widget build(BuildContext context) {
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // header row inside body (no AppBar/back arrow)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Admin • Order History',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _kInk,
                      fontSize: 18,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _sortMode,
                  onSelected: (v) => setState(() => _sortMode = v),
                  icon: const Icon(Icons.sort, color: _kInk),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'date_desc',
                      child: Text("Date • Newest first"),
                    ),
                    PopupMenuItem(
                      value: 'date_asc',
                      child: Text("Date • Oldest first"),
                    ),
                    PopupMenuItem(
                      value: 'cost_desc',
                      child: Text("Cost • High → Low"),
                    ),
                    PopupMenuItem(
                      value: 'cost_asc',
                      child: Text("Cost • Low → High"),
                    ),
                    PopupMenuItem(
                      value: 'cycles_desc',
                      child: Text("Cycles • High → Low"),
                    ),
                    PopupMenuItem(
                      value: 'cycles_asc',
                      child: Text("Cycles • Low → High"),
                    ),
                    PopupMenuItem(
                      value: 'value_desc',
                      child: Text("Value • High → Low"),
                    ),
                    PopupMenuItem(
                      value: 'value_asc',
                      child: Text("Value • Low → High"),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // list
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ordersRef
                  .where('status', whereIn: _historyStatuses)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text("Error: ${snap.error}"));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snap.data!.docs.toList();

                // ------------ SORTING -----------------

                docs.sort((a, b) {
                  final A = a.data();
                  final B = b.data();

                  DateTime toDT(dynamic v) {
                    if (v is Timestamp) return v.toDate();
                    if (v is int) {
                      return DateTime.fromMillisecondsSinceEpoch(v);
                    }
                    if (v is String) {
                      return DateTime.tryParse(v) ?? DateTime(0);
                    }
                    return DateTime(0);
                  }

                  double toDouble(dynamic v) {
                    if (v is num) return v.toDouble();
                    return double.tryParse(v.toString()) ?? 0.0;
                  }

                  double totalOf(Map<String, dynamic> m) {
                    final direct = m['total'] ??
                        m['grandTotal'] ??
                        m['totalInclVat'] ??
                        m['total_incl_vat'] ??
                        m['amount'];

                    if (direct is num) return direct.toDouble();
                    if (direct != null) {
                      return double.tryParse(direct.toString()) ?? 0.0;
                    }
                    return 0.0;
                  }

                  double subtotalOf(Map<String, dynamic> m) {
                    final List items =
                    (m['items'] ?? m['wooLineItems'] ?? []) as List;
                    double s = 0;
                    for (final it in items) {
                      if (it is! Map) continue;
                      final qty = (it['quantity'] ?? 1) as num;
                      final price = it['price'] is num
                          ? (it['price'] as num).toDouble()
                          : double.tryParse('${it['price']}') ??
                          (double.tryParse('${it['total']}') ?? 0.0) /
                              (qty == 0 ? 1 : qty);
                      s += price * qty;
                    }
                    return s;
                  }

                  final parts = _sortMode.split('_'); // e.g. ['date','desc']
                  final key = parts[0];
                  final asc = parts.length > 1 && parts[1] == 'asc';

                  int cmp; // positive: a>b

                  if (key == 'date') {
                    final dA = toDT(A['updatedAt'] ?? A['timestamp']);
                    final dB = toDT(B['updatedAt'] ?? B['timestamp']);
                    cmp = dA.compareTo(dB);
                  } else if (key == 'cost') {
                    final cA = totalOf(A);
                    final cB = totalOf(B);
                    cmp = cA.compareTo(cB);
                  }
                  else if (key == 'cycles') {
                    final cycA = toDouble(A['cycle_number'] ?? 0);
                    final cycB = toDouble(B['cycle_number'] ?? 0);

                    final pA = (A['parentId'] ?? A['parent_subscription_id'] ?? A['parentSubscriptionId'] ?? a.id).toString();
                    final pB = (B['parentId'] ?? B['parent_subscription_id'] ?? B['parentSubscriptionId'] ?? b.id).toString();

                    // First group by parent
                    if (pA != pB) return asc ? pA.compareTo(pB) : pB.compareTo(pA);

                    // Then compare cycles within that parent
                    cmp = cycA.compareTo(cycB);
                  } else {
                    // value
                    final vA =
                    toDouble(A['subtotal'] ?? A['itemsValue'] ?? 0.0);
                    final vB =
                    toDouble(B['subtotal'] ?? B['itemsValue'] ?? 0.0);
                    final valA =
                    vA > 0 ? vA : subtotalOf(A); // fallback from items
                    final valB = vB > 0 ? vB : subtotalOf(B);
                    cmp = valA.compareTo(valB);
                  }

                  return asc ? cmp : -cmp;
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No order history",
                      style: TextStyle(
                          color: _kInk, fontWeight: FontWeight.w600),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _AdminOrderCard(
                    orderId: docs[i].id,
                    data: docs[i].data(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


}

////////////////////////////////////////////////////////////////
/// ADMIN ORDER CARD (matches OrdersPage UI)
////////////////////////////////////////////////////////////////

class _AdminOrderCard extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> data;

  const _AdminOrderCard({
    required this.orderId,
    required this.data,
  });

  String _fmt(dynamic v) {
    if (v is Timestamp) return DateFormat('dd/MM').format(v.toDate());
    if (v is int) {
      return DateFormat('dd/MM')
          .format(DateTime.fromMillisecondsSinceEpoch(v));
    }
    if (v is String) {
      final d = DateTime.tryParse(v);
      if (d != null) return DateFormat('dd/MM').format(d);
    }
    return '—';
  }

  List<Map<String, dynamic>> _previewItems() {
    final woo = (data['wooLineItems'] as List?)
        ?.whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    if (woo != null && woo.isNotEmpty) return woo;
    final items = (data['items'] as List?)
        ?.whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    return items ?? <Map<String, dynamic>>[];
  }

  double _totalAmount() {
    final v = data['total'] ??
        data['grandTotal'] ??
        data['totalInclVat'] ??
        data['total_incl_vat'] ??
        data['amount'];
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'delivered':
      case 'completed':
        return Colors.green.shade200;
      case 'cancelled':
      case 'rejected':
        return Colors.red.shade200;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _previewItems();
    final status = (data['status'] ?? '').toString();
    final cycleNumber = data['cycle_number'] ?? 1;
    final parentId = (data['parentId'] ?? data['parent_subscription_id'] ?? data['parentSubscriptionId'] ?? orderId).toString();
    final parentShort = parentId.substring(0, 8);
    final updated = _fmt(data['updatedAt'] ?? data['timestamp']);

    return InkWell(
      onTap: () => _openReceipt(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.receipt_long, color: _kInk),
            ),

            const SizedBox(width: 14),

            // Middle column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Order #$orderId",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    updated,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),

                  if (data['isSubscription'] == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      "Cycle $cycleNumber • Parent $parentShort",
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _kInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 4),
                  if (items.isNotEmpty)
                    Text(
                      "${items[0]['name']} x${items[0]['quantity']}",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _kInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Right column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _kInk,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "€${_totalAmount().toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: _kInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  ///////////////////////////////////////////////////////////
  /// RECEIPT SHEET (same style as your OrdersPage)
  ///////////////////////////////////////////////////////////

  void _openReceipt(BuildContext context) {
    final List<Map<String, dynamic>> items =
    (data['items'] ?? data['wooLineItems'] ?? [])
        .cast<Map<dynamic, dynamic>>()
        .map((e) => e.cast<String, dynamic>())
        .toList();

    final dateStr = _fmt(data['updatedAt'] ?? data['timestamp']);
    final status = (data['status'] ?? '').toString().toUpperCase();
    final total = _totalAmount();

    final cycleNumber = data['cycle_number'] ?? 1;
    final parentId = (data['parentId'] ?? data['parent_subscription_id'] ?? data['parentSubscriptionId'] ?? orderId).toString();
    final parentShort = parentId.substring(0, 8);

    final createdAt = data['createdAt'];
    final completedAt = data['deliveredAt'] ?? data['updatedAt'];


    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.80,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (_, controller) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Text(
                  "Order Receipt",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "#$orderId • $dateStr",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                // Subscription info block
                if (data['isSubscription'] == true) ...[
                  Text(
                    "Cycle $cycleNumber • Parent $parentShort",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

              // Start + Completed timestamps
                if (createdAt != null) Text(
                  "Started: ${_fmt(createdAt)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (completedAt != null) Text(
                  "Completed: ${_fmt(completedAt)}",
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),


                // summary row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _kInk,
                        ),
                      ),
                    ),
                    Text(
                      "€${total.toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),

                const SizedBox(height: 8),
                const Text(
                  "Items",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 4),

                Expanded(
                  child: ListView.builder(
                    controller: controller,
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final it = items[i];
                      final qty = (it['quantity'] ?? 1) as num;
                      final price = (it['price'] ?? 0).toString();
                      final total = (it['total'] ?? 0).toString();
                      final imageUrl =
                      (it['imageUrl'] ?? it['image'] ?? '') as String?;

                      Widget leading;
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        leading = ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        );
                      } else {
                        leading = const Icon(
                          Icons.local_mall_outlined,
                          color: _kInk,
                          size: 28,
                        );
                      }

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: leading,
                        title: Text(
                          it['name'] ?? "Item",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kInk,
                          ),
                        ),

                        subtitle: Text(
                          "€$price  x$qty",
                          style: const TextStyle(color: _kInk),
                        ),
                        trailing: Text(
                          "€$total",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _kInk,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

}
