import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class PickLocationPage extends StatefulWidget {
  const PickLocationPage({super.key});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  Completer<GoogleMapController> mapController = Completer();
  LatLng? selectedPosition;
  String selectedAddress = 'Move map to pick address...';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    final hasPermission = await Geolocator.checkPermission();
    if (hasPermission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    final controller = await mapController.future;
    final target = LatLng(position.latitude, position.longitude);
    setState(() => selectedPosition = target);
    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
    _updateAddress(target);
  }

  void _onCameraIdle() async {
    final controller = await mapController.future;
    final center = await controller.getLatLng(ScreenCoordinate(x: 200, y: 400));
    setState(() {
      selectedPosition = center;
      selectedAddress = 'Getting address...';
    });
    _updateAddress(center);
  }

  Future<void> _updateAddress(LatLng pos) async {
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          selectedAddress = "${place.street}, ${place.locality}, ${place.administrativeArea}";
        });
      }
    } catch (_) {
      setState(() {
        selectedAddress = "Address not found";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController.complete(controller),
            initialCameraPosition: const CameraPosition(target: LatLng(34.9166, 33.6298), zoom: 14), // Larnaca default
            onCameraIdle: _onCameraIdle,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            myLocationButtonEnabled: true,
          ),
          const Icon(Icons.location_on, size: 40, color: Colors.redAccent),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                  child: Text(
                    selectedAddress,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, selectedAddress);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Confirm Location", style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}