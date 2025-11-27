import 'package:flutter/material.dart';

IconData addressIcon(String type) {
  switch (type) {
    case 'house': return Icons.home_filled;
    case 'apartment': return Icons.business;
    case 'office': return Icons.apartment;
    case 'hotel': return Icons.hotel;
    default: return Icons.location_on;
  }
}
