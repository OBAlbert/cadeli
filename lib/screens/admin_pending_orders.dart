import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart'; // call Firebase Cloud Functions
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';


/// Admin view for orders awaiting approval.
/// Accept -> capture payment (server), set status=active.
/// Reject -> void payment (server), set status=rejected.
class PendingOrdersPage extends StatefulWidget {
  const PendingOrdersPage({super.key});

  @override
  State<PendingOrdersPage> createState() => _PendingOrdersPageState();
}

class _PendingOrdersPageState extends State<PendingOrdersPage> {
  late GoogleMapController _mapController;
  final LatLng _shopLocation = const LatLng(34.918713218314764, 33.60916689025297);

  List<Map<String, dynamic>> _orders = [];
  String _sortBy = 'distance';
  bool _busy = false; // lock UI while capture/void runs

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
    if (km >= 9000) return '—'; // sentinel for "missing coords"
    if (km <= 0) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }



  @override
  void initState() {
    super.initState();

    FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')   // <-- our target
        .orderBy('createdAt', descending: true)        // consistent ordering
        .limit(25)
        .snapshots()
        .listen((snapshot) async {
      debugPrint('🔥 Pending docs: ${snapshot.docs.length}');
      if (snapshot.docs.isNotEmpty) {
        final d0 = snapshot.docs.first.data();
        debugPrint('🔥 First doc keys: ${d0.keys.toList()}');
        debugPrint('🔥 First doc status: ${d0['status']}  createdAt: ${d0['createdAt']}');
      }

      final built = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};

        // ✅ true customer name from users/{uid}.fullName
        final userId = (data['userId'] ?? '').toString();
        final fullName = await _getFullNameFor(userId);

        // Display address (your fields)
        final line1 = (addr['address_1'] ?? '').toString().trim();
        final city  = (addr['city'] ?? '').toString().trim();
        // your sample sometimes had address text in last_name
        final lastMaybeAddress = (addr['last_name'] ?? '').toString().trim();
        String addressLine = ([line1, city]..removeWhere((s) => s.isEmpty)).join(', ');
        if (addressLine.isEmpty && lastMaybeAddress.isNotEmpty) addressLine = lastMaybeAddress;
        if (addressLine.isEmpty) addressLine = 'Larnaca, Cyprus';

        final phone = (addr['phone'] ?? '').toString().trim();

        // coords (no geocoding; if missing -> large distance so sorts last)
        final lat = (addr['lat'] as num?)?.toDouble();
        final lng = (addr['lng'] as num?)?.toDouble();
        final hasLL = lat != null && lng != null;
        final distanceKm = hasLL
            ? Geolocator.distanceBetween(_shopLocation.latitude, _shopLocation.longitude, lat!, lng!) / 1000.0
            : 9999.0;

        // meta
        final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
        final deliveryType = (meta['delivery_type'] ?? 'normal').toString();
        final timeSlot     = (meta['time_slot'] ?? '').toString();

        final preferredDay = (meta['preferred_day'] ?? '').toString();
        final frequency    = (meta['frequency'] ?? '').toString();

        // totals (your total is a string sometimes)
        num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
        final total = _num(data['total']);
        final createdAt = (data['createdAt'] ?? data['timestamp']);
        final paymentStatus = (data['paymentStatus'] ?? 'unpaid').toString();
        final wooLineItems =
            (data['wooLineItems'] as List?) ??
                (data['items'] as List?) ??
                const [];
        final currency = (data['currency'] ?? '').toString();
        final paymentMethod = (data['paymentMethod'] ?? 'card').toString(); // 'card' | 'cod'


        built.add({
          'id'            : doc.id,
          'userId'        : userId,
          'wooOrderId'    : (data['wooOrderId'] ?? 0) as int,
          'customerName'  : fullName.isNotEmpty ? fullName : userId, // ✅ use real name
          'address'       : addressLine,
          'phone'         : phone,
          'timeSlot'      : timeSlot.isEmpty ? 'No time selected' : timeSlot,
          'subscription'  : deliveryType == 'subscription',          // bool for internal use
          'distance'      : distanceKm,
          'timestamp'     : createdAt,
          'lat'           : lat,
          'lng'           : lng,
          'total'         : total,
          'paymentStatus' : paymentStatus,
          'items'        : wooLineItems,
          'currency'     : currency,
          'paymentMethod': paymentMethod,
          'preferredDay' : preferredDay,
          'frequency'    : frequency,
        });
      }

      if (mounted) setState(() => _orders = _sortOrders(built));
    },
        onError: (e) {
      debugPrint('🔥 orders stream error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Can’t load pending orders: $e')),
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

  // --- Admin actions ---

  Future<void> _acceptOrder(Map<String, dynamic> order) async {
    if (_busy) return;
    setState(() => _busy = true);

    final int wooOrderId = order['wooOrderId'] ?? 0;
    final String docId = order['id'];

    try {
      await FirebaseFunctions.instance
          .httpsCallable('adminAcceptOrder')
          .call({'orderId': wooOrderId, 'docId': docId});

      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
        'timeline': FieldValue.arrayUnion([
          {
            'at': DateTime.now().toUtc().toIso8601String(),
            'type': 'admin_accepted',
            'note': 'Order accepted by admin (Stripe capture handled server-side if card).'
          }
        ]),
      });

      final userId = (order['userId'] as String? ?? '');
      if (userId.isNotEmpty) {
        await ChatService.instance.ensureChat(
            orderId: docId, customerId: userId, adminId: FirebaseAuth.instance.currentUser!.uid, status: 'active');
        await ChatService.instance.sendSystem(docId, '✅ Your order has been accepted! We\'re preparing it now.');
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Accepted. If card, payment was captured.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to accept: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rejectOrder(Map<String, dynamic> order) async {
    if (_busy) return;
    setState(() => _busy = true);

    final int wooOrderId = order['wooOrderId'] ?? 0;
    final String docId = order['id'];

    try {
      await FirebaseFunctions.instance
          .httpsCallable('adminRejectOrder')
          .call({'orderId': wooOrderId, 'docId': docId});

      await FirebaseFirestore.instance.collection('orders').doc(docId).update({
        'status': 'rejected',
        'paymentStatus': 'voided',
        'timeline': FieldValue.arrayUnion([
          {
            'at': DateTime.now().toUtc().toIso8601String(),
            'type': 'admin_rejected',
            'note': 'Payment authorization voided, order rejected'
          }
        ]),
      });

      final userId = (order['userId'] as String? ?? '');
      if (userId.isNotEmpty) {
        await ChatService.instance.ensureChat(
            orderId: docId, customerId: userId, adminId: FirebaseAuth.instance.currentUser!.uid, status: 'rejected');
        await ChatService.instance.sendSystem(docId, '❌ Your order was rejected. The payment authorization has been voided.');
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rejected: authorization voided'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reject: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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


  @override
  Widget build(BuildContext context) {
    final markers = _orders
        .where((o) => o['lat'] != null && o['lng'] != null)
        .map((o) => Marker(
      markerId: MarkerId(o['id']),
      position: LatLng(o['lat'] as double, o['lng'] as double),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
      onTap: () => _showOrderDialog(o),
    ))
        .toSet();

    return Scaffold(
      body: Column(
        children: [
          // Map
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

          // Sort header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Pending Orders",
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

          // List
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy, // lock while server call in-flight
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                itemCount: _orders.length,
                itemBuilder: (_, i) {
                  final order = _orders[i];
                  return GestureDetector(
                    onTap: () => _showOrderDialog(order),
                    child: Opacity(
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
                            // LEFT: details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // name + distance
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

                                  // address
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

                                  // chips row: payment, status, total, subscription + time slot
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _chip((order['paymentMethod'] == 'cod') ? 'COD' : 'Card'),
                                      _chip('Status: ${order['paymentStatus'] ?? 'unpaid'}'),
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
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // RIGHT: vertical actions
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _circleBtn(icon: Icons.check, color: Colors.green, onTap: () => _acceptOrder(order)),
                                const SizedBox(height: 8),
                                _circleBtn(icon: Icons.chat_bubble_outline, color: Colors.blueGrey, onTap: () => _showOrderDialog(order)),
                                const SizedBox(height: 8),
                                _circleBtn(icon: Icons.close, color: Colors.red, onTap: () => _rejectOrder(order)),
                              ],
                            ),
                          ],
                        ),
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

  void _showOrderDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (_) {
        // Get items once (outside of the widget list!)
        final List items =
            (order['items'] as List?) ??
                (order['wooLineItems'] as List?) ??
                const [];

        return AlertDialog(
          backgroundColor: const Color(0xFF1F2937),
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Colors.amber),
              const SizedBox(width: 8),
              Text(
                'Order #${order['id'].toString().substring(0, 8)}',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Customer info card ---
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
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        (order['customerName'] ?? 'No Name').toString(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (order['address'] ?? '-').toString(),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // --- Order details card ---
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
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                      const SizedBox(height: 12),

                      if (order['timestamp'] is Timestamp)
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Ordered: ${DateFormat('MMM d, h:mm a').format(
                                  (order['timestamp'] as Timestamp).toDate())}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.social_distance,
                              color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Distance: ${_formatDistance(
                                order['distance'] as double)} from shop",
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),

                      // --- Items (if present) ---
                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 6),
                        const Text(
                          'Items',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),

                        ...items.map<Widget>((it) {
                          // Defensive reads for dynamic structures
                          final name = (it is Map && it['name'] != null)
                              ? it['name'].toString()
                              : 'Item';
                          final qty = (it is Map && it['quantity'] != null)
                              ? it['quantity'].toString()
                              : '1';
                          final lineTotal = (it is Map && it['total'] != null)
                              ? it['total'].toString()
                              : '';

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '$name  x$qty',
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                    const TextStyle(color: Colors.white70),
                                  ),
                                ),
                                Text(
                                  lineTotal.isEmpty
                                      ? ''
                                      : '${order['currency'] ?? ''} $lineTotal',
                                  style:
                                  const TextStyle(color: Colors.white70),
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
              child:
              const Text("Close", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _rejectOrder(order);
              },
              icon: const Icon(Icons.cancel, color: Colors.white),
              label:
              const Text('Reject', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _acceptOrder(order);
              },
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label:
              const Text('Accept', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        );
      },
    );
  }
}
