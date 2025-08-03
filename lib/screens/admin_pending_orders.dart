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
      final orders = snapshot.docs
          .map((doc) {
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
      })
          .where((order) =>
      (order['name'] ?? '').toString().trim().isNotEmpty &&
          (order['address'] ?? '').toString().trim().isNotEmpty)
          .toList();

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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(
                        value: 'distance',
                        child: Text(
                          "By Distance",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                        )),
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

                return GestureDetector(
                  onTap: () => _showOrderDialog(order), // 📌 Tap opens full detail
                  child:
                   Container(
                    margin: const EdgeInsets.only(bottom: 16), // Spacing between cards
                    padding: const EdgeInsets.all(16), // Inner card padding
                    decoration: BoxDecoration(
                      color: Colors.white, // White background as per wireframe
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300), // Soft border
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🔹 Top row: User name (bold) and distance
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              order['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              "${(order['distance'] as double).toStringAsFixed(0)}km",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        // 🔹 Address row with pin icon
                        Row(
                          children: [
                            const Icon(Icons.location_pin, color: Colors.red, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order['address'] ?? 'No address',
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // 🔹 Time slot row
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              order['timeSlot'] ?? 'No time',
                              style: const TextStyle(fontSize: 14, color: Colors.black87),
                            ),
                          ],
                        ),

                        const SizedBox(height: 4),

                        // 🔹 Subscription type row
                        Row(
                          children: [
                            const Icon(Icons.notifications_none, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(
                              order['subscription'] ?? 'no-subscription',
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // 🔹 Action buttons row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // ✅ Accept
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.check, color: Colors.white),
                                onPressed: () => _updateOrderStatus(order['id'], 'active'),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // 💬 Chat / Info button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blueGrey,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                onPressed: () => _showOrderDialog(order),
                                icon: Image.asset(
                                  'assets/icons/chat_icon.png',
                                  width: 20,
                                  height: 20,
                                  color: Colors.white, // Apply white tint
                                ),
                              ),
                            ),

                            const SizedBox(width: 8),

                            // ❌ Reject
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () => _rejectOrder(order['id']),
                              ),
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
                            color: Colors.black,
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
