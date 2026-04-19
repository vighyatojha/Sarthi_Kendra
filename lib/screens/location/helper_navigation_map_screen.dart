// lib/screens/location/helper_navigation_map_screen.dart

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
const _purple = Color(0xFF7C3AED);
const _indigo = Color(0xFF2D1B69);
const _violet = Color(0xFF5B21B6);
const _green  = Color(0xFF16A34A);
const _red    = Color(0xFFEF4444);
const _bg     = Color(0xFFF8F7FF);
const _white  = Colors.white;
const _t1     = Color(0xFF1E1B4B);
const _t2     = Color(0xFF64748B);
const _t3     = Color(0xFF94A3B8);
const _border = Color(0xFFEDE9FE);

class HelperNavigationMapScreen extends StatefulWidget {
  final LatLng?   destination;
  final String    destinationAddress;
  final Position? helperCurrentPos;

  const HelperNavigationMapScreen({
    super.key,
    this.destination,
    this.destinationAddress = '',
    this.helperCurrentPos,
  });

  @override
  State<HelperNavigationMapScreen> createState() =>
      _HelperNavigationMapScreenState();
}

class _HelperNavigationMapScreenState
    extends State<HelperNavigationMapScreen> {
  GoogleMapController? _mapCtrl;

  LatLng? _helperPos;
  LatLng? _destPos;
  String  _destAddress = '';
  bool    _loading     = true;
  String  _distanceText = '';
  String  _etaText      = '';

  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  static const _mapStyle = '''[
    {"featureType":"poi","elementType":"labels",
     "stylers":[{"visibility":"off"}]},
    {"featureType":"transit","elementType":"labels.icon",
     "stylers":[{"visibility":"off"}]}
  ]''';

  @override
  void initState() {
    super.initState();
    _destAddress = widget.destinationAddress;
    _destPos     = widget.destination;
    _init();
  }

  @override
  void dispose() {
    _mapCtrl?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    // Use cached position immediately if available
    if (widget.helperCurrentPos != null) {
      _helperPos = LatLng(
        widget.helperCurrentPos!.latitude,
        widget.helperCurrentPos!.longitude,
      );
    }

    // Fetch fresh GPS
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.denied) {
          perm = await Geolocator.requestPermission();
        }
        if (perm != LocationPermission.denied &&
            perm != LocationPermission.deniedForever) {
          final pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
          _helperPos = LatLng(pos.latitude, pos.longitude);
        }
      }
    } catch (_) {}

    // Geocode address if no GeoPoint was passed
    if (_destPos == null && _destAddress.isNotEmpty) {
      try {
        final locs = await locationFromAddress(_destAddress);
        if (locs.isNotEmpty) {
          _destPos = LatLng(locs.first.latitude, locs.first.longitude);
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() => _loading = false);

    if (_helperPos != null && _destPos != null) {
      _buildMarkersAndRoute();
      // Fit after map is created
      Future.delayed(const Duration(milliseconds: 600), _fitBounds);
    }
  }

  void _buildMarkersAndRoute() {
    if (_helperPos == null || _destPos == null) return;

    final dist = Geolocator.distanceBetween(
      _helperPos!.latitude, _helperPos!.longitude,
      _destPos!.latitude,   _destPos!.longitude,
    );
    final mins = ((dist / 1000) / 30 * 60).round();

    _distanceText = dist < 1000
        ? '${dist.round()} m'
        : '${(dist / 1000).toStringAsFixed(1)} km';
    _etaText = mins < 1 ? '< 1 min' : '$mins min${mins > 1 ? "s" : ""}';

    _markers = {
      Marker(
        markerId: const MarkerId('helper'),
        position: _helperPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueViolet),
        infoWindow: const InfoWindow(title: 'You'),
      ),
      Marker(
        markerId: const MarkerId('dest'),
        position: _destPos!,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Customer',
          snippet: _destAddress.isNotEmpty ? _destAddress : null,
        ),
      ),
    };

    _polylines = {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [_helperPos!, _destPos!],
        color: _purple,
        width: 5,
        patterns: [PatternItem.dash(24), PatternItem.gap(12)],
      ),
    };

    if (mounted) setState(() {});
  }

  void _fitBounds() {
    if (_helperPos == null || _destPos == null || _mapCtrl == null) return;
    final sw = LatLng(
      math.min(_helperPos!.latitude,  _destPos!.latitude),
      math.min(_helperPos!.longitude, _destPos!.longitude),
    );
    final ne = LatLng(
      math.max(_helperPos!.latitude,  _destPos!.latitude),
      math.max(_helperPos!.longitude, _destPos!.longitude),
    );
    _mapCtrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 90),
    );
  }

  void _recenter() {
    if (_helperPos == null) return;
    _mapCtrl?.animateCamera(
      CameraUpdate.newCameraPosition(
          CameraPosition(target: _helperPos!, zoom: 15)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeB   = MediaQuery.of(context).padding.bottom;

    // Sheet height adapts: more space if address is long
    final sheetH = _destAddress.isNotEmpty ? 260.0 + safeB : 200.0 + safeB;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(children: [

        // ── Map or states ────────────────────────────────────────────────
        if (_loading)
          _LoadingView(safeTop: safeTop)
        else if (_helperPos == null && _destPos == null)
          _NoLocationView(onBack: () => Navigator.pop(context))
        else
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _destPos ?? _helperPos!,
              zoom: 14,
            ),
            onMapCreated: (c) {
              _mapCtrl = c;
              c.setMapStyle(_mapStyle);
              Future.delayed(
                  const Duration(milliseconds: 600), _fitBounds);
            },
            markers:               _markers,
            polylines:             _polylines,
            myLocationEnabled:     true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled:   false,
            compassEnabled:        true,
            mapToolbarEnabled:     false,
            padding: EdgeInsets.only(
                top: safeTop + 70, bottom: sheetH),
            gestureRecognizers:
            <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                      () => EagerGestureRecognizer()),
            },
          ),

        // ── Top bar ──────────────────────────────────────────────────────
        Positioned(
          top: safeTop + 10,
          left: 12, right: 12,
          child: Row(children: [
            // Back button
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3))],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: _t1, size: 18),
              ),
            ),
            const SizedBox(width: 10),

            // Title
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.09),
                      blurRadius: 10,
                      offset: const Offset(0, 3))],
                ),
                child: Row(children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: _green, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Route to Customer',
                      style: TextStyle(
                          color: _t1,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),

        // ── Fit-all FAB ──────────────────────────────────────────────────
        Positioned(
          right: 14,
          bottom: sheetH + 60,
          child: _MapFab(
            icon: Icons.fit_screen_rounded,
            onTap: _fitBounds,
          ),
        ),

        // ── Recenter FAB ─────────────────────────────────────────────────
        Positioned(
          right: 14,
          bottom: sheetH + 10,
          child: _MapFab(
            icon: Icons.my_location_rounded,
            onTap: _recenter,
          ),
        ),

        // ── Bottom info sheet ─────────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: _BottomInfoSheet(
            distanceText: _distanceText,
            etaText:      _etaText,
            address:      _destAddress,
            isLoading:    _loading,
            safeBottom:   safeB,
          ),
        ),
      ]),
    );
  }
}

// ─── Loading view ─────────────────────────────────────────────────────────────
class _LoadingView extends StatelessWidget {
  final double safeTop;
  const _LoadingView({required this.safeTop});

  @override
  Widget build(BuildContext context) => Container(
    color: _bg,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _purple.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: const CircularProgressIndicator(
              color: _purple, strokeWidth: 2.5),
        ),
        const SizedBox(height: 20),
        const Text('Getting your location…',
            style: TextStyle(
                color: _t1,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('This takes just a moment',
            style: TextStyle(color: _t2, fontSize: 12)),
      ],
    ),
  );
}

// ─── No location view ─────────────────────────────────────────────────────────
class _NoLocationView extends StatelessWidget {
  final VoidCallback onBack;
  const _NoLocationView({required this.onBack});

  @override
  Widget build(BuildContext context) => Container(
    color: _bg,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
                color: _red.withOpacity(0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.location_off_rounded,
                color: _red, size: 36),
          ),
          const SizedBox(height: 20),
          const Text('Location Unavailable',
              style: TextStyle(
                  color: _t1,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text(
            'Could not get GPS or customer location.\nPlease check permissions and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _t2, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('Go Back'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _purple,
              side: const BorderSide(color: _purple),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ─── Map FAB ──────────────────────────────────────────────────────────────────
class _MapFab extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapFab({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: _white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.13),
            blurRadius: 10,
            offset: const Offset(0, 3))],
      ),
      child: Icon(icon, color: _purple, size: 22),
    ),
  );
}

// ─── Bottom info sheet ────────────────────────────────────────────────────────
class _BottomInfoSheet extends StatelessWidget {
  final String distanceText, etaText, address;
  final bool   isLoading;
  final double safeBottom;

  const _BottomInfoSheet({
    required this.distanceText,
    required this.etaText,
    required this.address,
    required this.isLoading,
    required this.safeBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius:
        const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -6))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // ── Handle ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDEE2E6),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),

        // ── Distance + ETA chips ────────────────────────────────────────
        if (!isLoading && distanceText.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              _InfoChip(
                icon:  Icons.straighten_rounded,
                color: _purple,
                label: 'Distance',
                value: distanceText,
              ),
              const SizedBox(width: 12),
              _InfoChip(
                icon:  Icons.access_time_rounded,
                color: _green,
                label: 'Est. Time',
                value: etaText,
              ),
            ]),
          )
        else if (isLoading)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              _ShimmerChip(), const SizedBox(width: 12), _ShimmerChip(),
            ]),
          ),

        // ── Destination address card ────────────────────────────────────
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5F5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _red.withOpacity(0.18)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: _red, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CUSTOMER LOCATION',
                          style: TextStyle(
                              color: _t3,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 2),
                      Text(address,
                          style: const TextStyle(
                              color: _t1,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ]),
            ),
          ),

        // ── Route legend ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withOpacity(0.14)),
            ),
            child: Row(children: [
              // Helper dot
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(
                      color: _purple.withOpacity(0.80),
                      shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('You',
                  style: TextStyle(
                      color: _t1, fontSize: 11,
                      fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              // Dashed line
              Expanded(
                child: LayoutBuilder(builder: (_, c) {
                  final count = (c.maxWidth / 8).floor();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(count, (_) => Container(
                        width: 4, height: 2,
                        color: _purple.withOpacity(0.40))),
                  );
                }),
              ),
              const SizedBox(width: 8),
              // Dest dot
              Container(width: 10, height: 10,
                  decoration: const BoxDecoration(
                      color: _red, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Customer',
                  style: TextStyle(
                      color: _t1, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),

        SizedBox(height: safeBottom + 18),
      ]),
    );
  }
}

// ─── Info chip ────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label, value;
  const _InfoChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(
                color: _t1,
                fontSize: 16,
                fontWeight: FontWeight.w800)),
      ]),
    ),
  );
}

// ─── Shimmer chip placeholder ─────────────────────────────────────────────────
class _ShimmerChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      height: 62,
      decoration: BoxDecoration(
        color: const Color(0xFFF0EEFF),
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  );
}