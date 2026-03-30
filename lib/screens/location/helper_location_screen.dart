// lib/screens/location/helper_location_screen.dart
//
// Map-based location picker for helpers.
// • Shows Google Map with draggable pin
// • "Use Current Location" GPS button
// • Search bar for address lookup
// • On confirm: saves GeoPoint + address string to helpers/{uid} doc
// • Only accessible when helper is online (enforced by caller)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _C {
  static const purple = Color(0xFF7C3AED);
  static const indigo = Color(0xFF2D1B69);
  static const bg     = Color(0xFFF8F7FF);
  static const white  = Colors.white;
  static const t1     = Color(0xFF1E1B4B);
  static const t2     = Color(0xFF64748B);
  static const t3     = Color(0xFF94A3B8);
  static const border = Color(0xFFEDE9FE);
  static const green  = Color(0xFF16A34A);
  static const red    = Color(0xFFEF4444);
}

// ═══════════════════════════════════════════════════════════════════════════
// ENTRY WIDGET
// ═══════════════════════════════════════════════════════════════════════════
class HelperLocationScreen extends StatelessWidget {
  const HelperLocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: _C.indigo,
          title: const Text('Update Location',
              style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
            child: Text('Maps are only available on mobile.')),
      );
    }
    return const _MobileHelperPicker();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MOBILE PICKER
// ═══════════════════════════════════════════════════════════════════════════
class _MobileHelperPicker extends StatefulWidget {
  const _MobileHelperPicker();

  @override
  State<_MobileHelperPicker> createState() => _MobileHelperPickerState();
}

class _MobileHelperPickerState extends State<_MobileHelperPicker>
    with TickerProviderStateMixin {
  GoogleMapController? _mapCtrl;

  late AnimationController _pinCtrl;
  late Animation<double>   _pinBounce;

  final TextEditingController _searchCtrl = TextEditingController();

  LatLng _center       = const LatLng(21.1702, 72.8311); // Surat default
  String _primaryLine  = 'Tap map or use GPS';
  String _secondaryLine = '';
  bool   _isGeocoding  = false;
  bool   _isSaving     = false;
  bool   _isSearching  = false;
  List<Location> _suggestions = [];
  bool   _showSugg    = false;
  MapType _mapType    = MapType.normal;

  static const _mapStyle = '''[
    {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
    {"featureType":"transit","elementType":"labels","stylers":[{"visibility":"off"}]}
  ]''';

  @override
  void initState() {
    super.initState();
    _pinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _pinBounce = Tween<double>(begin: 0, end: -14)
        .animate(CurvedAnimation(parent: _pinCtrl, curve: Curves.easeOut));
    _goToCurrent();
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _mapCtrl?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Map callbacks ─────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController c) {
    _mapCtrl = c;
    c.setMapStyle(_mapStyle);
  }

  void _onCameraMove(CameraPosition _) {
    if (!_pinCtrl.isAnimating) _pinCtrl.forward();
  }

  void _onCameraIdle() {
    if (_mapCtrl == null) return;
    final size   = MediaQuery.of(context).size;
    final sheetH = size.height * 0.36;
    _mapCtrl!
        .getLatLng(ScreenCoordinate(
      x: (size.width / 2).round(),
      y: ((size.height - sheetH) / 2).round(),
    ))
        .then(_reverseGeocode);
  }

  // ── Geocoding ─────────────────────────────────────────────────────────────

  Future<void> _reverseGeocode(LatLng pos) async {
    _center = pos;
    setState(() => _isGeocoding = true);
    _pinCtrl.forward();
    try {
      final marks = await placemarkFromCoordinates(
          pos.latitude, pos.longitude);
      if (marks.isNotEmpty && mounted) {
        final p = marks.first;
        final street = [
          p.subThoroughfare ?? '',
          p.thoroughfare ?? ''
        ].where((s) => s.isNotEmpty).join(' ').trim();

        setState(() {
          _primaryLine = street.isNotEmpty
              ? street
              : (p.subLocality ?? p.locality ?? 'Unknown location');
          _secondaryLine = [
            p.subLocality ?? '',
            p.locality ?? '',
            p.administrativeArea ?? '',
          ].where((s) => s.isNotEmpty).join(', ');
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _primaryLine  = pos.latitude.toStringAsFixed(5);
          _secondaryLine = pos.longitude.toStringAsFixed(5);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isGeocoding = false);
        _pinCtrl.reverse();
      }
    }
  }

  // ── Get current GPS location ──────────────────────────────────────────────

  Future<void> _goToCurrent() async {
    HapticFeedback.lightImpact();
    setState(() => _isGeocoding = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showErr('Location service is disabled.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showErr('Location permission denied.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final latlng = LatLng(pos.latitude, pos.longitude);
      _mapCtrl?.animateCamera(
          CameraUpdate.newCameraPosition(
              CameraPosition(target: latlng, zoom: 16)));
      await _reverseGeocode(latlng);
    } catch (e) {
      _showErr('GPS error. Try moving to an open area.');
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  // ── Search ────────────────────────────────────────────────────────────────

  Future<void> _onSearch(String q) async {
    if (q.length < 3) {
      setState(() { _suggestions = []; _showSugg = false; });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final res = await locationFromAddress(q);
      if (mounted) setState(() {
        _suggestions = res;
        _showSugg    = res.isNotEmpty;
      });
    } catch (_) {
      if (mounted) setState(() { _suggestions = []; _showSugg = false; });
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSuggestion(Location loc) {
    FocusScope.of(context).unfocus();
    setState(() => _showSugg = false);
    final latlng = LatLng(loc.latitude, loc.longitude);
    _mapCtrl?.animateCamera(
        CameraUpdate.newLatLngZoom(latlng, 16));
    _reverseGeocode(latlng);
  }

  // ── Confirm & save ────────────────────────────────────────────────────────

  Future<void> _confirm() async {
    HapticFeedback.mediumImpact();
    final uid = fb.FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) { _showErr('Not logged in.'); return; }

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('helpers').doc(uid).update({
        'location': GeoPoint(_center.latitude, _center.longitude),
        'locationAddress': '$_primaryLine, $_secondaryLine'.trim(),
        'locationUpdatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          SizedBox(width: 10),
          Text('Location updated!',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ));
      // Also refresh provider if needed
      if (mounted) context.read<AuthProvider>().refreshProfile();
      Navigator.pop(context);
    } catch (e) {
      _showErr('Save failed: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showErr(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white)),
      backgroundColor: _C.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size   = MediaQuery.of(context).size;
    final sheetH = size.height * 0.36;
    final safeB  = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _C.bg,
      body: Stack(children: [

        // ── Google Map ────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: 15),
          onMapCreated: _onMapCreated,
          onCameraMove: _onCameraMove,
          onCameraIdle: _onCameraIdle,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: true,
          mapToolbarEnabled: false,
          padding: EdgeInsets.only(bottom: sheetH),
          mapType: _mapType,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
          },
        ),

        // ── Animated center pin ───────────────────────────────────────────
        Positioned(
          left: 0, right: 0,
          top: ((size.height - sheetH) / 2) - 56,
          child: IgnorePointer(
            child: Center(
              child: AnimatedBuilder(
                animation: _pinBounce,
                builder: (_, __) => Transform.translate(
                  offset: Offset(0, _pinBounce.value),
                  child: const _MapPin(),
                ),
              ),
            ),
          ),
        ),

        // ── "Set Location" floating label ─────────────────────────────────
        Positioned(
          left: 0, right: 0,
          top: ((size.height - sheetH) / 2) - 98,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 9),
                decoration: BoxDecoration(
                  color: _C.purple,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(
                      color: _C.purple.withOpacity(0.4),
                      blurRadius: 12, offset: const Offset(0, 4))],
                ),
                child: const Text('Set Helper Location',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700,
                        fontSize: 12, letterSpacing: 0.3)),
              ),
            ),
          ),
        ),

        // ── Search bar + suggestions ──────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Search row
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _C.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 16, offset: const Offset(0, 4))],
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Icon(Icons.arrow_back_ios_rounded,
                          color: _C.t1, size: 20),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearch,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: _C.t1),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Search area or address...',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 14),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: _isSearching
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _C.purple))
                        : GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _showSugg = false);
                      },
                      child: Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                            color: const Color(0xFFDEE2E6),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded,
                            color: _C.t2, size: 14),
                      ),
                    ),
                  ),
                ]),
              ),

              // Suggestions dropdown
              if (_showSugg && _suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: _C.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length.clamp(0, 4),
                    separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    itemBuilder: (_, i) {
                      final loc = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: const Icon(Icons.location_on_rounded,
                            color: _C.purple, size: 20),
                        title: Text(
                          '${loc.latitude.toStringAsFixed(4)}, '
                              '${loc.longitude.toStringAsFixed(4)}',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                        onTap: () => _selectSuggestion(loc),
                      );
                    },
                  ),
                ),
            ]),
          ),
        ),

        // ── Satellite toggle ──────────────────────────────────────────────
        Positioned(
          right: 16, bottom: sheetH + 80,
          child: _FabBtn(
            icon: _mapType == MapType.normal
                ? Icons.satellite_alt
                : Icons.map_outlined,
            onTap: () => setState(() {
              _mapType = _mapType == MapType.normal
                  ? MapType.satellite
                  : MapType.normal;
              if (_mapType == MapType.normal && _mapCtrl != null) {
                _mapCtrl!.setMapStyle(_mapStyle);
              }
            }),
          ),
        ),

        // ── GPS button ────────────────────────────────────────────────────
        Positioned(
          right: 16, bottom: sheetH + 16,
          child: _FabBtn(
            icon: Icons.my_location_rounded,
            loading: _isGeocoding,
            onTap: _goToCurrent,
          ),
        ),

        // ── Bottom sheet ──────────────────────────────────────────────────
        Align(
          alignment: Alignment.bottomCenter,
          child: _BottomSheet(
            primaryLine:   _isGeocoding ? 'Locating…'   : _primaryLine,
            secondaryLine: _isGeocoding ? ''             : _secondaryLine,
            isLoading: _isGeocoding,
            isSaving:  _isSaving,
            safeBottom: safeB,
            onConfirm: _confirm,
            onChangeTap: _goToCurrent,
          ),
        ),
      ]),
    );
  }
}

// ─── Map pin ──────────────────────────────────────────────────────────────
class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: _C.purple,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(
              color: _C.purple.withOpacity(0.5),
              blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: const Icon(Icons.location_on_rounded,
            color: Colors.white, size: 26),
      ),
      CustomPaint(size: const Size(16, 10),
          painter: _TailPainter()),
      Container(
        width: 10, height: 4,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ],
  );
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(size.width / 2 - 6, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width / 2 + 6, 0)
        ..close(),
      Paint()..color = _C.purple,
    );
  }
  @override bool shouldRepaint(_) => false;
}

// ─── Floating action button ───────────────────────────────────────────────
class _FabBtn extends StatelessWidget {
  final IconData icon;
  final bool loading;
  final VoidCallback onTap;

  const _FabBtn({
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        color: _C.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: loading
          ? const Center(
          child: SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: _C.purple)))
          : Icon(icon, color: _C.purple, size: 24),
    ),
  );
}

// ─── Bottom sheet ─────────────────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final String primaryLine, secondaryLine;
  final bool isLoading, isSaving;
  final double safeBottom;
  final VoidCallback onConfirm, onChangeTap;

  const _BottomSheet({
    required this.primaryLine,
    required this.secondaryLine,
    required this.isLoading,
    required this.isSaving,
    required this.safeBottom,
    required this.onConfirm,
    required this.onChangeTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: _C.white,
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      boxShadow: [BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 30, offset: Offset(0, -8))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: 40, height: 4,
          decoration: BoxDecoration(
              color: const Color(0xFFDEE2E6),
              borderRadius: BorderRadius.circular(2)),
        ),
      ),
      const SizedBox(height: 20),

      // Address row
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
                color: _C.purple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.location_on_rounded,
                color: _C.purple, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('YOUR HELPER LOCATION',
                style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
                    color: _C.t3, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            isLoading
                ? _Shimmer(width: 200, height: 18)
                : Text(primaryLine,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700,
                    color: _C.t1, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            isLoading
                ? _Shimmer(width: 140, height: 13)
                : Text(secondaryLine,
                style: const TextStyle(fontSize: 12, color: _C.t2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ])),
          TextButton(
            onPressed: onChangeTap,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 4)),
            child: const Text('GPS',
                style: TextStyle(
                    color: _C.purple,
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ]),
      ),

      const SizedBox(height: 8),

      // Info note
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: _C.purple.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _C.purple.withOpacity(0.15))),
          child: Row(children: const [
            Icon(Icons.info_outline_rounded,
                color: _C.purple, size: 14),
            SizedBox(width: 8),
            Expanded(child: Text(
              'This location helps customers find you nearby.',
              style: TextStyle(
                  color: _C.t2, fontSize: 11, height: 1.4),
            )),
          ]),
        ),
      ),

      const SizedBox(height: 18),

      // Confirm button
      Padding(
        padding: EdgeInsets.only(
            left: 24, right: 24, bottom: safeBottom + 20),
        child: SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            onPressed: isSaving || isLoading ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.purple,
              disabledBackgroundColor: _C.purple.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: isSaving
                ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded,
                    size: 20, color: Colors.white),
                SizedBox(width: 10),
                Text('Confirm My Location',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    ]),
  );
}

// ─── Shimmer ──────────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width, height;
  const _Shimmer({required this.width, required this.height});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this)
      ..repeat(reverse: true);
    _a = Tween<double>(begin: 0.3, end: 0.8)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(
        color: Color.lerp(
            const Color(0xFFE9ECEF), const Color(0xFFF8F9FA), _a.value),
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}