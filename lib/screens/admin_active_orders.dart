import 'package:cadeli/screens/pick_truck_location_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/map_icon_service.dart';
import '../services/chat_service.dart';
import 'chat_thread_page.dart';
import '../widget/truck_dropdown.dart';

class ActiveOrdersPage extends StatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  State<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends State<ActiveOrdersPage> {
  late GoogleMapController _mapController;

  // Default fallback (shop) if truck location not set yet
  final LatLng _defaultTruckLocation =
  const LatLng(34.918713218314764, 33.60916689025297);

  // ==== TRUCK LOCATION STATE ====
  LatLng? _truckLocation;
  Timestamp? _truckUpdatedAt;
  BitmapDescriptor? _truckMarkerIcon;

  // ==== ORDERS STATE ====
  List<Map<String, dynamic>> _orders = [];
  String _sortBy = 'distance_asc'; // distance_asc, distance_desc, time_desc, time_asc

  bool _busy = false;

  final Map<String, String> _userNameCache = {};

  Future<String> _getFullNameFor(String? uid) async {
    if (uid == null || uid.isEmpty) return '';
    if (_userNameCache.containsKey(uid)) return _userNameCache[uid]!;
    try {
      final snap =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final fullName = (snap.data()?['fullName'] ?? '').toString().trim();
      _userNameCache[uid] = fullName;
      return fullName;
    } catch (_) {
      _userNameCache[uid] = '';
      return '';
    }
  }

  String _formatDistance(double km) {
    if (km >= 9000) return '—'; // sentinel for missing coords
    if (km <= 0) return '—';
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }

  // ==== LOAD TRUCK LOCATION FROM FIRESTORE ====
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

        // Distances depend on truck location → recalc
        _recalculateDistances();
      }
    } catch (e) {
      debugPrint("Truck location error → $e");
    }
  }



  // Recalculate distance for all orders when truck moves
  void _recalculateDistances() {
    final origin = _truckLocation ?? _defaultTruckLocation;

    final updated = _orders.map<Map<String, dynamic>>((o) {
      final lat = o['lat'] as double?;
      final lng = o['lng'] as double?;
      double distanceKm;

      if (lat != null && lng != null) {
        distanceKm = Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          lat,
          lng,
        ) /
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
    orders.sort((a, b) {
      final da = (a['distance'] ?? 9999.0) as double;
      final db = (b['distance'] ?? 9999.0) as double;
      final ta = a['timestamp'];
      final tb = b['timestamp'];

      switch (_sortBy) {
        case 'distance_desc':
          return db.compareTo(da);        // farthest first
        case 'time_asc':
          if (ta is Timestamp && tb is Timestamp) {
            return ta.compareTo(tb);      // oldest first
          }
          return 0;
        case 'time_desc':
          if (ta is Timestamp && tb is Timestamp) {
            return tb.compareTo(ta);      // newest first
          }
          return 0;
        case 'distance_asc':
        default:
          return da.compareTo(db);        // nearest first
      }
    });
    return orders;
  }

  @override
  void initState() {
    super.initState();
    _loadTruckLocation();

    FirebaseFirestore.instance
        .collection('config')
        .doc('truckLocation')
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final d = snap.data()!;
      final lat = (d['lat'] as num?)?.toDouble();
      final lng = (d['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        setState(() {
          _truckLocation = LatLng(lat, lng);
          _truckUpdatedAt = d['updatedAt'] as Timestamp?;
        });
        _recalculateDistances();
        _mapController.animateCamera(
          CameraUpdate.newLatLng(LatLng(lat, lng)),
        );
      }
    });


    // preload custom truck icon
    MapIconService.loadTruckIcon().then((_) {
      if (mounted) {
        setState(() {
          _truckMarkerIcon = MapIconService.truckIcon;
        });
      }
    });

    // ==== ACTIVE ORDERS STREAM ====
    // Treat both 'active' and 'out_for_delivery' as "Active Orders"
    FirebaseFirestore.instance
        .collection('orders')
        .where('status', whereIn: ['active', 'out_for_delivery'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen((snapshot) async {
      final built = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // user name
        final userId = (data['userId'] ?? '').toString();
        final fullName = await _getFullNameFor(userId);

        // address
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};
        final line1 = (addr['address_1'] ?? '').toString().trim();
        final city = (addr['city'] ?? '').toString().trim();
        final lastMaybeAddress = (addr['last_name'] ?? '').toString().trim();
        String addressLine =
        ([line1, city]..removeWhere((s) => s.isEmpty)).join(', ');
        if (addressLine.isEmpty && lastMaybeAddress.isNotEmpty) {
          addressLine = lastMaybeAddress;
        }
        if (addressLine.isEmpty) addressLine = 'Larnaca, Cyprus';

        final phone = (addr['phone'] ?? '').toString().trim();

        // meta (for subscription & coords)
        final meta = (data['meta'] as Map<String, dynamic>?) ?? {};

        // coords → distance from truck (or default)
        final lat =
        ((addr['lat'] ?? meta['location_lat']) as num?)?.toDouble();
        final lng =
        ((addr['lng'] ?? meta['location_lng']) as num?)?.toDouble();

        final hasLL = lat != null && lng != null;
        final origin = _truckLocation ?? _defaultTruckLocation;
        final distanceKm = hasLL
            ? Geolocator.distanceBetween(
          origin.latitude,
          origin.longitude,
          lat!,
          lng!,
        ) /
            1000.0
            : 9999.0;

        final deliveryType = (meta['delivery_type'] ?? 'normal').toString();
        final timeSlot = (meta['time_slot'] ?? '').toString();
        final frequency = (meta['frequency'] ?? '').toString();

        num _num(dynamic v) =>
            v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
        final total = _num(data['total']);
        final createdAt = (data['createdAt'] ?? data['timestamp']);
        final paymentStatus = (data['paymentStatus'] ?? 'unpaid').toString();
        final currency = (data['currency'] ?? '').toString();
        final paymentMethod = (data['paymentMethod'] ?? 'card').toString();
        final items = (data['wooLineItems'] as List?) ??
            (data['items'] as List?) ??
            const [];

        built.add({
          'id': doc.id,
          'userId': userId,
          'customerName': fullName.isNotEmpty ? fullName : userId,
          'address': addressLine,
          'phone': phone,
          'distance': distanceKm,
          'timestamp': createdAt,
          'lat': lat,
          'lng': lng,
          'total': total,
          'paymentStatus': paymentStatus,
          'items': items,
          'currency': currency,
          'paymentMethod': paymentMethod,
          'subscription': deliveryType == 'subscription',
          'timeSlot': timeSlot.isEmpty ? 'No time selected' : timeSlot,
          'frequency': frequency,
          'cycleNumber': data['cycle_number'] ?? 1,
          'parentId': data['parentId'] ?? doc.id,
          'status': (data['status'] ?? '').toString(),
        });
      }

      if (mounted) {
        setState(() {
          _orders = _sortOrders(built);
        });
      }
    }, onError: (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Can’t load active orders: $e')),
        );
      }
    });
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
            'type': 'status_$status', // e.g. status_out_for_delivery
            'note': _statusLabel(status),
          }
        ]),
      });

      // system note in chat (works with onChatMessageCreated trigger)
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(orderId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'text': 'Status updated to ${_statusLabel(status)}.',
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status → ${_statusLabel(status)}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'out_for_delivery':
        return 'Out for delivery';
      case 'delivered':
        return 'Delivered';
      case 'active':
        return 'Active';
      default:
        return s;
    }
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
                  Text(
                    "Truck Location",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "Last updated: $updatedStr",
                style: const TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  final lat = _truckLocation!.latitude;
                  final lng = _truckLocation!.longitude;
                  final url = Uri.parse(
                    "https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving",
                  );
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

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{};

    final initialTarget = _truckLocation ?? _defaultTruckLocation;

    // truck marker
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

    // order markers
    for (final o in _orders) {
      final lat = o['lat'] as double?;
      final lng = o['lng'] as double?;
      if (lat != null && lng != null) {
        markers.add(
          Marker(
            markerId: MarkerId(o['id'] as String),
            position: LatLng(lat, lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            onTap: () => _showOrderDialog(o),
          ),
        );
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Expanded(
              child: Text(
                "Active Orders",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0E1A36),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // SAME AS PENDING
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
                    width: 160,
                    child: const TruckDropdown(),
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
          // MAP
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                key: ValueKey(
                    '${initialTarget.latitude}_${initialTarget.longitude}'),
                onMapCreated: (c) => _mapController = c,
                initialCameraPosition:
                CameraPosition(target: initialTarget, zoom: 13),
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
              const Text(
                "Active Orders",
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

          // LIST
          Expanded(
            child: AbsorbPointer(
              absorbing: _busy,
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT: details
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
                                      _formatDistance(
                                          order['distance'] as double),
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
                                        (order['address'] ?? 'No address')
                                        as String,
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
                                    _chip((order['paymentMethod'] == 'cod')
                                        ? 'COD'
                                        : 'Card'),
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
                                      _chip(
                                        'Total: ${order['total']} ${order['currency'] ?? ''}',
                                      ),
                                    _chip((order['subscription'] as bool)
                                        ? 'Subscription'
                                        : 'One-off'),
                                    if (order['subscription'] == true)
                                      _chip('Cycle ${order['cycleNumber']}'),

                                    if ((order['subscription'] as bool) &&
                                        (order['timeSlot'] as String)
                                            .isNotEmpty)
                                      _chip('Slot: ${order['timeSlot']}'),

                                    if ((order['subscription'] as bool) &&
                                        (order['frequency'] as String)
                                            .isNotEmpty)
                                      _chip('Every: ${order['frequency']}'),
                                  ],
                                ),

                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _updateStatus(
                                          order['id'] as String,
                                          'out_for_delivery'),
                                      icon:
                                      const Icon(Icons.delivery_dining),
                                      label:
                                      const Text('Out for delivery'),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: () => _updateStatus(
                                          order['id'] as String,
                                          'delivered'),
                                      icon: const Icon(
                                          Icons.check_circle_outline),
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
                                  final customerId =
                                  (order['userId'] ?? '').toString();
                                  if (customerId.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Missing customerId for this order'),
                                      ),
                                    );
                                    return;
                                  }

                                  await ChatService.instance.ensureChat(
                                    orderId: order['parentId'],  // always parent for subscriptions
                                    customerId: customerId,
                                    adminId: FirebaseAuth.instance.currentUser!.uid,
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
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.black87),
    ),
  );

  Widget _circleBtn({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }

  void _showOrderDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (_) {
        final List items = (order['items'] as List?) ?? const [];

        return AlertDialog(
          backgroundColor: Colors.white,
          contentPadding: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF0E1A36)),
              const SizedBox(width: 8),
              Text(
                'Order #${order['id'].toString().substring(0, 8)}',
                style: const TextStyle(
                  color: Color(0xFF0E1A36),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CUSTOMER CARD
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
                      Row(children: const [
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
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 16, color: Colors.black45),
                          SizedBox(width: 6),
                          Text(
                            (order['phone'] ?? '-').toString(),
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 16, color: Colors.black45),
                          SizedBox(width: 6),
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

                // ORDER DETAILS CARD
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
                      Row(children: const [
                        Icon(Icons.info_outline,
                            color: Color(0xFF0E1A36), size: 20),
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
                            SizedBox(width: 6),
                            Text(
                              "Ordered: ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                              style: const TextStyle(color: Colors.black45),
                            ),
                          ],
                        ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.social_distance,
                              color: Colors.amber, size: 16),
                          SizedBox(width: 6),
                          Text(
                            "Distance: ${_formatDistance(order['distance'] as double)} from truck",
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      if (items.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Colors.grey),
                        const SizedBox(height: 6),
                        const Text(
                          'Items',
                          style: TextStyle(
                            color: Color(0xFF0E1A36),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),

                        ...items.map<Widget>((it) {
                          final name = it['name']?.toString() ?? 'Item';
                          final qty = it['quantity']?.toString() ?? '1';
                          final lineTotal = it['total']?.toString() ?? '';

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
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Text(
                                  lineTotal.isEmpty
                                      ? ''
                                      : '${order['currency'] ?? ''} $lineTotal',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],

                      // --- TOTAL ---
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
              child: const Text("Close", style: TextStyle(color: Colors.black87)),
            ),

            TextButton.icon(
              onPressed: () => _updateStatus(order['id'], 'out_for_delivery'),
              icon: const Icon(Icons.delivery_dining, color: Colors.white),
              label: const Text('Out for delivery',
                  style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(backgroundColor: Colors.indigo),
            ),

            TextButton.icon(
              onPressed: () => _updateStatus(order['id'], 'delivered'),
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label:
              const Text('Delivered', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(backgroundColor: Colors.green),
            ),
          ],
        );
      },
    );
  }
}
