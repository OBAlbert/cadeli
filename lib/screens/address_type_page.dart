import 'package:flutter/material.dart';
import 'address_apartment_page.dart';
import 'address_house_page.dart';
import 'address_office_page.dart';
import 'address_hotel_page.dart';
import 'address_other_page.dart';

class AddressTypePage extends StatelessWidget {
  final double lat;
  final double lng;
  final String formatted;
  final String city;
  final String country;

  const AddressTypePage({
    super.key,
    required this.lat,
    required this.lng,
    required this.formatted,
    required this.city,
    required this.country,
  });

  static const _ink = Color(0xFF1A233D); // Cadeli dark blue

  void _openDetails(BuildContext context, String type) async {
    Widget page;

    switch (type) {
      case 'apartment':
        page = AddressApartmentPage(
          lat: lat,
          lng: lng,
          formatted: formatted,
          city: city,
          country: country,
        );
        break;

      case 'house':
        page = AddressHousePage(
          lat: lat,
          lng: lng,
          formatted: formatted,
          city: city,
          country: country,
        );
        break;

      case 'office':
        page = AddressOfficePage(
          lat: lat,
          lng: lng,
          formatted: formatted,
          city: city,
          country: country,
        );
        break;

      case 'hotel':
        page = AddressHotelPage(
          lat: lat,
          lng: lng,
          formatted: formatted,
          city: city,
          country: country,
        );
        break;

      default:
        page = AddressOtherPage(
          lat: lat,
          lng: lng,
          formatted: formatted,
          city: city,
          country: country,
        );
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );

    if (result != null) {
      Navigator.pop(context, result);
    }
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Icon(icon, color: _ink, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F8F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP NAV
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: _ink),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          city,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _ink,
                          ),
                        ),
                        Text(
                          '$country • ${formatted.split(",").first}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.check_circle, color: Colors.green, size: 32),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // HEADING
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Where are we delivering?",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                "Choose your location type to help the courier find you faster.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ),

            const SizedBox(height: 12),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _card(
                    icon: Icons.apartment,
                    title: "Apartment",
                    subtitle: "e.g. residential building / flats",
                    onTap: () => _openDetails(context, "apartment"),
                  ),
                  _card(
                    icon: Icons.home_filled,
                    title: "House",
                    subtitle: "Standalone house or duplex",
                    onTap: () => _openDetails(context, "house"),
                  ),
                  _card(
                    icon: Icons.business,
                    title: "Office",
                    subtitle: "Corporate office or workplace",
                    onTap: () => _openDetails(context, "office"),
                  ),
                  _card(
                    icon: Icons.hotel,
                    title: "Hotel",
                    subtitle: "Hotel, motel or resort",
                    onTap: () => _openDetails(context, "hotel"),
                  ),
                  _card(
                    icon: Icons.location_city_outlined,
                    title: "Other",
                    subtitle: "Park, hospital, event space, etc.",
                    onTap: () => _openDetails(context, "other"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
