import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapIconService {
  static BitmapDescriptor? truckIcon;

  static Future<void> loadTruckIcon() async {
    if (truckIcon != null) return;

    final data = await rootBundle.load('assets/icons/truck.png');
    final codec = await instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: 92,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ImageByteFormat.png);

    truckIcon = BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }
}
