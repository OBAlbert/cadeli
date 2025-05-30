// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:geolocator/geolocator.dart';
//
// class MapPickerPage extends StatefulWidget {
//   final Function(LatLng) onLocationPicked;
//   const MapPickerPage({super.key, required this.onLocationPicked});
//
//   @override
//   State<MapPickerPage> createState() => _MapPickerPageState();
// }
//
// class _MapPickerPageState extends State<MapPickerPage> {
//   GoogleMapController? _mapController;
//   LatLng? _selectedLocation;
//
//   @override
//   void initState() {
//     super.initState();
//     _determinePosition();
//   }
//
//   Future<void> _determinePosition() async {
//     bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
//     if (!serviceEnabled) {
//       await Geolocator.openLocationSettings();
//       return;
//     }
//
//     LocationPermission permission = await Geolocator.requestPermission();
//     if (permission == LocationPermission.denied) return;
//
//     Position position = await Geolocator.getCurrentPosition();
//     _mapController?.animateCamera(CameraUpdate.newLatLng(
//         LatLng(position.latitude, position.longitude)));
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Pick Location')),
//       body: Stack(
//         alignment: Alignment.center,
//         children: [
//           GoogleMap(
//             onMapCreated: (controller) => _mapController = controller,
//             initialCameraPosition: const CameraPosition(
//               target: LatLng(34.9229, 33.6250), // Larnaca
//               zoom: 14,
//             ),
//             onCameraMove: (pos) => _selectedLocation = pos.target,
//           ),
//           const Icon(Icons.location_pin, size: 50, color: Colors.red),
//           Positioned(
//             bottom: 30,
//             child: ElevatedButton(
//               onPressed: () {
//                 if (_selectedLocation != null) {
//                   widget.onLocationPicked(_selectedLocation!);
//                   Navigator.pop(context);
//                 }
//               },
//               child: const Text("Confirm Location"),
//             ),
//           )
//         ],
//       ),
//     );
//   }
// }
