import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class PendingOrdersPage extends StatefulWidget {
  const PendingOrdersPage({super.key});

  @override
  State<PendingOrdersPage> createState() => _PendingOrdersPageState();
}

class _PendingOrdersPageState extends State<PendingOrdersPage> {
  late GoogleMapController _mapController;
  final LatLng _shopLocation = const LatLng(34.9192, 33.6225);
  List<Map<String, dynamic>> _orders = [];
  String _sortBy = 'distance';

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data();
        final GeoPoint? loc = data['location'];
        final dist = loc != null
            ? Geolocator.distanceBetween(
          _shopLocation.latitude,
          _shopLocation.longitude,
          loc.latitude,
          loc.longitude,
        ) / 1000
            : 0.0;
        return {
          ...data,
          'distance': dist,
          'id': doc.id,
        };
      }).toList();

      setState(() {
        _orders = _sortOrders(orders);
      });
    });
  }

  List<Map<String, dynamic>> _sortOrders(List<Map<String, dynamic>> orders) {
    if (_sortBy == 'distance') {
      orders.sort((a, b) =>
          (a['distance'] as double).compareTo(b['distance'] as double));
    } else {
      orders.sort((a, b) => (b['timestamp'] as Timestamp)
          .compareTo(a['timestamp'] as Timestamp));
    }
    return orders;
  }

  void _updateOrderStatus(String id, String newStatus) {
    FirebaseFirestore.instance
        .collection('orders')
        .doc(id)
        .update({'status': newStatus});
  }

  void _rejectOrder(String id) {
    FirebaseFirestore.instance.collection('orders').doc(id).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // MAP
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 6)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition:
                CameraPosition(target: _shopLocation, zoom: 13),
                zoomControlsEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
                markers: _orders
                    .where((order) => order['location'] != null)
                    .map((order) {
                  final GeoPoint loc = order['location'];
                  return Marker(
                    markerId: MarkerId(order['id']),
                    position: LatLng(loc.latitude, loc.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueYellow),
                    onTap: () => _showOrderDialog(order),
                  );
                }).toSet(),
              ),
            ),
          ),

          // SORT HEADER
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Pending Orders",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(
                        value: 'distance', child: Text("By Distance")),
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
                )
              ],
            ),
          ),

          // ORDER LIST
          Expanded(
            child: ListView.builder(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Distance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order['name'] ?? '',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87),
                          ),
                          Text(
                            "${(order['distance'] as double).toStringAsFixed(1)} km",
                            style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("📍 ${order['address'] ?? ''}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black)),
                      Text("☎️ ${order['number'] ?? ''}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black)),
                      if ((order['deliveryNotes'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty)
                        Text("📝 ${order['deliveryNotes']}",
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black)),
                      Text("📦 ${order['status'] ?? ''}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black)),
                      if (order['timestamp'] != null)
                        Text(
                          "📅 ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check_circle,
                                color: Colors.green),
                            onPressed: () =>
                                _updateOrderStatus(order['id'], 'active'),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _rejectOrder(order['id']),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: Colors.amber),
            const SizedBox(width: 8),
            Text('Order #${order['id'].toString().substring(0, 8)}', 
                style: const TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Info Section
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
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.amber, size: 20),
                        const SizedBox(width: 8),
                        Text('Customer Information',
                            style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(order['name'] ?? 'No Name',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (order['number'] != null)
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(order['number'],
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                    const SizedBox(height: 6),
                    if (order['address'] != null)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(order['address'],
                                style: const TextStyle(color: Colors.white70)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Order Details Section
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
                    Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        const Text('Order Details',
                            style: TextStyle(
                                color: Colors.blue,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (order['timestamp'] != null)
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
                          "Distance: ${(order['distance'] as double).toStringAsFixed(1)} km from shop",
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    if ((order['deliveryNotes'] ?? '').toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, color: Colors.green, size: 16),
                          SizedBox(width: 6),
                          Text('Delivery Notes:',
                              style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(order['deliveryNotes'],
                            style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                      ),
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
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _rejectOrder(order['id']);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order rejected and removed'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            icon: const Icon(Icons.cancel, color: Colors.white),
            label: const Text('Reject', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(order['id'], 'active');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Order accepted and moved to active'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.check_circle, color: Colors.white),
            label: const Text('Accept', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
