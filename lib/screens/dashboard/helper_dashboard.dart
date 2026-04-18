import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/booking_chat_service.dart';
import '../schedule/schedule_screen.dart';
import '../location/helper_location_screen.dart';

import '../../theme/app_theme.dart';
import '../trust/trust_safety_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/helper_model.dart';
import '../../utils/smooth_route.dart';
import '../kyc/kyc_screen.dart';
import '../bookings/incoming_booking_detail.dart';
import '../jobs/job_history_screen.dart';
import '../support/support_screen.dart';
import '../earning/earnings_screen.dart';
import '../profile/helper_profile_screen.dart';
import '../../widgets/notification_bell.dart';

// ─── Unified booking status constants ────────────────────────────────────────
// NEVER use: active, declined, timeout, navigating, started, completing,
//            done, in_progress — only these 5 values are valid:
// pending → accepted → ongoing → completed → cancelled
class _Status {
  static const pending   = 'booked';   // user app writes 'booked'
  static const accepted  = 'accepted';
  static const arrived   = 'arrived';  // ← NEW: helper at location, not yet started
  static const ongoing   = 'ongoing';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

// ─── Light-only palette ──────────────────────────────────────────────────────
class _P {
  static const bg     = Color(0xFFF8F7FF);
  static const white  = Colors.white;
  static const purple = Color(0xFF7C3AED);
  static const indigo = Color(0xFF2D1B69);
  static const violet = Color(0xFF5B21B6);
  static const green  = Color(0xFF16A34A);
  static const amber  = Color(0xFFF59E0B);
  static const red    = Color(0xFFEF4444);
  static const t1     = Color(0xFF1E1B4B);
  static const t2     = Color(0xFF64748B);
  static const t3     = Color(0xFF94A3B8);
  static const border = Color(0xFFEDE9FE);
  static const div    = Color(0xFFF1F0FF);
}

double _safeDouble(dynamic v) =>
    v == null ? 0.0 : v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

int _safeInt(dynamic v) =>
    v == null ? 0 : v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;

// ─── Amount helper: NEVER show platformFee to helper — only baseAmount ───────
// platformFee is app revenue and must stay internal / admin-only.
double _helperAmount(Map<String, dynamic> d) =>
    _safeDouble(d['baseAmount']);

// ─── Payment method badge ────────────────────────────────────────────────────
Widget _paymentBadge(String? method) {
  final isCash = (method ?? 'Cash') == 'Cash';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: (isCash ? _P.green : _P.purple).withOpacity(0.10),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: (isCash ? _P.green : _P.purple).withOpacity(0.25),
      ),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        isCash ? Icons.payments_rounded : Icons.phone_android_rounded,
        size: 11,
        color: isCash ? _P.green : _P.purple,
      ),
      const SizedBox(width: 4),
      Text(
        isCash ? 'Cash' : 'UPI',
        style: TextStyle(
          color: isCash ? _P.green : _P.purple,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ROOT SCAFFOLD
// ═══════════════════════════════════════════════════════════════════════════
class HelperDashboard extends StatefulWidget {
  final bool bypassKycGate;
  const HelperDashboard({super.key, this.bypassKycGate = false});
  @override
  State<HelperDashboard> createState() => _HelperDashboardState();
}

class _HelperDashboardState extends State<HelperDashboard>
    with SingleTickerProviderStateMixin {

  int _tab = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  StreamSubscription<Position>? _locSub;
  Position? _myPos;

  StreamSubscription<QuerySnapshot>? _badgeSub;
  int _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().refreshProfile();
      _initLocation();
      _initBadge();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _locSub?.cancel();
    _badgeSub?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) return;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _pushLocation(pos);
    } catch (_) {}
    _locSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 15),
    ).listen(_pushLocation);
  }

  void _pushLocation(Position pos) {
    if (mounted) setState(() => _myPos = pos);
    final uid = context.read<AuthProvider>().helper?.uid ?? '';
    if (uid.isEmpty) return;
    FirebaseFirestore.instance.collection('helpers').doc(uid).update({
      'location': GeoPoint(pos.latitude, pos.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  // AFTER — counts only THIS helper's bookings
  void _initBadge() {
    final uid = context.read<AuthProvider>().helper?.uid ?? '';
    if (uid.isEmpty) return;
    _badgeSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: uid)
        .where('status', whereIn: ['booked', 'pending'])
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _pendingCount = s.docs.length);
    });
  }

  void _switchTab(int i) {
    if (_tab == i) return;
    HapticFeedback.selectionClick();
    _fadeCtrl.reset();
    setState(() => _tab = i);
    _fadeCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final helper = context.watch<AuthProvider>().helper;

    if (helper != null && !widget.bypassKycGate) {
      if (helper.isPending)   return _KycPending(helper: helper);
      if (helper.isSubmitted) return _KycUnderReview(helper: helper);
      if (helper.isRejected)  return _KycRejected(helper: helper);
      if (helper.isInactive)  return _KycInactive(helper: helper);
    }
    // bypassKycGate == true → fall through to normal dashboard

    final lang = context.watch<LanguageProvider>();

    final pages = [
      _JobsTab(myPos: _myPos, pendingCount: _pendingCount, onGoHome: () => _switchTab(1)),
      _HomeTab(myPos: _myPos, onGoJobs: () => _switchTab(0), pendingCount: _pendingCount),
      const EarningsScreen(),
      const TrustSafetyScreen(),
      const HelperProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: _P.bg,
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: _BottomNav(
        selected: _tab,
        onSelect: _switchTab,
        lang: lang,
        badge: _pendingCount,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM NAV
// ═══════════════════════════════════════════════════════════════════════════
class _BottomNav extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  final LanguageProvider lang;
  final int badge;
  const _BottomNav({
    required this.selected, required this.onSelect,
    required this.lang, required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final hi = lang.isHindi;

    return Container(
      color: Colors.transparent,
      height: 82 + bottom,
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // ── Floating pill ──────────────────────────────────────────────
          Positioned(
            bottom: bottom + 10,
            left: 18,
            right: 18,
            child: Container(
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [
                  BoxShadow(
                    color: _P.purple.withOpacity(0.13),
                    blurRadius: 30,
                    spreadRadius: 0,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _pill(0, Icons.work_rounded, Icons.work_outline_rounded,
                      hi ? 'काम' : 'Jobs', showBadge: true),
                  _pill(1, Icons.home_rounded, Icons.home_outlined,
                      hi ? 'होम' : 'Home'),
                  const SizedBox(width: 58),
                  _pill(3, Icons.shield_rounded, Icons.shield_outlined,
                      hi ? 'ट्रस्ट' : 'Trust'),
                  _pill(4, Icons.person_rounded, Icons.person_outline_rounded,
                      hi ? 'मैं' : 'Me'),
                ],
              ),
            ),
          ),

          // ── Centre elevated Earn button ────────────────────────────────
          Positioned(
            bottom: bottom + 18,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onSelect(2);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: selected == 2
                        ? [const Color(0xFF5B21B6), const Color(0xFF7C3AED)]
                        : [const Color(0xFF7C3AED), const Color(0xFF9D6FE8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _P.purple.withOpacity(selected == 2 ? 0.55 : 0.28),
                      blurRadius: selected == 2 ? 24 : 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected == 2
                          ? Icons.wallet_rounded
                          : Icons.wallet_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hi ? 'कमाई' : 'Earn',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(int index, IconData fill, IconData out, String label,
      {bool showBadge = false}) {
    final sel = selected == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onSelect(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: sel ? _P.purple.withOpacity(0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                sel ? fill : out,
                key: ValueKey(sel),
                size: 22,
                color: sel ? _P.purple : _P.t3,
              ),
            ),
            if (showBadge && badge > 0)
              Positioned(
                top: -5, right: -8,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: _P.red,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badge > 9 ? '9+' : '$badge',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 8,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 3),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 9,
              fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
              color: sel ? _P.purple : _P.t3,
              letterSpacing: 0.3,
            ),
            child: Text(label),
          ),
        ]),
      ),
    );
  }
}

// ── Shared tab header ─────────────────────────────────────────────────────
class _TabHeader extends StatelessWidget {
  final HelperModel? helper;
  final bool isOnline, isHindi;
  const _TabHeader(
      {required this.helper, required this.isOnline, required this.isHindi});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      bottom: 14, left: 16, right: 16,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_P.indigo, _P.violet, _P.purple],
      ),
    ),
    child: Row(children: [
      Container(
        width: 42, height: 42,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2)),
        child: Center(child: Text(helper?.initials ?? 'SK',
            style: const TextStyle(color: Colors.white,
                fontSize: 14, fontWeight: FontWeight.w800))),
      ),
      const SizedBox(width: 11),
      Expanded(child: Text(helper?.name ?? 'Helper',
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(
              color: isOnline ? AppColors.onlineGreen : Colors.white38,
              shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(isOnline
              ? (isHindi ? 'ऑनलाइन' : 'ONLINE')
              : (isHindi ? 'ऑफलाइन' : 'OFFLINE'),
              style: const TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(width: 10),
      const NotificationBell(isDark: false),
    ]),
  );
}

// ── Status banner ─────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final HelperModel? helper;
  final int count;
  final bool isHindi;
  const _StatusBanner(
      {required this.helper, required this.count, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    final isOnline = helper?.isOnline ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isOnline
                ? AppColors.onlineGreen.withOpacity(0.25)
                : _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: (isOnline ? AppColors.onlineGreen : _P.t3).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.wifi_tethering_rounded,
              color: isOnline ? AppColors.onlineGreen : _P.t3, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isOnline
              ? (isHindi ? 'आप ऑनलाइन हैं' : "You're Online")
              : (isHindi ? 'आप ऑफलाइन हैं' : "You're Offline"),
              style: const TextStyle(
                  color: _P.t1, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(count > 0
              ? '$count ${isHindi ? 'अनुरोध पास में' : 'Request${count > 1 ? "s" : ""} nearby'}'
              : (isHindi ? 'पास में कोई अनुरोध नहीं' : 'No requests nearby'),
              style: const TextStyle(color: _P.t2, fontSize: 11)),
        ])),
        _OnlineToggleBtn(helper: helper, isHindi: isHindi, isOnline: isOnline),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIX 10 — ONGOING JOB SECTION (Firestore-driven, no local _JobStage enum)
// status == 'accepted' → show Start Job button (no timer)
// status == 'ongoing'  → show live elapsed timer + Mark Complete
// ═══════════════════════════════════════════════════════════════════════════
class _OngoingJobSection extends StatelessWidget {
  final String uid;
  final bool isHindi;
  const _OngoingJobSection({required this.uid, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    // ✅ Stream now includes 'arrived' status
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', whereIn: [
        _Status.accepted,
        _Status.arrived,
        _Status.ongoing,
      ])
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final doc    = snap.data!.docs.first;
        final d      = doc.data() as Map<String, dynamic>;
        final status = d['status'] as String? ?? _Status.accepted;

        // Chip config per status
        final (chipLabel, chipColor) = switch (status) {
          _Status.ongoing  => ('IN PROGRESS', AppColors.onlineGreen),
          _Status.arrived  => ('ARRIVED', _P.amber),
          _              => ('ACCEPTED', _P.purple),
        };

        final sectionTitle = switch (status) {
          _Status.ongoing => 'ONGOING JOB',
          _Status.arrived => 'JOB IN PROGRESS',
          _             => 'UPCOMING TODAY',
        };

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(
              sectionTitle,
              style: const TextStyle(
                  color: _P.t1, fontSize: 20,
                  fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
            _Chip(
              label: chipLabel,
              bg: chipColor.withOpacity(0.12),
              fg: chipColor,
            ),
          ]),
          const SizedBox(height: 12),
          _OngoingCard(
            bookingId: doc.id,
            data: d,
            uid: uid,
            isHindi: isHindi,
          ),
          const SizedBox(height: 26),
        ]);
      },
    );
  }
}

// ── Ongoing card — driven entirely by Firestore status field ─────────────
class _OngoingCard extends StatefulWidget {
  final String bookingId, uid;
  final Map<String, dynamic> data;
  final bool isHindi;
  const _OngoingCard({
    required this.bookingId, required this.uid,
    required this.data, required this.isHindi,
  });
  @override
  State<_OngoingCard> createState() => _OngoingCardState();
}

class _OngoingCardState extends State<_OngoingCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _actionBusy = false;

  String get _status =>
      widget.data['status'] as String? ?? _Status.accepted;

  bool get _isAccepted => _status == _Status.accepted;
  bool get _isArrived  => _status == _Status.arrived;
  bool get _isOngoing  => _status == _Status.ongoing;

  @override
  void initState() {
    super.initState();
    if (_isOngoing) _startTimer();
  }

  @override
  void didUpdateWidget(_OngoingCard old) {
    super.didUpdateWidget(old);
    final wasOngoing = old.data['status'] == _Status.ongoing;
    if (_isOngoing && !wasOngoing) _startTimer();
    if (!_isOngoing && wasOngoing) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    if (!_isOngoing) return;
    final start =
        (widget.data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    _elapsed = DateTime.now().difference(start);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _clock {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── Notify user helper ────────────────────────────────────────────────────
  Future<void> _notifyUser(
      String type, String title, String body) async {
    final userId = widget.data['userId'] as String? ?? '';
    if (userId.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .add({
      'type':      type,
      'title':     title,
      'body':      body,
      'bookingId': widget.bookingId,
      'read':      false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Step 1: Mark Arrived ──────────────────────────────────────────────────
  Future<void> _markArrived() async {
    setState(() => _actionBusy = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status':                   _Status.arrived,
        'arrivedAt':                FieldValue.serverTimestamp(),
        'statusTimestamps.arrived': FieldValue.serverTimestamp(), // ← syncs user timeline
      });
      final helperName =
          widget.data['helperName'] as String? ?? 'Your helper';
      await _notifyUser(
        'helper_arrived',
        'Helper has Arrived! 📍',
        '$helperName has arrived at your location.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Arrival confirmed — customer notified!'),
          ]),
          backgroundColor: _P.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  // ── Step 2: Start Job ─────────────────────────────────────────────────────
  Future<void> _startJob() async {
    setState(() => _actionBusy = true);
    try {
      final db    = FirebaseFirestore.instance;
      await db.collection('bookings').doc(widget.bookingId).update({
        'status':                        _Status.ongoing,
        'startedAt':                     FieldValue.serverTimestamp(),
        'statusTimestamps.inProgress':   FieldValue.serverTimestamp(), // ← syncs user timeline
      });
      final svcName =
          widget.data['serviceName'] as String? ?? 'service';
      await _notifyUser(
        'job_started',
        'Work has Started! 🔧',
        'Your $svcName has officially started.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.play_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Job started — timer running!'),
          ]),
          backgroundColor: _P.purple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  // ── Step 3: Mark Complete ─────────────────────────────────────────────────
  Future<void> _complete() async {
    setState(() => _actionBusy = true);
    try {
      final db    = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('bookings').doc(widget.bookingId), {
        'status':      _Status.completed,
        'completedAt': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('helpers').doc(widget.uid), {
        'completedJobs': FieldValue.increment(1),
      });
      await batch.commit();
      final svcName =
          widget.data['serviceName'] as String? ?? 'service';
      await _notifyUser(
        'job_completed',
        'Job Completed! 🎉',
        'Your $svcName has been completed. Please confirm and rate.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Job marked complete!'),
          ]),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _reply(String msg) async {
    HapticFeedback.lightImpact();
    final db    = FirebaseFirestore.instance;
    final batch = db.batch();
    final ref   = db.collection('chats').doc(widget.bookingId)
        .collection('messages').doc();
    batch.set(ref, {
      'text': msg, 'senderId': widget.uid,
      'senderType': 'helper', 'isQuickReply': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(db.collection('chats').doc(widget.bookingId), {
      'lastMessage': msg,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastSenderId': widget.uid,
    }, SetOptions(merge: true));
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"$msg" sent'),
      backgroundColor: _P.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _openMaps() async {
    final loc  = widget.data['userLocation'] as GeoPoint?;
    final addr = widget.data['address'] as String?
        ?? widget.data['userAddress'] as String? ?? '';
    Uri uri;
    if (loc != null) {
      uri = Uri.parse(
          'https://maps.google.com/?q=${loc.latitude},${loc.longitude}');
    } else if (addr.isNotEmpty) {
      uri = Uri.parse(
          'https://maps.google.com/?q=${Uri.encodeComponent(addr)}');
    } else {
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Action button factory ─────────────────────────────────────────────────
  Widget _buildActionButton() {
    if (_isOngoing) {
      return SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton.icon(
          onPressed: _actionBusy ? null : _complete,
          icon: _actionBusy
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 22),
          label: Text(
            widget.isHindi ? 'काम पूरा करें' : 'Mark Complete',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF166534),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }
    if (_isArrived) {
      return SizedBox(
        width: double.infinity, height: 56,
        child: ElevatedButton.icon(
          onPressed: _actionBusy ? null : _startJob,
          icon: _actionBusy
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_circle_filled_rounded, size: 22),
          label: Text(
            widget.isHindi ? 'काम शुरू करें' : 'Start Work',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _P.purple,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),
      );
    }
    // accepted
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton.icon(
        onPressed: _actionBusy ? null : _markArrived,
        icon: _actionBusy
            ? const SizedBox(width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.location_on_rounded, size: 22),
        label: Text(
          widget.isHindi ? 'मैं पहुँच गया' : "I've Arrived",
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF59E0B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d       = widget.data;
    final address = d['address'] as String?
        ?? d['userAddress'] as String? ?? '';
    final amount  = _helperAmount(d);
    final svc     = d['serviceName'] as String? ?? 'Service';
    final replies = widget.isHindi
        ? ['मैं रास्ते पर हूँ', 'पहुँच गया', 'काम शुरू हुआ', '5 मिनट में आता हूँ']
        : ["I'm on my way", 'Arrived at location', 'Job started', '5 mins away'];
    final scheduledAt =
    (d['scheduledAt'] as Timestamp?)?.toDate().toLocal();
    final schedStr = scheduledAt != null
        ? DateFormat('d MMM, h:mm a').format(scheduledAt)
        : '';

    // Header gradient changes per status
    final headerColors = _isOngoing
        ? [const Color(0xFF064E3B), const Color(0xFF166534)]
        : _isArrived
        ? [const Color(0xFF78350F), const Color(0xFFB45309)]
        : [_P.indigo, _P.violet];

    return Container(
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _P.border),
        boxShadow: [
          BoxShadow(
            color: _P.purple.withOpacity(0.09),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [

        // ── Gradient header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: headerColors,
            ),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status pill + payment badge
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _isOngoing
                            ? AppColors.onlineGreen
                            : _isArrived
                            ? _P.amber
                            : Colors.white70,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isOngoing
                          ? (widget.isHindi ? 'जारी है' : 'IN PROGRESS')
                          : _isArrived
                          ? (widget.isHindi ? 'पहुँच गए' : 'ARRIVED')
                          : (widget.isHindi ? 'आगामी' : 'UPCOMING'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ]),
                ),
                const Spacer(),
                _paymentBadge(d['paymentMethod'] as String?),
              ]),
              const SizedBox(height: 14),

              // Service name
              Text(
                svc,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Timer (ongoing) or scheduled time + amount
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_isOngoing) ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _clock,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Text(
                          'ELAPSED TIME',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SCHEDULED FOR',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          schedStr.isNotEmpty ? schedStr : '—',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const Text(
                        'YOUR EARNING',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Booking progress stepper ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _BookingProgressStepper(
            status: _status,
            isHindi: widget.isHindi,
          ),
        ),

        // ── Destination ──────────────────────────────────────────────────
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _P.border),
              ),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _P.red.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.location_on_rounded,
                      color: _P.red, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DESTINATION',
                        style: TextStyle(
                          color: _P.t3,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        address,
                        style: const TextStyle(
                          color: _P.t1,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _openMaps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _P.purple.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _P.purple.withOpacity(0.20)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_rounded,
                            size: 13, color: _P.purple),
                        SizedBox(width: 4),
                        Text(
                          'Maps',
                          style: TextStyle(
                            color: _P.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

        // ── Quick replies (ongoing only) ─────────────────────────────────
        if (_isOngoing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUICK REPLIES',
                  style: TextStyle(
                    color: _P.t3,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: replies.map((r) => GestureDetector(
                    onTap: () => _reply(r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: _P.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFDDD6FE)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        r,
                        style: const TextStyle(
                          color: _P.t2,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),

        // ── Action button ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildActionButton(),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIX 4 — UPCOMING JOBS SECTION
// Query: helperId == uid AND status == 'accepted' AND scheduledAt > now
// Shown between _OngoingJobSection and _PendingList
// ═══════════════════════════════════════════════════════════════════════════
class _UpcomingJobsSection extends StatelessWidget {
  final String uid;
  final bool isHindi;
  const _UpcomingJobsSection({required this.uid, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    final now = Timestamp.now();
    // REQUIRES COMPOSITE INDEX: helperId ASC + status ASC + scheduledAt ASC
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: _Status.accepted)
          .where('scheduledAt', isGreaterThan: now)
          .orderBy('scheduledAt')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final docs = snap.data!.docs;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SecHead(
            title: isHindi ? 'आगामी काम' : 'Upcoming Jobs',
            badge: '${docs.length}',
          ),
          const SizedBox(height: 12),
          ...docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final svc = d['serviceName'] as String? ?? 'Service';
            final addr = d['address'] as String? ?? '';
            final amount = _helperAmount(d);
            final scheduledAt = (d['scheduledAt'] as Timestamp?)?.toDate().toLocal();
            final dateStr = scheduledAt != null
                ? DateFormat('EEE, d MMM').format(scheduledAt)
                : '';
            final timeStr = scheduledAt != null
                ? DateFormat('h:mm a').format(scheduledAt)
                : '';

            return Container(
              key: ValueKey(doc.id),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _P.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _P.border),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: _P.purple.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.event_available_rounded,
                      color: _P.purple, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(svc,
                      style: const TextStyle(
                          color: _P.t1, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$dateStr · $timeStr',
                      style: const TextStyle(
                          color: _P.purple, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (addr.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(addr,
                        style: const TextStyle(color: _P.t2, fontSize: 11),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _P.t1, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  _paymentBadge(d['paymentMethod'] as String?),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 6),
        ]);
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIX 2 — PENDING LIST (flicker-free with _cached pattern)
// ═══════════════════════════════════════════════════════════════════════════
class _PendingList extends StatefulWidget {
  final String uid;
  final bool isHindi;
  final Position? myPos;
  const _PendingList({required this.uid, required this.isHindi, this.myPos});
  @override
  State<_PendingList> createState() => _PendingListState();
}

class _PendingListState extends State<_PendingList> {
  List<QueryDocumentSnapshot> _cached = [];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      key: const PageStorageKey('pending_list'),
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: widget.uid)
          .where('status', whereIn: ['booked', 'pending'])
          .limit(15)
          .snapshots(),
      builder: (ctx, snap) {
        // ✅ FIX: always update cache — including when it becomes EMPTY
        // Old code only updated when docs were non-empty, so accepted jobs
        // stayed visible because _cached was never cleared.
        if (snap.hasData) {
          if (snap.data!.docs.isEmpty) {
            _cached = [];
          } else {
            _cached = List<QueryDocumentSnapshot>.from(snap.data!.docs)
              ..sort((a, b) {
                final ta = ((a.data() as Map)['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ?? 0;
                final tb = ((b.data() as Map)['createdAt'] as Timestamp?)
                    ?.millisecondsSinceEpoch ?? 0;
                return tb.compareTo(ta);
              });
          }
        }

        if (_cached.isEmpty &&
            snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_cached.isEmpty) return _VisibilityCard(isHindi: widget.isHindi);

        return Column(
          children: _cached.map((doc) => _RequestCard(
            key: ValueKey(doc.id),
            bookingId: doc.id,
            data: doc.data() as Map<String, dynamic>,
            uid: widget.uid,
            isHindi: widget.isHindi,
            myPos: widget.myPos,
          )).toList(),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIX 3 + 5 + 6 — REQUEST CARD
// • No date picker — reads customer's scheduledAt directly
// • Smart auto-decline timer: only for instant bookings (< 2 hours away)
// • Shows paymentMethod badge (Cash/UPI)
// • Accept shows _AcceptConfirmSheet with customer's date
// ═══════════════════════════════════════════════════════════════════════════
class _RequestCard extends StatefulWidget {
  final String bookingId, uid;
  final Map<String, dynamic> data;
  final bool isHindi;
  final Position? myPos;

  const _RequestCard({
    super.key,
    required this.bookingId, required this.uid, required this.data,
    required this.isHindi, this.myPos,
  });

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  // ✅ Timer completely removed — no auto-decline

  Future<void> _decline() async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({
      'status':      _Status.cancelled,
      'cancelledBy': 'helper',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingBookingDetail(bookingId: widget.bookingId),
      ),
    );
  }

  String _dist() {
    final loc = widget.data['userLocation'] as GeoPoint?;
    if (loc == null || widget.myPos == null) return '';
    final m = Geolocator.distanceBetween(
        widget.myPos!.latitude, widget.myPos!.longitude,
        loc.latitude, loc.longitude);
    return m < 1000
        ? '${m.toInt()} m away'
        : '${(m / 1000).toStringAsFixed(1)} km away';
  }

  String _ago(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  static (IconData, Color) _svcIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('plumb'))  return (Icons.plumbing_rounded,             const Color(0xFF0EA5E9));
    if (n.contains('electr')) return (Icons.electrical_services_rounded,  const Color(0xFFF59E0B));
    if (n.contains('clean'))  return (Icons.cleaning_services_rounded,    const Color(0xFF10B981));
    if (n.contains('carpen') || n.contains('wood'))
      return (Icons.handyman_rounded, const Color(0xFF8B5CF6));
    if (n.contains('paint'))  return (Icons.format_paint_rounded,         const Color(0xFFEF4444));
    if (n.contains('ac') || n.contains('air'))
      return (Icons.ac_unit_rounded, const Color(0xFF06B6D4));
    if (n.contains('pest'))   return (Icons.pest_control_rounded,         const Color(0xFF84CC16));
    if (n.contains('garden') || n.contains('yard'))
      return (Icons.yard_rounded, const Color(0xFF22C55E));
    if (n.contains('pet'))    return (Icons.pets_rounded,                 const Color(0xFFF97316));
    if (n.contains('video') || n.contains('photo'))
      return (Icons.videocam_rounded, const Color(0xFF6366F1));
    return (Icons.home_repair_service_rounded, _P.purple);
  }

  Future<void> _showAcceptConfirm(BuildContext context) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AcceptConfirmSheet(
        data: widget.data,
        isHindi: widget.isHindi,
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await _accept(context);
  }

  Future<void> _accept(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final db   = FirebaseFirestore.instance;

    final helperName  = auth.helper?.name ?? '';
    final helperId    = auth.helper?.uid  ?? '';
    final svcName     = widget.data['serviceName'] as String? ?? 'Service';
    final userId      = widget.data['userId'] as String? ?? '';
    final scheduledAt = (widget.data['scheduledAt'] as Timestamp?)?.toDate();
    final formatted   = scheduledAt != null
        ? DateFormat('d MMM yyyy, h:mm a').format(scheduledAt.toLocal())
        : '';

    final batch = db.batch();

    batch.update(db.collection('bookings').doc(widget.bookingId), {
      'status':      _Status.accepted,
      'helperId':    helperId,
      'helperName':  helperName,
      'acceptedAt':  FieldValue.serverTimestamp(),
      'confirmedAt': FieldValue.serverTimestamp(),
    });

    if (userId.isNotEmpty) {
      final notifRef = db
          .collection('notifications').doc(userId)
          .collection('items').doc();
      batch.set(notifRef, {
        'type':      'booking_accepted',
        'title':     'Booking Confirmed! ✅',
        'body':      '$helperName has accepted your $svcName booking'
            '${formatted.isNotEmpty ? " for $formatted" : ""}.',
        'bookingId': widget.bookingId,
        'read':      false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    await BookingChatService.instance.onBookingAccepted(
      bookingId:     widget.bookingId,
      helperId:      helperId,
      helperName:    helperName,
      helperPhoto:   '',
      userId:        userId,
      userName:      '',
      serviceName:   svcName,
      scheduledTime: formatted,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d      = widget.data;
    final svc    = d['serviceName'] as String? ?? 'Service';
    final amount = _helperAmount(d);
    final ts     = (d['createdAt'] as Timestamp?)?.toDate();
    final dist   = _dist();
    final (icon, color) = _svcIcon(svc);
    final payMethod = d['paymentMethod'] as String?;
    final scheduledAt = (d['scheduledAt'] as Timestamp?)?.toDate();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // ── Card top ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54, height: 54,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(svc,
                    style: const TextStyle(
                        color: _P.t1, fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 5),
                if (dist.isNotEmpty)
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _P.purple.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.near_me_rounded,
                            size: 10, color: _P.purple),
                        const SizedBox(width: 3),
                        Text(dist,
                            style: const TextStyle(
                                color: _P.purple, fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    if (ts != null)
                      Text(_ago(ts),
                          style: const TextStyle(
                              color: _P.t3, fontSize: 11)),
                  ]),
                if (scheduledAt != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.schedule_rounded,
                        size: 11, color: _P.t2),
                    const SizedBox(width: 3),
                    Text(
                      DateFormat('d MMM, h:mm a')
                          .format(scheduledAt.toLocal()),
                      style: const TextStyle(
                          color: _P.t2, fontSize: 11,
                          fontWeight: FontWeight.w500),
                    ),
                  ]),
                ],
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: _P.t1, fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                _paymentBadge(payMethod),
              ]),
            ],
          ),
        ),

        // ── Divider + Actions ──
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20)),
            border: Border(top: BorderSide(color: _P.border)),
          ),
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          child: Row(children: [
            // View details
            GestureDetector(
              onTap: () => _openDetail(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _P.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _P.border),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: _P.t2),
                  SizedBox(width: 5),
                  Text('Details',
                      style: TextStyle(
                          color: _P.t2, fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _showAcceptConfirm(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
              ),
              child: Text(
                widget.isHindi ? 'स्वीकार करें' : 'ACCEPT',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    letterSpacing: 0.6),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _decline,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: _P.red.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: _P.red.withOpacity(0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.close_rounded,
                      size: 14, color: _P.red.withOpacity(0.8)),
                  const SizedBox(width: 4),
                  Text(
                    widget.isHindi ? 'मना करें' : 'DECLINE',
                    style: TextStyle(
                        color: _P.red.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIX 3 — ACCEPT CONFIRMATION SHEET
// Shows customer's booked date/time — helper cannot change it.
// Shows baseAmount only — platformFee is never shown to helper.
// ═══════════════════════════════════════════════════════════════════════════
class _AcceptConfirmSheet extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isHindi;
  const _AcceptConfirmSheet({required this.data, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    final safeB = MediaQuery.of(context).padding.bottom;
    final svc   = data['serviceName'] as String? ?? 'Service';
    final addr  = data['address'] as String? ?? '';
    // Helper only sees baseAmount — platform fee is app revenue (never shown)
    final amount = _helperAmount(data);
    final payMethod = data['paymentMethod'] as String?;

    // Read the customer's scheduledAt Timestamp
    final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate().toLocal();
    final dateStr = scheduledAt != null
        ? DateFormat('EEEE, d MMMM yyyy').format(scheduledAt)
        : '—';
    final timeStr = scheduledAt != null
        ? DateFormat('h:mm a').format(scheduledAt)
        : '—';

    return Container(
      decoration: const BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, safeB + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Drag handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFDEE2E6),
                borderRadius: BorderRadius.circular(2)),
          ),
        ),

        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: _P.green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.handshake_rounded,
                color: _P.green, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isHindi ? 'बुकिंग स्वीकार करें' : 'Confirm Booking',
                style: const TextStyle(
                    color: _P.t1, fontSize: 17, fontWeight: FontWeight.w800)),
            Text(isHindi ? 'ग्राहक का शेड्यूल' : "Customer's requested schedule",
                style: const TextStyle(color: _P.t2, fontSize: 12)),
          ]),
        ]),
        const SizedBox(height: 22),

        // Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _P.border),
          ),
          child: Column(children: [
            _Row(Icons.home_repair_service_rounded, _P.purple,
                isHindi ? 'सेवा' : 'Service', svc),
            const SizedBox(height: 12),
            _Row(Icons.calendar_today_rounded, _P.purple,
                isHindi ? 'तारीख' : 'Date', dateStr),
            const SizedBox(height: 12),
            _Row(Icons.access_time_rounded, _P.purple,
                isHindi ? 'समय' : 'Time', timeStr),
            if (addr.isNotEmpty) ...[
              const SizedBox(height: 12),
              _Row(Icons.location_on_rounded, _P.red,
                  isHindi ? 'पता' : 'Address', addr),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                    color: _P.green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.currency_rupee_rounded,
                    color: _P.green, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isHindi ? 'भुगतान' : 'Your Payment',
                    style: const TextStyle(
                        color: _P.t3, fontSize: 10, fontWeight: FontWeight.w600)),
                Text('₹${amount.toStringAsFixed(0)}',
                    style: const TextStyle(
                        color: _P.green, fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ])),
              _paymentBadge(payMethod),
            ]),
          ]),
        ),
        const SizedBox(height: 22),

        // Confirm button
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _P.green,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              isHindi ? 'पुष्टि करें और स्वीकार करें' : 'Confirm & Accept',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Decline button
        SizedBox(
          width: double.infinity, height: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _P.red,
              side: const BorderSide(color: _P.red),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(
              isHindi ? 'अस्वीकार करें' : 'Decline',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _Row(this.icon, this.color, this.label, this.value);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: _P.t3, fontSize: 10, fontWeight: FontWeight.w600)),
        Text(value,
            style: const TextStyle(
                color: _P.t1, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
    ],
  );
}

// ── Visibility empty card ─────────────────────────────────────────────────
class _VisibilityCard extends StatelessWidget {
  final bool isHindi;
  const _VisibilityCard({required this.isHindi});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    decoration: BoxDecoration(
      color: const Color(0xFFF0EEFF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDDD6FE)),
    ),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
            color: _P.purple.withOpacity(0.10), shape: BoxShape.circle),
        child: const Icon(Icons.gps_fixed_rounded, color: _P.purple, size: 28),
      ),
      const SizedBox(height: 16),
      Text(isHindi ? 'विज़िबिलिटी एक्टिव' : 'Visibility Active',
          style: const TextStyle(
              color: _P.purple, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      RichText(text: TextSpan(
        style: const TextStyle(color: _P.t2, fontSize: 13, height: 1.6),
        children: [
          TextSpan(text: isHindi
              ? 'आप ऑनलाइन हैं और '
              : "You're online and visible to customers in a "),
          const TextSpan(text: '5 km radius',
              style: TextStyle(fontWeight: FontWeight.w700, color: _P.t1)),
          TextSpan(text: isHindi
              ? ' के ग्राहकों को दिख रहे हैं।\nनए अनुरोध तुरंत यहाँ दिखेंगे।'
              : '. New requests will appear here instantly.'),
        ],
      )),
    ]),
  );
}

// ── History button ────────────────────────────────────────────────────────
class _HistoryBtn extends StatelessWidget {
  final bool isHindi;
  const _HistoryBtn({required this.isHindi});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
        context, SmoothRoute(page: const JobHistoryScreen())),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
          color: _P.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.border)),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: _P.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.work_history_rounded, color: _P.purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(
            isHindi ? 'सभी पुराने काम देखें' : 'View All Job History',
            style: const TextStyle(
                color: _P.t1, fontSize: 14, fontWeight: FontWeight.w600))),
        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _P.t3),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// JOBS TAB — includes _UpcomingJobsSection between Ongoing and Pending
// ═══════════════════════════════════════════════════════════════════════════
class _JobsTab extends StatelessWidget {
  final Position? myPos;
  final int pendingCount;
  final VoidCallback? onGoHome;
  const _JobsTab({this.myPos, required this.pendingCount, this.onGoHome});

  @override
  Widget build(BuildContext context) {
    final helper  = context.watch<AuthProvider>().helper;
    final isHindi = context.watch<LanguageProvider>().isHindi;
    final uid     = helper?.uid ?? '';

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _TabHeader(
          helper: helper,
          isOnline: helper?.isOnline ?? false,
          isHindi: isHindi,
        )),
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _StatusBanner(
              helper: helper, count: pendingCount, isHindi: isHindi),
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // 1. Ongoing/Accepted job card (Firestore-driven)
            _OngoingJobSection(uid: uid, isHindi: isHindi),
            // 2. Upcoming accepted jobs (scheduledAt > now)
            _UpcomingJobsSection(uid: uid, isHindi: isHindi),
            // 3. Pending requests
            _SecHead(
              title: isHindi ? 'नए अनुरोध' : 'Pending Requests',
              badge: pendingCount > 0 ? '$pendingCount Nearby' : null,
            ),
            const SizedBox(height: 12),
            _PendingList(uid: uid, isHindi: isHindi, myPos: myPos),
            const SizedBox(height: 22),
            _HistoryBtn(isHindi: isHindi),
            const SizedBox(height: 10),
            _ScheduleShortcutBtn(isHindi: isHindi),
            const SizedBox(height: 12),
          ])),
        ),
      ]),
    );
  }
}

// ── Schedule shortcut button ──────────────────────────────────────────────
class _ScheduleShortcutBtn extends StatelessWidget {
  final bool isHindi;
  const _ScheduleShortcutBtn({required this.isHindi});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
        context, MaterialPageRoute(
        builder: (_) => const ScheduleScreen())),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
          color: _P.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.border)),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: _P.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.calendar_month_rounded,
              color: _P.purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(
            isHindi ? 'शेड्यूल देखें' : 'View My Schedule',
            style: const TextStyle(
                color: _P.t1, fontSize: 14, fontWeight: FontWeight.w600))),
        const Icon(Icons.arrow_forward_ios_rounded,
            size: 12, color: _P.t3),
      ]),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// HOME TAB
// ═══════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  final Position? myPos;
  final VoidCallback? onGoJobs;
  final int pendingCount;
  const _HomeTab({this.myPos, this.onGoJobs, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    final helper  = context.watch<AuthProvider>().helper;
    final uid     = helper?.uid ?? '';
    final isHindi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: _P.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _GreetingHeader(helper: helper)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            _ToggleCard(helper: helper, isHindi: isHindi),
            const SizedBox(height: 14),
            _EarningsCard(uid: uid, isHindi: isHindi),
            const SizedBox(height: 14),
            _StatsRow(helper: helper),
            const SizedBox(height: 14),
            _TodayScheduleCard(uid: uid, isHindi: isHindi),
            const SizedBox(height: 14),
            _WaitingBanner(isHindi: isHindi, pendingCount: pendingCount, onTap: onGoJobs),
            const SizedBox(height: 22),
            _SecHead(title: isHindi ? 'हालिया गतिविधि' : 'Recent Activity'),
            const SizedBox(height: 12),
            _ActivityList(uid: uid),
          ])),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FIX 8 — TODAY SCHEDULE CARD
// Uses scheduledAt Timestamp range query — NOT the phantom 'scheduledDate' field
// Only shows accepted + ongoing bookings
// ═══════════════════════════════════════════════════════════════════════════
// ── Today schedule card ───────────────────────────────────────────────────────
// StatefulWidget — persistent subscription prevents "No jobs" flash on rebuild.
// Includes 'arrived' status alongside accepted + ongoing.
class _TodayScheduleCard extends StatefulWidget {
  final String uid;
  final bool isHindi;
  const _TodayScheduleCard({required this.uid, required this.isHindi});
  @override
  State<_TodayScheduleCard> createState() => _TodayScheduleCardState();
}

class _TodayScheduleCardState extends State<_TodayScheduleCard> {
  StreamSubscription<QuerySnapshot>? _sub;
  // Each entry: {'scheduledAt': DateTime, 'serviceName': String}
  List<Map<String, dynamic>> _slots = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_TodayScheduleCard old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;
    final now   = DateTime.now();
    final start = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
    final end   = Timestamp.fromDate(
        DateTime(now.year, now.month, now.day, 23, 59, 59));

    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .where('scheduledAt', isGreaterThanOrEqualTo: start)
        .where('scheduledAt', isLessThanOrEqualTo: end)
        .snapshots()
        .listen((snap) {
      final slots = snap.docs
          .where((doc) {
        final s = (doc.data() as Map)['status'] as String? ?? '';
        return s == _Status.accepted ||
            s == _Status.arrived  ||
            s == _Status.ongoing;
      })
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
      if (mounted) setState(() => _slots = slots);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _slots.length;

    return GestureDetector(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const ScheduleScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_P.purple.withOpacity(0.08), _P.purple.withOpacity(0.03)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _P.purple.withOpacity(0.20)),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: _P.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.calendar_today_rounded,
                color: _P.purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.isHindi ? 'आज का शेड्यूल' : "Today's Schedule",
                  style: const TextStyle(
                      color: _P.t1, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              if (count == 0)
                Text(
                  widget.isHindi ? 'आज कोई काम नहीं है' : 'No jobs scheduled today',
                  style: const TextStyle(color: _P.t2, fontSize: 12),
                )
              else ...[
                Text(
                  '$count ${widget.isHindi ? 'काम शेड्यूल' : 'job${count > 1 ? "s" : ""} scheduled'}',
                  style: const TextStyle(
                      color: _P.purple, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  children: _slots.take(3).map((d) {
                    final sat = (d['scheduledAt'] as Timestamp?)?.toDate().toLocal();
                    final t   = sat != null ? DateFormat('h:mm a').format(sat) : '';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: _P.purple.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(t,
                          style: const TextStyle(
                              color: _P.purple, fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    );
                  }).toList(),
                ),
              ],
            ]),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: _P.purple),
        ]),
      ),
    );
  }
}

// ── Greeting header ───────────────────────────────────────────────────────
class _GreetingHeader extends StatefulWidget {
  final HelperModel? helper;
  const _GreetingHeader({required this.helper});
  @override
  State<_GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<_GreetingHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _p;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _p = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _p, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _p.dispose();
    super.dispose();
  }

  static String _greet() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final helper   = widget.helper;
    final isOnline = helper?.isOnline ?? false;
    final isHindi  = context.watch<LanguageProvider>().isHindi;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 20, left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_P.indigo, _P.violet, _P.purple],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(isHindi ? 'नमस्ते 👋' : '${_greet()} 👋',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
            Text(helper?.name ?? 'Helper',
                style: const TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w800)),
          ])),
          AnimatedBuilder(
            animation: _a,
            builder: (_, __) => Opacity(
              opacity: isOnline ? _a.value : 0.4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                    color: (isOnline
                        ? AppColors.onlineGreen
                        : Colors.white24),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 6, height: 6,
                      decoration: BoxDecoration(
                          color: isOnline
                              ? Colors.white
                              : Colors.white38,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(isOnline
                      ? (isHindi ? 'ऑनलाइन' : 'ONLINE')
                      : (isHindi ? 'ऑफलाइन' : 'OFFLINE'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          const NotificationBell(isDark: false),
        ]),
        const SizedBox(height: 14),
        // Location pill — use helper.area directly (no extra stream needed)
        if (helper != null)
          Builder(
            builder: (ctx) {
              final area    = helper.area;
              final display = area.isNotEmpty ? area : 'Surat, Gujarat';

              return GestureDetector(
                onTap: () {
                  if (isOnline) {
                    Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const HelperLocationScreen()));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Row(children: [
                        Icon(Icons.lock_rounded,
                            color: Colors.white, size: 15),
                        SizedBox(width: 8),
                        Text('Go ONLINE first to update location',
                            style: TextStyle(color: Colors.white)),
                      ]),
                      backgroundColor: _P.amber,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      margin: const EdgeInsets.all(12),
                      duration: const Duration(seconds: 2),
                    ));
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(
                          isOnline ? 0.18 : 0.10),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.22))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      isOnline
                          ? Icons.location_on_rounded
                          : Icons.location_off_rounded,
                      color: Colors.white70, size: 13,
                    ),
                    const SizedBox(width: 5),
                    Text(display,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(width: 5),
                    Icon(
                      isOnline
                          ? Icons.edit_rounded
                          : Icons.lock_rounded,
                      color: Colors.white60, size: 11,
                    ),
                  ]),
                ),
              );
            },
          )
        else
          const _StaticLocationPill(isOnline: false),
      ]),
    );
  }
}

class _StaticLocationPill extends StatelessWidget {
  final bool isOnline;
  const _StaticLocationPill({required this.isOnline});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.22))),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.location_on_rounded, color: Colors.white70, size: 13),
      SizedBox(width: 5),
      Text('Surat, Gujarat',
          style: TextStyle(
              color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Online toggle card ────────────────────────────────────────────────────
class _ToggleCard extends StatelessWidget {
  final HelperModel? helper;
  final bool isHindi;
  const _ToggleCard({required this.helper, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    final on = helper?.isOnline ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
          color: _P.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: on
                  ? AppColors.onlineGreen.withOpacity(0.25)
                  : _P.border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('SERVICE STATUS',
              style: TextStyle(
                  color: _P.t3, fontSize: 9,
                  fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(on
              ? (isHindi ? 'अभी ऑनलाइन हैं' : 'Currently Online')
              : (isHindi ? 'अभी ऑफलाइन हैं' : 'Currently Offline'),
              style: const TextStyle(
                  color: _P.t1, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const Spacer(),
        _OnlineToggleBtn(helper: helper, isHindi: isHindi, isOnline: on),
      ]),
    );
  }
}

// ── Today earnings card ────────────────────────────────────────────────────
// ── Today earnings card ───────────────────────────────────────────────────────
// StatefulWidget with a persistent StreamSubscription so parent rebuilds
// (e.g. GPS location ticks) never reset the displayed total to ₹0.
class _EarningsCard extends StatefulWidget {
  final String uid;
  final bool isHindi;
  const _EarningsCard({required this.uid, required this.isHindi});
  @override
  State<_EarningsCard> createState() => _EarningsCardState();
}

class _EarningsCardState extends State<_EarningsCard> {
  StreamSubscription<QuerySnapshot>? _sub;
  double _total = 0;
  int    _jobs  = 0;
  static const double _goal = 1500.0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_EarningsCard old) {
    super.didUpdateWidget(old);
    // Only re-subscribe if the uid actually changed (e.g. user switched accounts).
    if (old.uid != widget.uid) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;
    final today = DateTime.now();
    final start = Timestamp.fromDate(
        DateTime(today.year, today.month, today.day));
    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId',   isEqualTo: widget.uid)
        .where('status',     isEqualTo: _Status.completed)
        .where('completedAt', isGreaterThanOrEqualTo: start)
        .snapshots()
        .listen((snap) {
      double total = 0;
      int    jobs  = 0;
      for (final doc in snap.docs) {
        total += _helperAmount(doc.data() as Map<String, dynamic>);
        jobs++;
      }
      if (mounted) setState(() { _total = total; _jobs = jobs; });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();
    final pct = (_total / _goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.isHindi ? 'आज की कमाई' : "Today's Earnings",
                style: const TextStyle(
                    color: _P.t2, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('₹ ${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: _P.t1, fontSize: 28, fontWeight: FontWeight.w800)),
            if (_jobs > 0) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.check_circle_rounded, color: _P.green, size: 13),
                const SizedBox(width: 4),
                Text(
                  '$_jobs ${widget.isHindi ? 'काम पूरे' : 'job${_jobs > 1 ? "s" : ""} done'}',
                  style: const TextStyle(
                      color: _P.green, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Text(widget.isHindi ? 'लक्ष्य' : 'Daily Goal',
                  style: const TextStyle(color: _P.t3, fontSize: 10)),
              const Spacer(),
              Text('₹${_total.toStringAsFixed(0)} / ₹${_goal.toInt()}',
                  style: const TextStyle(
                      color: _P.t3, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: const Color(0xFFEDE9FE),
                valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 1.0 ? _P.green : _P.purple),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 18),
        SizedBox(
          width: 80, height: 80,
          child: Stack(alignment: Alignment.center, children: [
            CustomPaint(size: const Size(80, 80), painter: _RingPainter(pct: pct)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(pct * 100).toInt()}%',
                  style: const TextStyle(
                      color: _P.t1, fontSize: 16, fontWeight: FontWeight.w800)),
              Text(widget.isHindi ? 'लक्ष्य' : 'goal',
                  style: const TextStyle(color: _P.t3, fontSize: 9)),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  const _RingPainter({required this.pct});
  @override
  void paint(Canvas c, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2, r = cx - 6;
    c.drawCircle(Offset(cx, cy), r, Paint()
      ..color       = const Color(0xFFEDE9FE)
      ..style       = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap   = StrokeCap.round);
    if (pct > 0) {
      c.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        2 * math.pi * pct,
        false,
        Paint()
          ..shader = const LinearGradient(colors: [_P.purple, Color(0xFF06B6D4)])
              .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap   = StrokeCap.round,
      );
    }
  }
  @override
  bool shouldRepaint(_RingPainter o) => o.pct != pct;
}



// ── Stats row ─────────────────────────────────────────────────────────────
// ── Stats row — uses HelperModel directly, no extra Firestore stream ──────────
class _StatsRow extends StatelessWidget {
  final HelperModel? helper;
  const _StatsRow({required this.helper});

  @override
  Widget build(BuildContext context) {
    if (helper == null) return const SizedBox.shrink();
    final rating = helper!.rating;
    final done   = helper!.completedJobs;

    return Row(children: [
      Expanded(child: _StatChip(
          icon: Icons.star_rounded, color: _P.amber, label: 'RATING',
          value: rating == 0 ? '–' : rating.toStringAsFixed(1),
          sub: 'All time')),
      const SizedBox(width: 12),
      Expanded(child: _StatChip(
          icon: Icons.check_circle_rounded, color: _P.green,
          label: 'JOBS DONE', value: '$done',
          sub: '$done completed')),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value, sub;
  const _StatChip({
    required this.icon, required this.color,
    required this.label, required this.value, required this.sub,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: _P.t3, fontSize: 9,
              fontWeight: FontWeight.w700, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 7),
        Text(value,
            style: const TextStyle(
                color: _P.t1, fontSize: 22, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 2),
      Text(sub, style: const TextStyle(color: _P.t2, fontSize: 11)),
    ]),
  );
}

// ── Waiting banner ─────────────────────────────────────────────────────────
// AFTER
// ── Waiting banner — uses pendingCount from parent, no inner stream ─────────
class _WaitingBanner extends StatelessWidget {
  final bool isHindi;
  final int pendingCount;
  final VoidCallback? onTap;
  const _WaitingBanner({
    required this.isHindi,
    required this.pendingCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingCount == 0) return const SizedBox.shrink();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _P.purple.withOpacity(0.07),
            _P.purple.withOpacity(0.02),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.purple.withOpacity(0.18)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
                color: _P.purple.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12)),
            child: Stack(alignment: Alignment.center, children: [
              const Icon(Icons.notifications_active_rounded,
                  color: _P.purple, size: 22),
              Positioned(top: 6, right: 6,
                  child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: _P.red, shape: BoxShape.circle))),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '$pendingCount ${isHindi ? 'नए अनुरोध' : 'New Request${pendingCount > 1 ? "s" : ""}'}',
                style: const TextStyle(
                    color: _P.t1, fontSize: 14, fontWeight: FontWeight.w700)),
            Text(isHindi ? 'जॉब्स टैब पर देखें' : 'Tap to view in Jobs tab',
                style: const TextStyle(color: _P.t2, fontSize: 11)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 13, color: _P.purple),
        ]),
      ),
    );
  }
}

// ── Recent activity list ──────────────────────────────────────────────────
// ── Recent activity list ──────────────────────────────────────────────────────
// StatefulWidget with persistent subscription — never flashes "No activity yet"
// on parent rebuild.
class _ActivityList extends StatefulWidget {
  final String uid;
  const _ActivityList({required this.uid});
  @override
  State<_ActivityList> createState() => _ActivityListState();
}

class _ActivityListState extends State<_ActivityList> {
  StreamSubscription<QuerySnapshot>? _sub;
  List<QueryDocumentSnapshot> _cached = [];
  bool _firstLoad = true;

  static (IconData, Color) _meta(String s) {
    switch (s) {
      case _Status.completed: return (Icons.check_circle_rounded, _P.green);
      case _Status.accepted:  return (Icons.handshake_rounded,    _P.purple);
      case _Status.arrived:   return (Icons.location_on_rounded,  _P.amber);
      case _Status.ongoing:   return (Icons.play_circle_rounded,  AppColors.onlineGreen);
      case 'booked':
      case 'pending':         return (Icons.pending_rounded,      _P.amber);
      default:                return (Icons.cancel_rounded,       AppColors.danger);
    }
  }

  static String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1)  return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24)   return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(_ActivityList old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid) {
      _sub?.cancel();
      _subscribe();
    }
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;
    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .orderBy('createdAt', descending: true)
        .limit(6)
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _cached    = snap.docs;
          _firstLoad = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) return const SizedBox.shrink();

    // Show nothing while the very first snapshot is in flight
    // (avoids the empty-state flash).
    if (_firstLoad) return const SizedBox.shrink();

    if (_cached.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: _P.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _P.border)),
        child: const Center(
            child: Text('No activity yet',
                style: TextStyle(color: _P.t2, fontSize: 13))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: _cached.asMap().entries.map((e) {
          final doc    = e.value;
          final d      = doc.data() as Map<String, dynamic>;
          final status = d['status'] as String? ?? _Status.pending;
          final svc    = d['serviceName'] as String? ?? 'Service';
          final amt    = _helperAmount(d);
          final ts     = (d['createdAt'] as Timestamp?)?.toDate();
          final isLast = e.key == _cached.length - 1;
          final (icon, color) = _meta(status);

          return KeyedSubtree(
            key: ValueKey(doc.id),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: color, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(svc,
                        style: const TextStyle(
                            color: _P.t1, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(status.toUpperCase(),
                        style: const TextStyle(
                            color: _P.t3, fontSize: 9,
                            fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      status == _Status.completed
                          ? '+₹${amt.toStringAsFixed(0)}'
                          : '₹${amt.toStringAsFixed(0)}',
                      style: TextStyle(
                          color: status == _Status.completed ? _P.green : _P.t2,
                          fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    if (ts != null)
                      Text(_ago(ts),
                          style: const TextStyle(color: _P.t3, fontSize: 10)),
                  ]),
                ]),
              ),
              if (!isLast)
                Divider(height: 1, color: _P.div, indent: 14, endIndent: 14),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _SecHead extends StatelessWidget {
  final String title;
  final String? badge;
  const _SecHead({required this.title, this.badge});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 18,
        decoration: BoxDecoration(
            color: _P.purple, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 10),
    Text(title,
        style: const TextStyle(
            color: _P.t1, fontSize: 17, fontWeight: FontWeight.w800)),
    if (badge != null) ...[
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: _P.purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _P.purple.withOpacity(0.18))),
        child: Text(badge!,
            style: const TextStyle(
                color: _P.purple, fontSize: 11,
                fontWeight: FontWeight.w700)),
      ),
    ],
  ]);
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: TextStyle(
            color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ─── Online toggle button ─────────────────────────────────────────────────
class _OnlineToggleBtn extends StatelessWidget {
  final HelperModel? helper;
  final bool isHindi, isOnline;

  const _OnlineToggleBtn({
    required this.helper,
    required this.isHindi,
    required this.isOnline,
  });

  // ✅ FINAL LOGIC
  bool _canGoOnline(Map<String, dynamic> d) {
    final kycApproved = helper?.isApproved ?? false;
    if (!kycApproved) return false;

    // These 7 fields = 95% base score (photo = bonus 5%)
    final checks = <bool>[
      (helper?.name ?? '').isNotEmpty,
      (helper?.phone ?? '').isNotEmpty,
      (helper?.area ?? '').isNotEmpty,
      (helper?.services ?? []).isNotEmpty,
      ((d['description'] ?? d['bio'] ?? '') as String).isNotEmpty,
      _safeDouble(d['experience']) > 0,
      _safeDouble(d['pricePerVisit']) > 0,
    ];

    final completed = checks.where((e) => e).length;
    final baseScore = (completed / checks.length) * 95;
    final photoScore = ((d['photoUrl'] as String? ?? '').isNotEmpty) ? 5.0 : 0.0;

    return (baseScore + photoScore) >= 95;
  }

  String _getBlockMessage(Map<String, dynamic> d) {
    final kycApproved = helper?.isApproved ?? false;

    if (!kycApproved) {
      return isHindi
          ? 'ऑनलाइन जाने के लिए KYC अप्रूवल का इंतजार करें'
          : 'Wait for KYC approval to go online';
    }

    final missing = <String>[];
    if ((helper?.name ?? '').isEmpty)                                        missing.add('Name');
    if ((helper?.phone ?? '').isEmpty)                                       missing.add('Phone');
    if ((helper?.area ?? '').isEmpty)                                        missing.add('Area');
    if ((helper?.services ?? []).isEmpty)                                    missing.add('Services');
    if (((d['description'] ?? d['bio'] ?? '') as String).isEmpty)            missing.add('About You');
    if (_safeDouble(d['experience']) <= 0)                                   missing.add('Experience');
    if (_safeDouble(d['pricePerVisit']) <= 0)                                missing.add('Price/Visit');
    if ((d['photoUrl'] as String? ?? '').isEmpty)                            missing.add('Photo (+5%)');

    if (missing.isEmpty) return isHindi
        ? 'प्रोफ़ाइल पूरी करें'
        : 'Complete your profile';

    return isHindi
        ? 'बाकी: ${missing.join(", ")}'
        : 'Missing: ${missing.join(", ")}';
  }

  @override
  Widget build(BuildContext context) {
    final uid = helper?.uid ?? '';
    if (uid.isEmpty) return _lockedChip(context, "Invalid user");

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};

        final canToggle = _canGoOnline(d);

        if (!canToggle) {
          return _lockedChip(context, _getBlockMessage(d));
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.read<AuthProvider>().toggleOnlineStatus();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isOnline ? AppColors.onlineGreen : _P.purple,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              isOnline
                  ? (isHindi ? 'ऑनलाइन' : 'ACTIVE')
                  : (isHindi ? 'लाइव जाएं' : 'GO LIVE'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ Updated locked UI
  Widget _lockedChip(BuildContext context, String message) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: _P.amber,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 3),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _P.amber.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded, color: _P.amber, size: 12),
            const SizedBox(width: 5),
            Text(
              isHindi ? 'लॉक्ड' : 'LOCKED',
              style: const TextStyle(
                color: _P.amber,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// KYC STATUS SCREENS
// ═══════════════════════════════════════════════════════════════════════════
class _KycPending extends StatelessWidget {
  final HelperModel helper;
  const _KycPending({required this.helper});
  @override
  Widget build(BuildContext context) => _KycShell(
      helper: helper, color: AppColors.warning, label: 'Action Required',
      icon: Icons.upload_file_rounded,
      title: 'Complete Your KYC',
      body: 'Upload your Aadhaar & PAN to get verified.',
      steps: const [
        ('Registration Complete', true), ('Upload Aadhaar & PAN', false),
        ('Admin Approval', false), ('Go Live & Earn', false),
      ],
      actions: [
        _KycBtn(label: 'Upload KYC Documents',
            icon: Icons.upload_rounded,
            onTap: (ctx) => Navigator.push(
                ctx, SmoothRoute(page: const KycScreen()))),
      ]);
}

class _KycUnderReview extends StatefulWidget {
  final HelperModel helper;
  const _KycUnderReview({required this.helper});
  @override
  State<_KycUnderReview> createState() => _KycUnderReviewState();
}

class _KycUnderReviewState extends State<_KycUnderReview> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) context.read<AuthProvider>().refreshProfile();
    });
  }
  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => _KycShell(
      helper: widget.helper, color: _P.purple, label: 'Under Review',
      icon: Icons.manage_search_rounded,
      title: 'Documents Under Review',
      body: 'KYC submitted. Admin will review within 24 hours.',
      steps: const [
        ('Registration Complete', true), ('KYC Documents Uploaded', true),
        ('Admin Approval', false), ('Go Live & Earn', false),
      ],
      actions: [
        _KycBtn(
          label: 'Check Status', icon: Icons.refresh_rounded, outline: true,
          onTap: (ctx) => ctx.read<AuthProvider>().refreshProfile(),
        ),
        _KycBtn(
          label: 'Go to Dashboard',
          icon: Icons.dashboard_rounded,
          onTap: (ctx) {
            Navigator.of(ctx).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (_) => const HelperDashboard(bypassKycGate: true)),
                  (_) => false,
            );
          },
        ),
      ]);
}

class _KycRejected extends StatelessWidget {
  final HelperModel helper;
  const _KycRejected({required this.helper});
  @override
  Widget build(BuildContext context) => _KycShell(
      helper: helper, color: AppColors.danger, label: 'KYC Rejected',
      icon: Icons.cancel_rounded,
      title: 'KYC Rejected',
      body: helper.kycRejectedReason ??
          'Please re-upload clear, valid documents.',
      steps: const [],
      actions: [
        _KycBtn(
            label: 'Re-upload Documents', icon: Icons.upload_rounded,
            color: AppColors.danger,
            onTap: (ctx) => Navigator.push(
                ctx, SmoothRoute(page: const KycScreen()))),
      ]);
}
class _KycInactive extends StatelessWidget {
  final HelperModel helper;
  const _KycInactive({required this.helper});
  @override
  Widget build(BuildContext context) => _KycShell(
      helper: helper, color: _P.t2, label: 'Deactivated',
      icon: Icons.block_rounded,
      title: 'Account Deactivated',
      body: 'Contact support to reactivate your account.',
      steps: const [],
      actions: const []);
}

class _KycShell extends StatelessWidget {
  final HelperModel helper;
  final Color color;
  final String label, title, body;
  final IconData icon;
  final List<(String, bool)> steps;
  final List<Widget> actions; // ← changed from Widget? action to List<Widget>
  const _KycShell({
    required this.helper, required this.color,
    required this.label, required this.title, required this.body,
    required this.icon, required this.steps, required this.actions,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _P.bg,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(children: [
        Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(child: Text(helper.initials,
                  style: TextStyle(
                      color: color, fontSize: 15,
                      fontWeight: FontWeight.w700)))),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(helper.name,
                style: const TextStyle(
                    color: _P.t1, fontSize: 15, fontWeight: FontWeight.w700)),
            Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.3))),
                child: Text(label,
                    style: TextStyle(
                        color: color, fontSize: 11,
                        fontWeight: FontWeight.w700))),
          ])),
        ]),
        const Spacer(),
        Container(width: 100, height: 100,
            decoration: BoxDecoration(
                color: color.withOpacity(0.08), shape: BoxShape.circle,
                border: Border.all(
                    color: color.withOpacity(0.3), width: 2)),
            child: Icon(icon, size: 48, color: color)),
        const SizedBox(height: 24),
        Text(title,
            style: const TextStyle(
                color: _P.t1, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center,
            style: const TextStyle(
                color: _P.t2, fontSize: 14, height: 1.6)),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 28),
          _KycSteps(steps: steps),
        ],
        const Spacer(),
        // Render all action buttons
        ...actions.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: a,
        )),
        TextButton.icon(
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout_rounded, size: 16, color: _P.red),
          label: const Text('Logout',
              style: TextStyle(color: _P.red, fontSize: 13)),
        ),
      ]),
    )),
  );
}

// Bypasses KYC gate — used when helper wants to explore dashboard while waiting


class _KycBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final void Function(BuildContext) onTap;
  final Color? color;
  final bool outline;
  const _KycBtn({
    required this.label, required this.icon, required this.onTap,
    this.color, this.outline = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: outline
        ? OutlinedButton.icon(
        onPressed: () => onTap(context),
        icon: Icon(icon), label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          foregroundColor: _P.purple,
          side: const BorderSide(color: _P.purple),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ))
        : ElevatedButton.icon(
        onPressed: () => onTap(context),
        icon: Icon(icon),
        label: Text(label,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        )),
  );
}

class _KycSteps extends StatelessWidget {
  final List<(String, bool)> steps;
  const _KycSteps({required this.steps});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border)),
    child: Column(children: steps.asMap().entries.map((e) {
      final (lbl, done) = e.value;
      final last = e.key == steps.length - 1;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 22, height: 22,
              decoration: BoxDecoration(
                  color: done ? _P.green : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: done ? _P.green : _P.border, width: 2)),
              child: Center(child: done
                  ? const Icon(Icons.check_rounded, size: 13,
                  color: Colors.white)
                  : Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: _P.border, shape: BoxShape.circle)))),
          if (!last)
            Container(width: 2, height: 26,
                color: done ? _P.green.withOpacity(0.3) : _P.border),
        ]),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 3),
            child: Text(lbl,
                style: TextStyle(
                    color: done ? _P.green : _P.t2, fontSize: 13,
                    fontWeight: done
                        ? FontWeight.w600
                        : FontWeight.w400))),
      ]);
    }).toList()),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// BOOKING PROGRESS STEPPER — mirrors the user-side tracking view (Image 3)
// ═══════════════════════════════════════════════════════════════════════════
class _BookingProgressStepper extends StatelessWidget {
  final String status;
  final bool isHindi;
  const _BookingProgressStepper(
      {required this.status, required this.isHindi});

  // (en label, status key, icon)
  static const _steps = [
    ('Booked',          'booked',     Icons.bookmark_rounded),
    ('Helper Assigned', 'accepted',   Icons.person_pin_rounded),
    ('Helper Arrived',  'arrived',    Icons.location_on_rounded),
    ('Work Started',    'ongoing',    Icons.play_circle_rounded),
    ('Completed',       'completed',  Icons.check_circle_rounded),
  ];

  static const _stepsHi = [
    'बुक हुआ', 'हेल्पर मिला', 'हेल्पर पहुँचा', 'काम शुरू', 'पूरा हुआ',
  ];

  int get _activeIndex {
    switch (status) {
      case _Status.pending:   return 0;
      case _Status.accepted:  return 1;
      case _Status.arrived:   return 2;
      case _Status.ongoing:   return 3;
      case _Status.completed: return 4;
      default: return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeIndex;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _P.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BOOKING PROGRESS',
            style: TextStyle(
              color: _P.t3,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ..._steps.asMap().entries.map((e) {
            final idx   = e.key;
            final (label, _, icon) = e.value;
            final hiLabel = _stepsHi[idx];
            final isDone    = idx < active;
            final isCurrent = idx == active;
            final isLast    = idx == _steps.length - 1;

            final dotColor = isDone
                ? _P.green
                : isCurrent
                ? _P.purple
                : Colors.transparent;
            final borderColor = isDone
                ? _P.green
                : isCurrent
                ? _P.purple
                : _P.border;
            final lineColor = isDone
                ? _P.green.withOpacity(0.35)
                : _P.border;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Dot + connector line ──
                Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: borderColor, width: 2),
                    ),
                    child: Center(
                      child: isDone
                          ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 13)
                          : Icon(
                        icon,
                        color: isCurrent
                            ? Colors.white
                            : _P.t3,
                        size: 12,
                      ),
                    ),
                  ),
                  if (!isLast)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 2,
                      height: 24,
                      color: lineColor,
                    ),
                ]),
                const SizedBox(width: 12),
                // ── Label ──
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    isHindi ? hiLabel : label,
                    style: TextStyle(
                      color: isDone
                          ? _P.green
                          : isCurrent
                          ? _P.purple
                          : _P.t3,
                      fontSize: 12,
                      fontWeight: (isDone || isCurrent)
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}