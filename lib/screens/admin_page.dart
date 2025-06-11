import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';


// backgroundColor: Colors.black87,

// @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFA1BDC7),
//       appBar: AppBar(
//         title: const Text('Verify Your Email'),
//         backgroundColor: Colors.black87,
//       ),

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
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

  void _showOrderDialog(Map<String, dynamic> order) {
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
            Text(order['name'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (order['address'] != null)
              Text("📍 ${order['address']}", style: const TextStyle(color: Colors.white)),
            if (order['number'] != null)
              Text("☎️ ${order['number']}", style: const TextStyle(color: Colors.white)),
            if ((order['deliveryNotes'] ?? '').toString().trim().isNotEmpty)
              Text("📝 ${order['deliveryNotes']}", style: const TextStyle(color: Colors.white)),
            if (order['status'] != null)
              Text("📦 ${order['status']}", style: const TextStyle(color: Colors.white)),
            if (order['timestamp'] != null)
              Text(
                "📅 ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                style: const TextStyle(color: Colors.white),
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: 0,
      //   onTap: (_) {},
      //   selectedItemColor: Colors.white,
      //   unselectedItemColor: Colors.white70,
      //   backgroundColor: const Color(0xFF254573),
      //   items: const [
      //     BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Admin'),
      //     BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Logout'),
      //   ],
      // ),
      appBar: AppBar(
        title: Text(
          "${_orders.length} Active Orders",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: const Color(0xFF254573),
      ),
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
                      // Name + Distance
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          ),
                          Text(
                            "${(order['distance'] as double).toStringAsFixed(1)} km",
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("📍 ${order['address'] ?? ''}", style: const TextStyle(fontSize: 14, color: Colors.black)),
                      Text("☎️ ${order['number'] ?? ''}", style: const TextStyle(fontSize: 14, color: Colors.black)),
                      if ((order['deliveryNotes'] ?? '').toString().trim().isNotEmpty)
                        Text("📝 ${order['deliveryNotes']}", style: const TextStyle(fontSize: 14, color: Colors.black)),
                      Text("📦 ${order['status'] ?? ''}", style: const TextStyle(fontSize: 14, color: Colors.black)),
                      if (order['timestamp'] != null)
                        Text(
                          "📅 ${DateFormat('MMM d, h:mm a').format((order['timestamp'] as Timestamp).toDate())}",
                          style: const TextStyle(fontSize: 14, color: Colors.black54),
                        ),
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
