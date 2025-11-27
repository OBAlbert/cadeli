import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _placesApiKey =
    'AIzaSyADsxWf0_pAhv8BOQ1oXWefCuj-PJP7qCY'; // same as your pickLocationPage

class PickTruckLocationPage extends StatefulWidget {
  const PickTruckLocationPage({super.key});

  @override
  State<PickTruckLocationPage> createState() => _PickTruckLocationPageState();
}

class _PickTruckLocationPageState extends State<PickTruckLocationPage> {
  final _mapController = Completer<GoogleMapController>();
  final TextEditingController _searchController = TextEditingController();
  late GooglePlace _googlePlace;

  LatLng _picked = const LatLng(34.9167, 33.6333);
  LatLng? _initialTruck;
  String _address = '';
  List<AutocompletePrediction> _predictions = [];
  bool _loading = false;

  BitmapDescriptor? _truckIcon;

  bool _liveTracking = false;
  StreamSubscription<Position>? _liveStream;

  // --- ICON --------------------------------------------------------

  Future<void> _loadTruckIcon() async {
    final bytes = await rootBundle.load('assets/icons/truck.png');
    final codec = await instantiateImageCodec(
      bytes.buffer.asUint8List(),
      targetWidth: 110,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ImageByteFormat.png);

    _truckIcon = BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
    setState(() {});
  }

  // --- INITIAL LOCATION --------------------------------------------

  Future<void> _loadInitialTruck() async {
    final snap = await FirebaseFirestore.instance
        .collection('config')
        .doc('truckLocation')
        .get();

    if (snap.exists) {
      final lat = (snap['lat'] as num?)?.toDouble();
      final lng = (snap['lng'] as num?)?.toDouble();
      if (lat != null && lng != null) {
        _initialTruck = LatLng(lat, lng);
        _picked = _initialTruck!;
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _googlePlace = GooglePlace(_placesApiKey);
    _loadTruckIcon();
    _loadInitialTruck().then((_) {
      _reverseGeocode(_picked);
      Future.delayed(const Duration(milliseconds: 300), () async {
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLngZoom(_picked, 15));
      });
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _liveStream?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- SEARCH / AUTOCOMPLETE --------------------------------------

  void _onSearchChanged() async {
    final input = _searchController.text.trim();
    if (input.isEmpty) {
      setState(() => _predictions = []);
      return;
    }
    final result = await _googlePlace.autocomplete.get(input);
    if (result?.predictions != null) {
      setState(() => _predictions = result!.predictions!);
    }
  }

  Future<void> _selectPrediction(AutocompletePrediction p) async {
    final details = await _googlePlace.details.get(p.placeId!);
    final loc = details?.result?.geometry?.location;
    if (loc == null) return;

    final pos = LatLng(loc.lat!, loc.lng!);
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    setState(() {
      _picked = pos;
      _address = details?.result?.formattedAddress ?? 'Selected location';
      _predictions = [];
      _searchController.text = details?.result?.name ?? '';
    });
    _reverseGeocode(_picked);
  }

  // --- REVERSE GEOCODE --------------------------------------------

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);
    try {
      final placemarks =
      await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pl = placemarks.first;
        setState(() =>
        _address = '${pl.street}, ${pl.locality}, ${pl.country}');
      }
    } catch (_) {
      setState(() => _address = 'Unknown location');
    } finally {
      setState(() => _loading = false);
    }
  }

  // --- USE MY LOCATION --------------------------------------------

  Future<void> _useMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || !serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Location not available")),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    final newPos = LatLng(pos.latitude, pos.longitude);
    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
    setState(() => _picked = newPos);
    _reverseGeocode(newPos);
  }

  // --- LIVE TRACKING ----------------------------------------------

  void _toggleLiveTracking() async {
    if (_liveTracking) {
      _liveStream?.cancel();
      _liveTracking = false;
      setState(() {});
      return;
    }

    _liveTracking = true;
    setState(() {});

    _liveStream = Geolocator.getPositionStream().listen((pos) {
      final newPos = LatLng(pos.latitude, pos.longitude);
      FirebaseFirestore.instance
          .collection('config')
          .doc('truckLocation')
          .set({
        'lat': newPos.latitude,
        'lng': newPos.longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() => _picked = newPos);

      _mapController.future
          .then((c) => c.animateCamera(CameraUpdate.newLatLng(newPos)));
    });
  }

  // --- SAVE -------------------------------------------------------

  Future<void> _save() async {
    final data = {
      'lat': _picked.latitude,
      'lng': _picked.longitude,
      'address': _address,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Active truck doc used by dropdown + maps
    await FirebaseFirestore.instance
        .collection('config')
        .doc('truckLocation')
        .set(data);

    // Saved list used by TruckDropdown history
    await FirebaseFirestore.instance
        .collection('config')
        .doc('truckLocations')
        .collection('list')
        .add({
      'lat': _picked.latitude,
      'lng': _picked.longitude,
      'address': _address,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (mounted) Navigator.pop(context, true);
  }

  // --- UI ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('truck'),
        position: _picked,
        icon: _truckIcon ?? BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        ),
        draggable: true,
        onDragEnd: (pos) {
          setState(() => _picked = pos);
          _reverseGeocode(pos);
        },
      ),
    };

    return Scaffold(
      backgroundColor: Colors.white,
      // no inner AppBar – parent Admin Panel already has one
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition:
              CameraPosition(target: _picked, zoom: 14),
              onMapCreated: (c) => _mapController.complete(c),
              markers: markers,
              onTap: (pos) {
                setState(() => _picked = pos);
                _reverseGeocode(pos);
              },
              onCameraMove: (pos) => _picked = pos.target,
              onCameraIdle: () => _reverseGeocode(_picked),
            ),
          ),

          // Top overlay: title + search + controls
          SafeArea(
            child: Column(
              children: [
                // title row (replaces AppBar)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: Color(0xFF1A233D),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Set Truck Location',
                        style: TextStyle(
                          color: Color(0xFF1A233D),
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),

                // search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      hintText: 'Search location...',
                      hintStyle: const TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xFF1A233D),
                      ),
                    ),
                  ),

                ),

                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (_, i) {
                        final p = _predictions[i];
                        return ListTile(
                          title: Text(p.description ?? ''),
                          onTap: () => _selectPrediction(p),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 10),

                // buttons row
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _glassBtn(
                        icon: Icons.my_location,
                        label: "Use My Location",
                        onTap: _useMyLocation,
                      ),
                      const SizedBox(width: 14),
                      _glassBtn(
                        icon: _liveTracking
                            ? Icons.pause
                            : Icons.wifi_tethering,
                        label: _liveTracking ? "Stop Live" : "Live Track",
                        onTap: _toggleLiveTracking,
                        active: _liveTracking,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // bottom confirm card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding:
              const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _loading
                      ? const CircularProgressIndicator()
                      : Text(
                    _address,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A233D),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFF0D2952),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Truck Location',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
          active ? const Color(0xFF0D2952) : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? Colors.indigo : Colors.black12,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: active ? Colors.white : const Color(0xFF1A233D)),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFF1A233D),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
