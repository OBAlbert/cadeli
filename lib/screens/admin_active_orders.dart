import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';


class ActiveOrdersPage  extends StatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  State<ActiveOrdersPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<ActiveOrdersPage> {
  late GoogleMapController _mapController;
  final LatLng _shopLocation = const LatLng(34.9192, 33.6225);
  List<Map<String, dynamic>> _orders = [];
  String _sortBy = 'distance';

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'active')
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
        ) /
            1000
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
      orders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
    } else {
      orders.sort((a, b) => (b['timestamp'] as Timestamp).compareTo(a['timestamp'] as Timestamp));
    }
    return orders;
  }

  void _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order status updated to $newStatus'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _showOrderDialog(Map<String, dynamic> order) {
    final String currentStatus = order['status'] ?? 'active';
    final List<String> statusOptions = _getNextStatusOptions(currentStatus);
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1F2937),
        contentPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    order['name'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(currentStatus),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusDisplayText(currentStatus),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (order['address'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("📍 ${order['address']}", 
                  style: const TextStyle(color: Colors.white)),
              ),
            if (order['number'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("☎️ ${order['number']}", 
                  style: const TextStyle(color: Colors.white)),
              ),
            if ((order['deliveryNotes'] ?? '').toString().trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("📝 ${order['deliveryNotes']}", 
                  style: const TextStyle(color: Colors.white)),
              ),
            if (order['timestamp'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(
                  "📅 ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            if (order['items'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Items:",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...((order['items'] as List<dynamic>?) ?? [])
                      .take(3)
                      .map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              "• ${item['name']} x${item['quantity']} - €${item['price']}",
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          )),
                  if ((order['items'] as List<dynamic>?)?.length != null && 
                      (order['items'] as List<dynamic>).length > 3)
                    Text(
                      "+${(order['items'] as List<dynamic>).length - 3} more items",
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  const SizedBox(height: 15),
                ],
              ),
            if (order['totalCost'] != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: Text(
                  "Total: €${(order['totalCost'] as double).toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            if (statusOptions.isNotEmpty) ...[
              const Divider(color: Colors.white30),
              const SizedBox(height: 10),
              const Text(
                "Update Status:",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: statusOptions.map((status) => ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateOrderStatus(order['id'], status);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getStatusColor(status),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _getStatusDisplayText(status),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  List<String> _getNextStatusOptions(String currentStatus) {
    switch (currentStatus.toLowerCase()) {
      case 'pending':
        return ['processing'];
      case 'active':
      case 'processing':
        return ['out_for_delivery'];
      case 'out_for_delivery':
        return ['delivered', 'completed'];
      default:
        return [];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'active':
      case 'processing':
        return Colors.blue;
      case 'out_for_delivery':
        return Colors.purple;
      case 'delivered':
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusDisplayText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'active':
      case 'processing':
        return 'Preparing';
      case 'out_for_delivery':
        return 'Out for Delivery';
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
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
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GoogleMap(
                onMapCreated: (controller) => _mapController = controller,
                initialCameraPosition: CameraPosition(target: _shopLocation, zoom: 13),
                zoomControlsEnabled: true,
                minMaxZoomPreference: const MinMaxZoomPreference(5, 18),
                markers: _orders.where((order) => order['location'] != null).map((order) {
                  final GeoPoint loc = order['location'];
                  return Marker(
                    markerId: MarkerId(order['id']),
                    position: LatLng(loc.latitude, loc.longitude),
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
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
                  "Active Orders",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
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
                )
              ],
            ),
          ),

          // ORDER LIST
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + Distance + Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              order['name'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order['status'] ?? 'active').withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getStatusColor(order['status'] ?? 'active').withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _getStatusDisplayText(order['status'] ?? 'active'),
                              style: TextStyle(
                                color: _getStatusColor(order['status'] ?? 'active'),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              "📍 ${order['address'] ?? ''}",
                              style: const TextStyle(fontSize: 14, color: Colors.black),
                            ),
                          ),
                          Text(
                            "${(order['distance'] as double).toStringAsFixed(1)} km",
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text("☎️ ${order['number'] ?? ''}", style: const TextStyle(fontSize: 14, color: Colors.black)),
                      if ((order['deliveryNotes'] ?? '').toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text("📝 ${order['deliveryNotes']}", style: const TextStyle(fontSize: 14, color: Colors.black)),
                      ],
                      if (order['timestamp'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          "📅 ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ],
                      if (order['totalCost'] != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total: €${(order['totalCost'] as double).toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _showOrderDialog(order),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A233D),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Text(
                                  "Manage",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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
}
