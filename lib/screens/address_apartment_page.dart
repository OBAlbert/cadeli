import 'package:flutter/material.dart';

class AddressApartmentPage extends StatefulWidget {
  const AddressApartmentPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.formatted,
    required this.city,
    required this.country,
  });

  final double lat;
  final double lng;
  final String formatted;
  final String city;
  final String country;

  @override
  State<AddressApartmentPage> createState() => _AddressApartmentPageState();
}

class _AddressApartmentPageState extends State<AddressApartmentPage> {
  static const ink = Color(0xFF1A233D);
  static const inkLight = Color(0xFF2A3A58);

  final buildingCtrl = TextEditingController();
  final entranceCtrl = TextEditingController();
  final floorCtrl = TextEditingController();
  final aptCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ink),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              widget.city,
              style: const TextStyle(
                color: ink,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            Text(
              widget.formatted,
              style: const TextStyle(
                fontSize: 12,
                color: inkLight,
              ),
            ),
          ],
        ),
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          const Text(
            "Address details",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Add details to help the courier find you easily.",
            style: TextStyle(fontSize: 14, color: inkLight),
          ),
          const SizedBox(height: 24),

          _field("Building name", "e.g. Yuho Tower", buildingCtrl),
          _field("Entrance / Staircase", "e.g. A or 3", entranceCtrl),
          _field("Floor", "e.g. 5", floorCtrl),
          _field("Apartment", "e.g. 45", aptCtrl),

          const SizedBox(height: 20),
          _nextButton(),
        ],
      ),
    );
  }

  Widget _field(String label, String hint, TextEditingController c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: ink),
          hintText: hint,
          hintStyle: const TextStyle(color: inkLight),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: ink, width: 1.4),
          ),
        ),
      ),
    );
  }

  Widget _nextButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          final data = {
            "type": "apartment",
            "details": {
              "buildingName": buildingCtrl.text.trim(),
              "entrance": entranceCtrl.text.trim(),
              "floor": floorCtrl.text.trim(),
              "apartment": aptCtrl.text.trim(),
            },
            "lat": widget.lat,
            "lng": widget.lng,
            "formatted": widget.formatted,
            "city": widget.city,
            "country": widget.country,
          };
          Navigator.pop(context, data);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "Next",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
