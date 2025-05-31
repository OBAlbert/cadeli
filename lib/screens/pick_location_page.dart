import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

const _placesApiKey = 'AIzaSyADsxWf0_pAhv8BOQ1oXWefCuj-PJP7qCY'; // BROWSER KEY

class PickLocationPage extends StatefulWidget {
  const PickLocationPage({super.key});

  @override
  State<PickLocationPage> createState() => _PickLocationPageState();
}

class _PickLocationPageState extends State<PickLocationPage> {
  final _mapController = Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();
  late GooglePlace _googlePlace;

  final LatLng _larnacaCenter = const LatLng(34.9167, 33.6333);
  LatLng _picked = const LatLng(34.9167, 33.6333);
  String _address = '';
  List<AutocompletePrediction> _predictions = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(_placesApiKey);
    _reverseGeocode(_picked);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    final result = await _googlePlace.autocomplete.get(
      input,
      components: [Component('country', 'cy')],
    );
    if (result != null && result.predictions != null) {
      setState(() => _predictions = result.predictions!);
    }
  }

  Future<void> _selectPrediction(AutocompletePrediction p) async {
    final details = await _googlePlace.details.get(p.placeId!);
    final loc = details?.result?.geometry?.location;
    if (loc != null) {
      final pos = LatLng(loc.lat!, loc.lng!);
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
      setState(() {
        _picked = pos;
        _address = details?.result?.formattedAddress ?? 'Selected location';
        _predictions = [];
        _searchController.text = details?.result?.name ?? '';
      });
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pl = placemarks.first;
        setState(() => _address = '${pl.street}, ${pl.locality}, ${pl.administrativeArea}');
      }
    } catch (_) {
      setState(() => _address = 'Unable to get address');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _useMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || !serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Location not available")));
      return;
    }
    final pos = await Geolocator.getCurrentPosition();
    final dist = Geolocator.distanceBetween(
      _larnacaCenter.latitude, _larnacaCenter.longitude, pos.latitude, pos.longitude,
    );
    if (dist > 30000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only available in Larnaca.")));
      return;
    }
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16));
    setState(() => _picked = LatLng(pos.latitude, pos.longitude));
    _reverseGeocode(_picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Pick Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/background/fade_base.jpg', fit: BoxFit.cover)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(
                            hintText: 'Search address in Larnaca...',
                            hintStyle: const TextStyle(color: Colors.black54),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _useMyLocation,
                        icon: const Icon(Icons.my_location, color: Colors.white),
                      )
                    ],
                  ),
                ),
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final p = _predictions[index];
                        return ListTile(
                          title: Text(p.description ?? '', style: const TextStyle(color: Colors.black)),
                          onTap: () => _selectPrediction(p),
                        );
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    height: MediaQuery.of(context).size.height * 0.45,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          GoogleMap(
                            initialCameraPosition: CameraPosition(target: _picked, zoom: 14),
                            onMapCreated: (controller) => _mapController.complete(controller),
                            onCameraMove: (position) => _picked = position.target,
                            onCameraIdle: () => _reverseGeocode(_picked),
                            myLocationButtonEnabled: false,
                            myLocationEnabled: false,
                            zoomGesturesEnabled: true,
                            zoomControlsEnabled: false,
                          ),
                          const Icon(Icons.location_on, size: 56, color: Color(0xFFC70418)), // Highlighted target icon
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : Text(
                      _address,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, _address),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF254573),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: const Text('Confirm Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
