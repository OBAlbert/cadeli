import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'address_type_page.dart'; // GeoPoint, FirebaseFirestore, FieldValue


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
  static const _larnacaRadiusMeters = 30000;

  LatLng _picked = const LatLng(34.9167, 33.6333);
  String _address = '';
  List<AutocompletePrediction> _predictions = [];
  bool _loading = false;

  // --- NEW: keep last good reverse-geocode + last valid point inside Larnaca
  Placemark? _lastPlacemark;
  LatLng _lastValid = const LatLng(34.9167, 33.6333);

  bool _isInsideLarnaca(LatLng p) {
    final d = Geolocator.distanceBetween(
      _larnacaCenter.latitude, _larnacaCenter.longitude, p.latitude, p.longitude,
    );
    return d <= _larnacaRadiusMeters;
  }

  void _rejectOutside() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('We currently deliver only within Larnaca.')),
    );
  }

  Future<Map<String, dynamic>> _saveAddressToFirestore({
    required String label,
    required String line1,
    required String city,
    required String country,
    required double lat,
    required double lng,

    required String type,                 // NEW
    required Map<String, dynamic> details, // NEW

    bool setAsDefault = true,
  })
  async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not signed in');

    final col = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses');

    final doc = col.doc(); // create id up-front
    final data = {
      'id': doc.id,
      'label': label,
      'line1': line1,

      'type': type,              // NEW
      'details': details,        // NEW

      'city': city,
      'country': country,
      'lat': lat,
      'lng': lng,
      'geo': GeoPoint(lat, lng),
      'isDefault': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (setAsDefault) {
      final batch = FirebaseFirestore.instance.batch();
      final all = await col.get();
      for (final d in all.docs) {
        batch.update(d.reference, {'isDefault': false});
      }
      batch.set(doc, {...data, 'isDefault': true});
      await batch.commit();
    } else {
      await doc.set(data);
    }

    return {...data, 'isDefault': setAsDefault};
  }



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
      location: LatLon(_larnacaCenter.latitude, _larnacaCenter.longitude),
      radius: _larnacaRadiusMeters, // bias to Larnaca
    );
    if (result?.predictions != null) {
      setState(() => _predictions = result!.predictions!);
    }
  }

  Future<void> _selectPrediction(AutocompletePrediction p) async {
    final details = await _googlePlace.details.get(p.placeId!);
    final loc = details?.result?.geometry?.location;
    if (loc == null) return;

    final pos = LatLng(loc.lat!, loc.lng!);
    if (!_isInsideLarnaca(pos)) {
      _rejectOutside();
      return;
    }

    final controller = await _mapController.future;
    await controller.animateCamera(CameraUpdate.newLatLngZoom(pos, 16));
    setState(() {
      _picked = pos;
      _lastValid = pos;
      _address = details?.result?.formattedAddress ?? 'Selected location';
      _predictions = [];
      _searchController.text = details?.result?.name ?? '';
    });
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loading = true);
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final pl = placemarks.first;
        _lastPlacemark = pl; // NEW
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
        title: const Padding(
          padding: EdgeInsets.only(left: 8.0),
          child: Text('Pick Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('assets/background/fade_base.jpg', fit: BoxFit.cover)),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _useMyLocation,
                          icon: const Icon(Icons.my_location, size: 18),
                          label: const Text('Use My Location'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF254573),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_predictions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(12)),
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _predictions.length,
                      itemBuilder: (context, index) {
                        final p = _predictions[index];
                        return ListTile(
                          title: Text(p.description ?? '', style: const TextStyle(color: Colors.black)),
                          onTap: () {
                            FocusScope.of(context).unfocus();
                            _selectPrediction(p);
                          },
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            GoogleMap(
                              initialCameraPosition: CameraPosition(target: _picked, zoom: 14),
                              onMapCreated: (controller) => _mapController.complete(controller),
                              onCameraMove: (position) => _picked = position.target,
                              onCameraIdle: () async {
                                if (!_isInsideLarnaca(_picked)) {
                                  _rejectOutside();
                                  final c = await _mapController.future;
                                  await c.animateCamera(CameraUpdate.newLatLngZoom(_lastValid, 14));
                                  return;
                                }
                                _lastValid = _picked;
                                _reverseGeocode(_picked);
                              },
                              myLocationButtonEnabled: false,
                              myLocationEnabled: false,
                              zoomGesturesEnabled: true,
                              zoomControlsEnabled: false,
                              onTap: (latLng) {
                                if (!_isInsideLarnaca(latLng)) {
                                  _rejectOutside();
                                  return;
                                }
                                setState(() => _picked = latLng);
                                _reverseGeocode(latLng);
                              },
                            ),
                            const Icon(Icons.location_on, size: 40, color: Color(0xFFC70418)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!_isInsideLarnaca(_picked)) {
                          _rejectOutside();
                          return;
                        }

                        final city = _lastPlacemark?.locality ?? 'Larnaca';
                        final country = _lastPlacemark?.isoCountryCode ?? 'CY';

                        // 1) Open the NEW Address Type selector screen
                        final structured = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddressTypePage(
                              lat: _picked.latitude,
                              lng: _picked.longitude,
                              formatted: _address,
                              city: city,
                              country: country,
                            ),
                          ),
                        );

                        // If user cancelled, do nothing
                        if (structured == null) return;

                        // 2) When user completes flow → save to Firestore
                        try {
                          final saved = await _saveAddressToFirestore(
                            label: structured['formatted'],         // formatted address
                            line1: structured['formatted'],         // same as label
                            city: structured['city'],
                            country: structured['country'],
                            lat: structured['lat'],
                            lng: structured['lng'],

                            // NEW
                            type: structured['type'],               // apartment, house, etc
                            details: structured['details'],         // fully structured details
                            setAsDefault: true,
                          );

                          if (mounted) Navigator.pop(context, saved);
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Couldn't save: $e")),
                          );
                        }

                      },
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
