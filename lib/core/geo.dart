// lib/core/geo.dart
// Geohash helpers (IDENTICAL in both apps; same maths as worker/src/geo.ts).
// Requests and helper positions store a 5-character geohash (cells of about
// 4.9 km × 4.5 km). Searching the 5×5 block of cells around a point covers more
// than 5 km in every direction; exact distance is then checked in code.

import 'dart:math' as math;

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
const _cellLat = 180 / 4096; // precision 5 → 12 latitude bits
const _cellLng = 360 / 8192; // and 13 longitude bits

String geohash(double lat, double lng, [int precision = 5]) {
  var latMin = -90.0, latMax = 90.0, lngMin = -180.0, lngMax = 180.0;
  final out = StringBuffer();
  var bit = 0, ch = 0;
  var even = true;
  while (out.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch = ch << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch = ch << 1;
        latMax = mid;
      }
    }
    even = !even;
    if (++bit == 5) {
      out.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return out.toString();
}

/// The 25 precision-5 cells around a point (Firestore `whereIn` allows 30).
List<String> nearbyCells(double lat, double lng) {
  final cLat = ((lat + 90) / _cellLat).floor() * _cellLat - 90 + _cellLat / 2;
  final cLng = ((lng + 180) / _cellLng).floor() * _cellLng - 180 + _cellLng / 2;
  final cells = <String>{};
  for (var dy = -2; dy <= 2; dy++) {
    for (var dx = -2; dx <= 2; dx++) {
      final la = (cLat + dy * _cellLat).clamp(-89.99, 89.99).toDouble();
      var ln = cLng + dx * _cellLng;
      if (ln > 180) ln -= 360;
      if (ln < -180) ln += 360;
      cells.add(geohash(la, ln, 5));
    }
  }
  return cells.toList();
}

/// Straight-line distance in km.
double kmBetween(double lat1, double lng1, double lat2, double lng2) {
  double r(double d) => d * math.pi / 180;
  final dLat = r(lat2 - lat1), dLng = r(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(r(lat1)) * math.cos(r(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * 6371 * math.asin(math.sqrt(a));
}

/// Rounds a coordinate to ~1 km so a request's public data never shows the exact house.
double approx(double v) => (v * 100).roundToDouble() / 100;