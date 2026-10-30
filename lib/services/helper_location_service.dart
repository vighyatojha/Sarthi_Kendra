// lib/services/helper_location_service.dart
// Shares the helper's position ONLY while they are "Available".
// The position goes to helper_locations/{uid}, which no other user can read;
// the push Worker uses it to alert helpers within 5 km of a new request.
// The requests feed also uses the last known position to find nearby jobs.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../core/geo.dart';

class HelperLocationService {
  HelperLocationService._();
  static final HelperLocationService instance = HelperLocationService._();

  DateTime? _lastWrite;
  double? _lastLat;
  double? _lastLng;

  /// Last position seen by this service (may be null right after app start).
  ({double lat, double lng})? get lastKnown =>
      _lastLat == null || _lastLng == null ? null : (lat: _lastLat!, lng: _lastLng!);

  /// Writes at most every 2 minutes, or sooner after moving 300 m.
  Future<void> report(Position pos, {required bool isOnline, bool force = false}) async {
    _remember(pos);
    if (!isOnline) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    if (!force && _lastWrite != null && _writtenLat != null) {
      final moved = Geolocator.distanceBetween(_writtenLat!, _writtenLng!, pos.latitude, pos.longitude);
      if (now.difference(_lastWrite!) < const Duration(minutes: 2) && moved < 300) return;
    }
    _lastWrite = now;
    _writtenLat = pos.latitude;
    _writtenLng = pos.longitude;
    try {
      await FirebaseFirestore.instance.collection('helper_locations').doc(uid).set({
        'lat': pos.latitude,
        'lng': pos.longitude,
        'geohash5': geohash(pos.latitude, pos.longitude, 5),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _lastWrite = null;
      debugPrint('HelperLocationService.report: $e');
    }
  }

  double? _writtenLat;
  double? _writtenLng;

  void _remember(Position pos) {
    _lastLat = pos.latitude;
    _lastLng = pos.longitude;
  }

  /// Position for the requests feed: last known, else a fresh GPS fix.
  /// Returns null if location is off or not allowed.
  Future<({double lat, double lng})?> currentPosition() async {
    final known = lastKnown;
    if (known != null) return known;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return null;
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _remember(last);
        return lastKnown;
      }
      // geolocator 12.x (this app's version) takes desiredAccuracy here.
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(const Duration(seconds: 20));
      _remember(pos);
      return lastKnown;
    } catch (_) {
      return null;
    }
  }

  /// Call BEFORE switching to Available: saves the current position.
  /// Returns null on success, or a message to show (then stay offline).
  Future<String?> goOnline() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return 'Turn on location (GPS) so nearby customers can find you.';
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        return 'Location permission is needed to receive nearby requests.';
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 20));
      await report(pos, isOnline: true, force: true);
      return null;
    } catch (e) {
      return 'Could not get your location. Try again outdoors.';
    }
  }

  /// Removes the stored position when going offline or logging out.
  Future<void> goOffline() async {
    _lastWrite = null;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('helper_locations').doc(uid).delete();
    } catch (_) {}
  }
}