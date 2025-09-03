import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

// NEW: for chat
import '../services/chat_service.dart';        // <-- adjust path if needed
import 'chat_thread_page.dart';               // <-- adjust path if needed

class ActiveOrdersPage extends StatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  State<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends State<ActiveOrdersPage> {
  late GoogleMapController _mapController;
  final LatLng _shopLocation = const LatLng(34.918713218314764, 33.60916689025297);

  List<Map<String, dynamic>> _orders = [];
  String _sortBy = 'distance';
  bool _busy = false;

  final Map<String, String> _userNameCache = {};

  Future<String> _getFullNameFor(String? uid) async {
    if (uid == null || uid.isEmpty) return '';
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final fullName = (snap.data()?['fullName'] ?? '').toString().trim();
      _userNameCache[uid] = fullName;
      return fullName;
    } catch (_) {
      _userNameCache[uid] = '';
      return '';
    }
  }

  String _formatDistance(double km) {
    if (km >= 9000) return '—';
    if (km <= 0) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      final built = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // user
        final userId = (data['userId'] ?? '').toString();
        final fullName = await _getFullNameFor(userId);

        // address (same logic as Pending)
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};
        final line1 = (addr['address_1'] ?? '').toString().trim();
        final city  = (addr['city'] ?? '').toString().trim();
        final lastMaybeAddress = (addr['last_name'] ?? '').toString().trim();
        String addressLine = ([line1, city]..removeWhere((s) => s.isEmpty)).join(', ');
        if (addressLine.isEmpty && lastMaybeAddress.isNotEmpty) addressLine = lastMaybeAddress;
        if (addressLine.isEmpty) addressLine = 'Larnaca, Cyprus';

        final phone = (addr['phone'] ?? '').toString().trim();

        // coords → distance
        final lat = (addr['lat'] as num?)?.toDouble();
        final lng = (addr['lng'] as num?)?.toDouble();
        final hasLL = lat != null && lng != null;
        final distanceKm = hasLL
            ? Geolocator.distanceBetween(_shopLocation.latitude, _shopLocation.longitude, lat!, lng!) / 1000.0
            : 9999.0;

        // meta (for subscription chips)
        final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
        final deliveryType = (meta['delivery_type'] ?? 'normal').toString();
        final timeSlot     = (meta['time_slot'] ?? '').toString();
        final preferredDay = (meta['preferred_day'] ?? '').toString();
        final frequency    = (meta['frequency'] ?? '').toString();

        num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
        final total          = _num(data['total']);
        final createdAt      = (data['createdAt'] ?? data['timestamp']);
        final paymentStatus  = (data['paymentStatus'] ?? 'unpaid').toString();
        final currency       = (data['currency'] ?? '').toString();
        final paymentMethod  = (data['paymentMethod'] ?? 'card').toString();
        final items          = (data['wooLineItems'] as List?) ?? (data['items'] as List?) ?? const [];

        built.add({
          'id'            : doc.id,
          'userId'        : userId,
          'customerName'  : fullName.isNotEmpty ? fullName : userId,
          'address'       : addressLine,
          'phone'         : phone,
          'distance'      : distanceKm,
          'timestamp'     : createdAt,
          'lat'           : lat,
          'lng'           : lng,
          'total'         : total,
          'paymentStatus' : paymentStatus,
          'items'         : items,
          'currency'      : currency,
          'paymentMethod' : paymentMethod,
          'subscription'  : deliveryType == 'subscription',
          'timeSlot'      : timeSlot.isEmpty ? 'No time selected' : timeSlot,
          'preferredDay'  : preferredDay,
          'frequency'     : frequency,
        });
      }

      if (mounted) setState(() => _orders = _sortOrders(built));
    },
        onError: (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Can’t load active orders: $e')),
            );
          }
        });
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    if (_sortBy == 'distance') {
      orders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    } else {
      orders.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });
    }
    return orders;
  }

  Future<void> _updateStatus(String orderId, String status) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'at': DateTime.now().toUtc().toIso8601String(),
            'type': 'status_update',
            'note': status,
          }
        ]),
      });

      // optional: system note in chat
      await FirebaseFirestore.instance
          .collection('chats').doc(orderId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': 'Status updated to ${_statusLabel(status)}.',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status → ${_statusLabel(status)}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'out_for_delivery': return 'Out for delivery';
      case 'delivered': return 'Delivered';
      default: return s;
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final markers = _orders
        .where((o) => o['lat'] != null && o['lng'] != null)
        .map((o) => Marker(
      markerId: MarkerId(o['id']),
      position: LatLng(o['lat'] as double, o['lng'] as double),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      onTap: () => _showOrderDialog(o),
    ))
        .toSet();

    return Scaffold(
      body: Column(
        children: [
          // MAP
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition: CameraPosition(target: _shopLocation, zoom: 13),
                zoomControlsEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
                markers: markers,
              ),
            ),
          ),

          // HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Active Orders",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'distance', child: Text("By Distance")),
                    DropdownMenuItem(value: 'time', child: Text("By Time")),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _sortBy = val;
                        _orders = _sortOrders([..._orders]);
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          // LIST
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _orders.length,
                itemBuilder: (_, i) {
                  final order = _orders[i];
                  return Opacity(
                    opacity: _busy ? 0.7 : 1,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT: details (same style as Pending)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        order['customerName'] ?? '',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
                                      ),
                                    ),
                                    Text(
                                      _formatDistance(order['distance'] as double),
                                      style: const TextStyle(fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                Row(children: [
                                  const Icon(Icons.location_pin, color: Colors.red, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      order['address'] ?? 'No address',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, color: Colors.black87),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 8),

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    _chip((order['paymentMethod'] == 'cod') ? 'COD' : 'Card'),
                                    _chip('Status: preparing'),
                                    if ((order['total'] as num) > 0)
                                      _chip('Total: ${order['total']} ${order['currency'] ?? ''}'),
                                    _chip((order['subscription'] as bool) ? 'Subscription' : 'One-off'),
                                    if ((order['subscription'] as bool) && (order['timeSlot'] as String).isNotEmpty)
                                      _chip('Slot: ${order['timeSlot']}'),
                                    if ((order['subscription'] as bool) && (order['preferredDay'] as String).isNotEmpty)
                                      _chip('Day: ${order['preferredDay']}'),
                                    if ((order['subscription'] as bool) && (order['frequency'] as String).isNotEmpty)
                                      _chip('Every: ${order['frequency']}'),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                // Quick status actions (optional)
                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _updateStatus(order['id'], 'out_for_delivery'),
                                      icon: const Icon(Icons.delivery_dining),
                                      label: const Text('Out for delivery'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _updateStatus(order['id'], 'delivered'),
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: const Text('Delivered'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // RIGHT: actions (Details + Chat)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _circleBtn(
                                icon: Icons.receipt_long,
                                color: Colors.indigo,
                                onTap: () => _showOrderDialog(order),
                              ),
                              const SizedBox(height: 8),
                              _circleBtn(
                                icon: Icons.chat_bubble_outline,
                                color: Colors.blueGrey,
                                onTap: () async {
                                  final orderId = order['id'] as String;
                                  final customerId = (order['userId'] ?? '').toString();
                                  if (customerId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Missing customerId for this order')),
                                    );
                                    return;
                                  }
                                  await ChatService.instance.ensureChat(
                                    orderId: orderId,
                                    customerId: customerId,
                                    adminId: 'ADMIN', // replace with your admin uid if you have one
                                    status: 'active',
                                  );
                                  if (!mounted) return;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatThreadPage(
                                        orderId: orderId,
                                        customerId: customerId,
                                        isAdminView: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.black87)),
  );

  Widget _circleBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(icon: Icon(icon, color: Colors.white), onPressed: onTap),
    );
  }

  void _showOrderDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (_) {
        final List items = (order['items'] as List?) ?? const [];

        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.amber),
              const SizedBox(width: 8),
              Text('Order #${(order['id'] as String).substring(0, 8)}',
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Customer card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: const [
                        Icon(Icons.person, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text('Customer Information',
                            style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 12),
                      Text((order['customerName'] ?? 'No Name').toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text((order['address'] ?? '-').toString(),
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Order details card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF374151),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Order Details',
                            style: TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 12),

                      if (order['timestamp'] is Timestamp)
                        Row(
                          children: [
                            const Icon(Icons.access_time, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Ordered: ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.social_distance, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Distance: ${_formatDistance(order['distance'] as double)} from shop",
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),

                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 6),
                        const Text('Items',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        ...items.map<Widget>((it) {
                          final name = (it is Map && it['name'] != null) ? it['name'].toString() : 'Item';
                          final qty  = (it is Map && it['quantity'] != null) ? it['quantity'].toString() : '1';
                          final lineTotal = (it is Map && it['total'] != null) ? it['total'].toString() : '';
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text('$name  x$qty',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white70)),
                                ),
                                Text(
                                  lineTotal.isEmpty ? '' : '${order['currency'] ?? ''} $lineTotal',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close", style: TextStyle(color: Colors.white70)),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(order['id'], 'out_for_delivery');
              },
              icon: const Icon(Icons.delivery_dining, color: Colors.white),
              label: const Text('Out for delivery', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(backgroundColor: Colors.indigo),
            ),
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _updateStatus(order['id'], 'delivered');
              },
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: const Text('Delivered', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        );
      },
    );
  }
}
