import 'package:cadeli/screens/pick_truck_location_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart'; // call Firebase Cloud Functions
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/map_icon_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widget/truck_dropdown.dart';
import 'pick_truck_location_page.dart';




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
  final LatLng _defaultTruckLocation = const LatLng(34.918713218314764, 33.60916689025297);

  // ==== NEW TRUCK LOCATION FIELDS ====
  LatLng? _truckLocation;
  Timestamp? _truckUpdatedAt;

  BitmapDescriptor? _truckMarkerIcon;


  Future<void> _loadTruckLocation() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('truckLocation')
          .get();

      final data = snap.data();
      if (data == null) return;

      final lat = (data['lat'] as num?)?.toDouble();
      final lng = (data['lng'] as num?)?.toDouble();

      if (lat != null && lng != null) {
        setState(() {
          _truckLocation = LatLng(lat, lng);
          _truckUpdatedAt = data['updatedAt'] as Timestamp?;
        });
      }
    } catch (e) {
      debugPrint("Truck location error → $e");
    }
  }


  List<Map<String, dynamic>> _orders = [];
  String _sortBy = 'distance_asc';
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
    _loadTruckLocation();

    // Preload custom truck icon so we can show it on the map
    MapIconService.loadTruckIcon().then((_) {
      if (!mounted) return;
      setState(() {
        _truckMarkerIcon = MapIconService.truckIcon;
      });
    });

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

        // Address block
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};

        final userId = (data['userId'] ?? '').toString();
        final fullName = await _getFullNameFor(userId);

        // Fixing address display
        final line1 = (addr['address_1'] ?? '').toString().trim();
        final city  = (addr['city'] ?? '').toString().trim();
        final lastMaybeAddress = (addr['last_name'] ?? '').toString().trim();

        String addressLine = ([line1, city]..removeWhere((s) => s.isEmpty)).join(', ');
        if (addressLine.isEmpty && lastMaybeAddress.isNotEmpty) addressLine = lastMaybeAddress;
        if (addressLine.isEmpty) addressLine = 'Larnaca, Cyprus';

        final phone = (addr['phone'] ?? '').toString().trim();

        // Coordinates
        final lat = (addr['lat'] as num?)?.toDouble();
        final lng = (addr['lng'] as num?)?.toDouble();
        final hasLL = lat != null && lng != null;

        final origin = _truckLocation ?? _defaultTruckLocation;
        final distanceKm = hasLL
            ? Geolocator.distanceBetween(
            origin.latitude, origin.longitude, lat!, lng!)
            / 1000.0
            : 9999.0;

        // Meta
        final meta = (data['meta'] as Map<String, dynamic>?) ?? {};
        final deliveryType = (meta['delivery_type'] ?? 'normal').toString();
        final timeSlot     = (meta['time_slot'] ?? '').toString();

        final frequency    = (meta['frequency'] ?? '').toString();

        // Totals (string → num safe)
        num _num(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
        final total = _num(data['total']);

        final createdAt      = (data['createdAt'] ?? data['timestamp']);
        final paymentStatus  = (data['paymentStatus'] ?? 'unpaid').toString();

        // Items list
        final wooLineItems =
            (data['wooLineItems'] as List?) ??
                (data['items'] as List?) ??
                const [];

        final currency       = (data['currency'] ?? '').toString();
        final paymentMethod  = (data['paymentMethod'] ?? 'card').toString();

        built.add({
          'id'            : doc.id,
          'userId'        : userId,
          'wooOrderId'    : (data['wooOrderId'] ?? 0) as int,
          'customerName'  : fullName.isNotEmpty ? fullName : userId,
          'address'       : addressLine,
          'phone'         : phone,
          'timeSlot'      : timeSlot.isEmpty ? 'No time selected' : timeSlot,
          'subscription'  : deliveryType == 'subscription',
          'distance'      : distanceKm,
          'timestamp'     : createdAt,
          'lat'           : lat,
          'lng'           : lng,
          'total'         : total,
          'paymentStatus' : paymentStatus,
          'items'         : wooLineItems,
          'currency'      : currency,
          'paymentMethod' : paymentMethod,
          'frequency'     : frequency,
          'cycle_number'  : data['cycle_number'] ?? 1,
          'parentId'      : (data['parentId'] ?? '').toString(),
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

    MapIconService.loadTruckIcon().then((_) {
      setState(() {
        _truckMarkerIcon = MapIconService.truckIcon;
      });
    });

  }

  void _recalculateDistances() {
    final origin = _truckLocation ?? _defaultTruckLocation;

    final updated = _orders.map<Map<String, dynamic>>((o) {
      final lat = o['lat'] as double?;
      final lng = o['lng'] as double?;
      double distanceKm;

      if (lat != null && lng != null) {
        distanceKm = Geolocator.distanceBetween(
            origin.latitude, origin.longitude, lat, lng) /
            1000.0;
      } else {
        distanceKm = 9999.0;
      }

      return {
        ...o,
        'distance': distanceKm,
      };
    }).toList();

    setState(() {
      _orders = _sortOrders(updated);
    });
  }


  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    // NEW SORT LOGIC
    if (_sortBy == 'distance_asc') {
      orders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    } else if (_sortBy == 'distance_desc') {
      orders.sort((a, b) => (b['distance'] as double).compareTo(a['distance'] as double));
    } else if (_sortBy == 'time_desc') {
      orders.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        return 0;
      });
    } else if (_sortBy == 'time_asc') {
      orders.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta is Timestamp && tb is Timestamp) return ta.compareTo(tb);
        return 0;
      });
    }
    else {
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
        // Cloud Function already set status/paymentStatus/updatedAt
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

  void _showTruckSheet(BuildContext context) {
    if (_truckLocation == null) return;

    final updated = _truckUpdatedAt?.toDate();
    final updatedStr = updated != null
        ? DateFormat('MMM d, h:mm a').format(updated)
        : 'Unknown';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_shipping, color: Colors.black87, size: 26),
                  SizedBox(width: 10),
                  Text("Truck Location",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 10),
              Text("Last updated: $updatedStr",
                  style: const TextStyle(
                      color: Colors.black54, fontSize: 14)),
              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () async {
                  final lat = _truckLocation!.latitude;
                  final lng = _truckLocation!.longitude;
                  final url = Uri.parse(
                      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving");
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.navigation),
                label: const Text("Navigate to Truck"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }




  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    final initialTarget = _truckLocation ?? _defaultTruckLocation;

    // --- Truck marker ---
    if (_truckLocation != null && _truckMarkerIcon != null) {
      markers.add(
        Marker(
          markerId: const MarkerId("truck"),
          position: _truckLocation!,
          icon: _truckMarkerIcon!,
          infoWindow: const InfoWindow(title: "Truck Location"),
        ),
      );
    }

    // --- Order markers ---
    for (final o in _orders) {
      final lat = o['lat'] as double?;
      final lng = o['lng'] as double?;
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId(o['id'] as String),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow),
            onTap: () => _showOrderDialog(o),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false, // 🔹 no extra back arrow under tabs
        titleSpacing: 16,
        title:  Row(
          children: [
            Expanded(
              child: Text(
                "Pending Orders",
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF0E1A36),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 8),
            // 🔹 Truck dropdown is flexible so the row never overflows
            Flexible(
              child: GestureDetector(
                onTap: () async {
                  final updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PickTruckLocationPage(),
                    ),
                  );

                  if (updated == true) {
                    await _loadTruckLocation();
                    _recalculateDistances();

                    if (_truckLocation != null && mounted) {
                      _mapController.animateCamera(
                        CameraUpdate.newLatLng(_truckLocation!),
                      );
                    }
                  }
                },
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 160,     // prevents overflow
                    child: TruckDropdown(),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh truck & distances',
            icon: const Icon(Icons.my_location, color: Color(0xFF0E1A36)),
            onPressed: () async {
              await _loadTruckLocation();
              _recalculateDistances();
            },
          ),
          IconButton(
            tooltip: 'Truck details',
            icon: const Icon(Icons.local_shipping_outlined, color: Color(0xFF0E1A36)),
            onPressed: () => _showTruckSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Map card ---
          Container(
            height: MediaQuery.of(context).size.height * 0.42, // a bit smaller, safer
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                key: ValueKey('${initialTarget.latitude}_${initialTarget.longitude}'),
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition: CameraPosition(
                  target: initialTarget,
                  zoom: 14,
                ),
                zoomControlsEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
                markers: markers,
              ),
            ),
          ),

          // --- Sort header ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pending Orders",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.black87),
                      dropdownColor: Colors.white,
                      style: const TextStyle(color: Colors.black87, fontSize: 13),
                      items: const [
                        DropdownMenuItem(
                          value: 'distance_asc',
                          child: Text('Distance • Nearest'),
                        ),
                        DropdownMenuItem(
                          value: 'distance_desc',
                          child: Text('Distance • Farthest'),
                        ),
                        DropdownMenuItem(
                          value: 'time_desc',
                          child: Text('Time • Newest'),
                        ),
                        DropdownMenuItem(
                          value: 'time_asc',
                          child: Text('Time • Oldest'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() {
                          _sortBy = val;
                          _orders = _sortOrders([..._orders]);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),

          ),

          const SizedBox(height: 4),

          // --- Orders list ---
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
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
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // LEFT
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          (order['customerName'] ?? '') as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _formatDistance(order['distance'] as double),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_pin,
                                          color: Colors.red, size: 18),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          (order['address'] ?? 'No address') as String,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      _chip(order['paymentMethod'] == 'cod' ? 'COD' : 'Card'),
                                      _chip('Payment: ${order['paymentStatus'] ?? 'unpaid'}'),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          order['paymentStatus']?.toUpperCase() ?? 'UNPAID',
                                          style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),

                                      if ((order['total'] as num) > 0)
                                        _chip('Total: ${order['total']} ${order['currency'] ?? ''}'),
                                      _chip((order['subscription'] as bool)
                                          ? 'Subscription'
                                          : 'One-off'),
                                      if (order['subscription'] == true) ...[
                                        if (order['cycle_number'] != null)
                                          _chip('Cycle: ${order['cycle_number']}'),

                                        if (order['parentId'] != null &&
                                            (order['parentId'] as String).trim().isNotEmpty)
                                          _chip('Parent #${(order['parentId'] as String).substring(0, 6)}'),
                                      ],

                                      if ((order['subscription'] as bool) &&
                                          (order['timeSlot'] as String).isNotEmpty)
                                        _chip('Slot: ${order['timeSlot']}'),
                                      if ((order['subscription'] as bool) &&
                                          (order['frequency'] as String).isNotEmpty)
                                        _chip('Every: ${order['frequency']}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 12),

                            // RIGHT
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _circleBtn(
                                  icon: Icons.check,
                                  color: Colors.green,
                                  onTap: () => _acceptOrder(order),
                                ),
                                const SizedBox(height: 8),
                                _circleBtn(
                                  icon: Icons.chat_bubble_outline,
                                  color: Colors.blueGrey,
                                  onTap: () => _showOrderDialog(order),
                                ),
                                const SizedBox(height: 8),
                                _circleBtn(
                                  icon: Icons.close,
                                  color: Colors.red,
                                  onTap: () => _rejectOrder(order),
                                ),
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
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF0E1A36)),
              const SizedBox(width: 8),
              Text(
                'Order #${order['id'].toString().substring(0, 8)}',
                style: const TextStyle(color: Color(0xFF0E1A36), fontSize: 18, fontWeight: FontWeight.w700),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.person, color: Color(0xFF0E1A36), size: 20),
                        SizedBox(width: 8),
                        Text('Customer Information',
                            style: TextStyle(
                              color: Color(0xFF0E1A36),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                      const SizedBox(height: 12),
                      Text(
                        (order['customerName'] ?? 'No Name').toString(),
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.black45),
                          SizedBox(width: 6),
                          Text(
                            (order['phone'] ?? '-').toString(),
                            style: TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.black45, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              (order['address'] ?? '-').toString(),
                              style: const TextStyle(color: Colors.black87),
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(Icons.info_outline, color: Color(0xFF0E1A36), size: 20),
                        SizedBox(width: 8),
                        Text('Order Details',
                            style: TextStyle(
                              color: Color(0xFF0E1A36),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                      const SizedBox(height: 12),

                      if (order['timestamp'] is Timestamp)
                        Row(
                          children: [
                            const Icon(Icons.access_time,
                                color: Colors.black45, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              "Ordered: ${DateFormat('MMM d, h:mm a').format(
                                  (order['timestamp'] as Timestamp).toDate())}",
                              style: const TextStyle(color: Colors.black45),
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
                            "Distance: ${_formatDistance(order['distance'] as double)} from truck",
                            style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (order['subscription'] == true) ...[
                        Row(
                          children: [
                            const Icon(Icons.repeat, color: Colors.blue, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Subscription • Cycle ${order['cycle_number']}',
                              style: const TextStyle(color: Colors.blue),
                            ),
                          ],
                        ),
                        if (order['parentId'] != null &&
                            order['parentId'].toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 22, top: 4),
                            child: Text(
                              'Parent ID: ${order['parentId'].toString().substring(0, 8)}',
                              style: const TextStyle(color: Colors.white60, fontSize: 12),
                            ),
                          ),
                      ],


                      // --- Items (if present) ---

                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 6),
                        const Text(
                          'Items',
                          style: TextStyle(
                              color: Color(0xFF0E1A36),
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                        const SizedBox(height: 8),

                        ...items.map<Widget>((it) {
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
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (it['imageUrl'] != null &&
                                    it['imageUrl'].toString().startsWith('http'))
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      it['imageUrl'],
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                else
                                  const Icon(Icons.local_mall_outlined,
                                      size: 32, color: Colors.black45),

                                const SizedBox(width: 8),

                                Expanded(
                                  child: Text(
                                    '$name  x$qty',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),

                                Text(
                                  lineTotal.isEmpty
                                      ? ''
                                      : '${order['currency'] ?? ''} $lineTotal',
                                  style: const TextStyle(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],

                      // --- Total ---
                      const SizedBox(height: 14),
                      Divider(color: Colors.grey.shade300),
                      const SizedBox(height: 10),
                      const Text(
                        'Total',
                        style: TextStyle(
                          color: Color(0xFF0E1A36),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${order['currency'] ?? ''} ${order['total'] ?? ''}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

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
              const Text("Close", style: TextStyle(color: Colors.black87)),
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
