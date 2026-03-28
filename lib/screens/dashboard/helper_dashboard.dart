// lib/screens/dashboard/helper_dashboard.dart
// ═══════════════════════════════════════════════════════════════════════════
//  SARTHI KENDRA — Dashboard (light theme only, no duplicate screens)
//
//  Tab layout:
//    0 — JOBS   (new, redesigned inline)
//    1 — HOME   (new, redesigned inline)
//    2 — EARN   → existing EarningsScreen
//    3 — ME     → existing HelperProfileScreen
//
//  Removed from this file:
//    _EarnTab, _MeTab and all their sub-widgets (duplicated existing files)
//    All isDark / dark-theme branches
//
//  pubspec.yaml additions needed:
//    url_launcher: ^6.2.5
//    geolocator: ^12.0.0   (already present)
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_theme.dart';
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

// ═══════════════════════════════════════════════════════════════════════════
// ROOT SCAFFOLD
// ═══════════════════════════════════════════════════════════════════════════
class HelperDashboard extends StatefulWidget {
  const HelperDashboard({super.key});
  @override
  State<HelperDashboard> createState() => _HelperDashboardState();
}

class _HelperDashboardState extends State<HelperDashboard>
    with SingleTickerProviderStateMixin {

  int _tab = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Background GPS
  StreamSubscription<Position>? _locSub;
  Position? _myPos;

  // Badge counter for JOBS tab
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

  void _initBadge() {
    _badgeSub = FirebaseFirestore.instance
        .collection('bookings')
        .where('status', isEqualTo: 'pending')
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

    // KYC gates
    if (helper != null) {
      if (helper.isPending)   return _KycPending(helper: helper);
      if (helper.isSubmitted) return _KycUnderReview(helper: helper);
      if (helper.isRejected)  return _KycRejected(helper: helper);
      if (helper.isInactive)  return _KycInactive(helper: helper);
    }

    final lang = context.watch<LanguageProvider>();

    final pages = [
      _JobsTab(myPos: _myPos, pendingCount: _pendingCount, onGoHome: () => _switchTab(1)),
      _HomeTab(myPos: _myPos, onGoJobs: () => _switchTab(0)),
      const EarningsScreen(),
      const HelperProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: _P.bg,
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
    final hi = lang.isHindi;
    final items = [
      (Icons.work_rounded,   Icons.work_outline_rounded,   hi ? 'काम'   : 'JOBS'),
      (Icons.home_rounded,   Icons.home_outlined,          hi ? 'होम'   : 'HOME'),
      (Icons.wallet_rounded, Icons.wallet_outlined,        hi ? 'कमाई' : 'EARN'),
      (Icons.person_rounded, Icons.person_outline_rounded, hi ? 'मैं'   : 'ME'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _P.white,
        border: Border(top: BorderSide(color: const Color(0xFFECEBFF), width: 1)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((e) {
              final i = e.key;
              final (fill, out, lbl) = e.value;
              final sel = selected == i;
              final hasBadge = i == 0 && badge > 0;

              return GestureDetector(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? _P.purple.withOpacity(0.10) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(sel ? fill : out, size: 24,
                          color: sel ? _P.purple : _P.t3),
                      if (hasBadge)
                        Positioned(
                          top: -5, right: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 17),
                            height: 17,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                                color: _P.red,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: _P.white, width: 1.5)),
                            child: Center(child: Text(
                              badge > 9 ? '9+' : '$badge',
                              style: const TextStyle(color: Colors.white,
                                  fontSize: 9, fontWeight: FontWeight.w800),
                            )),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(lbl, style: TextStyle(
                      fontSize: 9,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      color: sel ? _P.purple : _P.t3,
                      letterSpacing: 0.4,
                    )),
                  ]),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// JOBS TAB
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
            _OngoingJobSection(uid: uid, isHindi: isHindi),
            _SecHead(
              title: isHindi ? 'नए अनुरोध' : 'Pending Requests',
              badge: pendingCount > 0 ? '$pendingCount Nearby' : null,
            ),
            const SizedBox(height: 12),
            _PendingList(uid: uid, isHindi: isHindi, myPos: myPos),
            const SizedBox(height: 22),
            _HistoryBtn(isHindi: isHindi),
            const SizedBox(height: 12),
          ])),
        ),
      ]),
    );
  }
}

// ── Shared tab header (reference image style) ─────────────────────────────
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
      // Online chip
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

// ── Ongoing job section ───────────────────────────────────────────────────
class _OngoingJobSection extends StatelessWidget {
  final String uid;
  final bool isHindi;
  const _OngoingJobSection({required this.uid, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', whereIn: ['accepted', 'in_progress'])
          .limit(1)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) return const SizedBox.shrink();
        final doc = snap.data!.docs.first;
        final d   = doc.data() as Map<String, dynamic>;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('ONGOING JOB',
                style: TextStyle(
                    color: _P.t1, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            _Chip(label: 'IN PROGRESS',
                bg: AppColors.onlineGreen.withOpacity(0.12),
                fg: AppColors.onlineGreen),
          ]),
          const SizedBox(height: 12),
          _OngoingCard(bookingId: doc.id, data: d, uid: uid, isHindi: isHindi),
          const SizedBox(height: 26),
        ]);
      },
    );
  }
}

// ── Ongoing card with live timer ──────────────────────────────────────────
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
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    final start =
        (widget.data['acceptedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    _elapsed = DateTime.now().difference(start);
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
      'lastMessage': msg, 'lastMessageAt': FieldValue.serverTimestamp(),
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

  Future<void> _complete() async {
    setState(() => _completing = true);
    try {
      final db    = FirebaseFirestore.instance;
      final batch = db.batch();
      batch.update(db.collection('bookings').doc(widget.bookingId), {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      });
      batch.update(db.collection('helpers').doc(widget.uid), {
        'completedJobs': FieldValue.increment(1),
      });
      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('🎉 Job marked complete!'),
          backgroundColor: _P.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final d       = widget.data;
    final address = d['address'] as String? ?? d['userAddress'] as String? ?? '';
    final amount  = ((d['amount'] ?? 0) as num).toDouble();
    final replies = widget.isHindi
        ? ['मैं रास्ते पर हूँ', 'पहुँच गया', 'काम शुरू हुआ', '5 मिनट में आता हूँ']
        : ["I'm on my way", 'Arrived at location', 'Job started', '5 mins away'];

    return Container(
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: _P.purple.withOpacity(0.07),
            blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        // Timer strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F3FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_clock,
                  style: const TextStyle(
                      color: _P.purple, fontSize: 28, fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      fontFeatures: [FontFeature.tabularFigures()])),
              const Text('CURRENT SESSION TIME',
                  style: TextStyle(
                      color: _P.t3, fontSize: 8,
                      fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: _P.t1, fontSize: 22, fontWeight: FontWeight.w800)),
              const Text('Fixed Rate',
                  style: TextStyle(color: _P.t3, fontSize: 10)),
            ]),
          ]),
        ),

        // Address
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _P.border),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, color: _P.purple, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DESTINATION',
                      style: TextStyle(
                          color: _P.t3, fontSize: 8,
                          fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(address,
                      style: const TextStyle(
                          color: _P.t1, fontSize: 13,
                          fontWeight: FontWeight.w600, height: 1.4)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _openMaps,
                    child: const Text('Open in Maps ↗',
                        style: TextStyle(
                            color: _P.purple, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ])),
              ]),
            ),
          ),

        // Quick replies
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('QUICK REPLIES',
                style: TextStyle(
                    color: _P.t3, fontSize: 8,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 7,
              children: replies.map((r) => GestureDetector(
                onTap: () => _reply(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                      color: _P.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDDD6FE))),
                  child: Text(r,
                      style: const TextStyle(
                          color: _P.t2, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ]),
        ),

        // Mark complete
        Padding(
          padding: const EdgeInsets.all(14),
          child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _completing ? null : _complete,
              icon: _completing
                  ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(widget.isHindi ? 'काम पूरा करें' : 'Mark Complete',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF166534),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Pending list ──────────────────────────────────────────────────────────
class _PendingList extends StatelessWidget {
  final String uid;
  final bool isHindi;
  final Position? myPos;
  const _PendingList(
      {required this.uid, required this.isHindi, this.myPos});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .orderBy('createdAt', descending: true)
          .limit(15)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _VisibilityCard(isHindi: isHindi);
        }
        return Column(
          children: snap.data!.docs.map((doc) => _RequestCard(
            bookingId: doc.id,
            data: doc.data() as Map<String, dynamic>,
            uid: uid, isHindi: isHindi, myPos: myPos,
          )).toList(),
        );
      },
    );
  }
}

// ── Request card ──────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final String bookingId, uid;
  final Map<String, dynamic> data;
  final bool isHindi;
  final Position? myPos;
  const _RequestCard({
    required this.bookingId, required this.uid, required this.data,
    required this.isHindi, this.myPos,
  });

  String _dist() {
    final loc = data['userLocation'] as GeoPoint?;
    if (loc == null || myPos == null) return '';
    final m = Geolocator.distanceBetween(
        myPos!.latitude, myPos!.longitude, loc.latitude, loc.longitude);
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
      return (Icons.handyman_rounded,                                      const Color(0xFF8B5CF6));
    if (n.contains('paint'))  return (Icons.format_paint_rounded,         const Color(0xFFEF4444));
    if (n.contains('ac') || n.contains('air'))
      return (Icons.ac_unit_rounded,                                       const Color(0xFF06B6D4));
    if (n.contains('pest'))   return (Icons.pest_control_rounded,         const Color(0xFF84CC16));
    if (n.contains('garden') || n.contains('yard'))
      return (Icons.yard_rounded,                                          const Color(0xFF22C55E));
    if (n.contains('pet'))    return (Icons.pets_rounded,                 const Color(0xFFF97316));
    return (Icons.home_repair_service_rounded, _P.purple);
  }

  @override
  Widget build(BuildContext context) {
    final svc    = data['serviceName'] as String? ?? 'Service';
    final amount = ((data['amount'] ?? 0) as num).toDouble();
    final ts     = (data['createdAt'] as Timestamp?)?.toDate();
    final dist   = _dist();
    final (icon, color) = _svcIcon(svc);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(svc,
                  style: const TextStyle(
                      color: _P.t1, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Row(children: [
                if (dist.isNotEmpty) ...[
                  const Icon(Icons.near_me_rounded, size: 11, color: _P.purple),
                  const SizedBox(width: 3),
                  Text(dist,
                      style: const TextStyle(
                          color: _P.purple, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3,
                      decoration: const BoxDecoration(
                          color: _P.t3, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                ],
                if (ts != null)
                  Text(_ago(ts),
                      style: const TextStyle(color: _P.t3, fontSize: 11)),
              ]),
            ])),
            Text('₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: _P.t1, fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),
        Divider(height: 1, color: _P.border),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            Expanded(flex: 3, child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _accept(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _P.green, foregroundColor: Colors.white,
                elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22)),
              ),
              child: Text(isHindi ? 'स्वीकार करें' : 'ACCEPT',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      letterSpacing: 0.6)),
            )),
            const SizedBox(width: 10),
            Expanded(flex: 2, child: TextButton(
              onPressed: _decline,
              style: TextButton.styleFrom(
                foregroundColor: _P.t2,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(isHindi ? 'मना करें' : 'DECLINE',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            )),
          ]),
        ),
      ]),
    );
  }

  Future<void> _accept(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    await FirebaseFirestore.instance
        .collection('bookings').doc(bookingId).update({
      'status': 'accepted',
      'helperId':   auth.helper?.uid,
      'helperName': auth.helper?.name,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
    if (context.mounted) {
      Navigator.push(context,
          SmoothRoute(page: IncomingBookingDetail(bookingId: bookingId)));
    }
  }

  Future<void> _decline() async {
    await FirebaseFirestore.instance
        .collection('bookings').doc(bookingId).update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }
}

// ── Visibility active empty card ──────────────────────────────────────────
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
// HOME TAB
// ═══════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatelessWidget {
  final Position? myPos;
  final VoidCallback? onGoJobs;
  const _HomeTab({this.myPos, this.onGoJobs});

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
            _StatsRow(uid: uid),
            const SizedBox(height: 18),
            _WaitingBanner(isHindi: isHindi, onTap: onGoJobs),
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

// ── Greeting header (Image-1 style) ───────────────────────────────────────
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
    if (h < 20) return 'Good Evening';
    return 'Good Night';
  }

  static String _emoji() {
    final h = DateTime.now().hour;
    if (h < 12) return '☀️';
    if (h < 17) return '🌤';
    if (h < 20) return '🌆';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final h        = widget.helper;
    final isOnline = h?.isOnline ?? false;
    final first    = (h?.name ?? 'Helper').split(' ').first;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 28, left: 20, right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_P.indigo, Color(0xFF4C1D95), _P.purple],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Welcome pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.25))),
            child: const Text('WELCOME BACK',
                style: TextStyle(color: Colors.white, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          const Spacer(),
          // Avatar + pulse
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 2)),
              child: Center(child: Text(h?.initials ?? 'SK',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 15, fontWeight: FontWeight.w800))),
            ),
            if (isOnline)
              Positioned(bottom: 0, right: 0,
                child: AnimatedBuilder(animation: _a, builder: (_, __) =>
                    Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                          color: AppColors.onlineGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(
                              color: AppColors.onlineGreen
                                  .withOpacity(_a.value * 0.8),
                              blurRadius: 8, spreadRadius: 2)]),
                    )),
              ),
          ]),
        ]),
        const SizedBox(height: 20),
        Text('${_greet()} ${_emoji()}, $first',
            style: const TextStyle(color: Colors.white,
                fontSize: 26, fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 16),
        // Location pill
        Container(
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
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white60, size: 15),
          ]),
        ),
      ]),
    );
  }
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

// ── Today earnings + goal ring ────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final String uid;
  final bool isHindi;
  const _EarningsCard({required this.uid, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    const goal  = 1500.0;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .snapshots(),
      builder: (ctx, snap) {
        double total = 0; int jobs = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m = d.data() as Map<String, dynamic>;
            total += ((m['amount'] ?? 0) as num).toDouble();
            jobs++;
          }
        }
        final pct = (total / goal).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: _P.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12, offset: const Offset(0, 3))]),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isHindi ? 'आज की कमाई' : "Today's Earnings",
                  style: const TextStyle(
                      color: _P.t2, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('₹ ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: _P.t1, fontSize: 28, fontWeight: FontWeight.w800)),
              if (jobs > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _P.green, size: 13),
                  const SizedBox(width: 4),
                  Text(
                      '$jobs ${isHindi ? 'काम पूरे' : 'job${jobs > 1 ? "s" : ""} done'}',
                      style: const TextStyle(
                          color: _P.green, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Text(isHindi ? 'लक्ष्य' : 'Daily Goal',
                    style: const TextStyle(color: _P.t3, fontSize: 10)),
                const Spacer(),
                Text('₹${total.toStringAsFixed(0)} / ₹${goal.toInt()}',
                    style: const TextStyle(
                        color: _P.t3, fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor: const Color(0xFFEDE9FE),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 1.0 ? _P.green : _P.purple),
                ),
              ),
            ])),
            const SizedBox(width: 18),
            SizedBox(width: 80, height: 80,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(80, 80),
                    painter: _RingPainter(pct: pct)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(pct * 100).toInt()}%',
                      style: const TextStyle(
                          color: _P.t1, fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(isHindi ? 'लक्ष्य' : 'goal',
                      style: const TextStyle(color: _P.t3, fontSize: 9)),
                ]),
              ]),
            ),
          ]),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  const _RingPainter({required this.pct});
  @override
  void paint(Canvas c, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2, r = cx - 6;
    final track = Paint()
      ..color = const Color(0xFFEDE9FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = const LinearGradient(colors: [_P.purple, Color(0xFF06B6D4)])
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    c.drawCircle(Offset(cx, cy), r, track);
    if (pct > 0) {
      c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -math.pi / 2, 2 * math.pi * pct, false, fill);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.pct != pct;
}

// ── Stats row ─────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String uid;
  const _StatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpers').doc(uid).snapshots(),
      builder: (ctx, snap) {
        double rating = 0; int reviews = 0, done = 0;
        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>? ?? {};
          rating  = ((d['rating'] ?? 0) as num).toDouble();
          reviews = ((d['totalReviews'] ?? 0) as num).toInt();
          done    = ((d['completedJobs'] ?? 0) as num).toInt();
        }
        return Row(children: [
          Expanded(child: _StatChip(
              icon: Icons.star_rounded, color: _P.amber, label: 'RATING',
              value: rating == 0 ? '–' : rating.toStringAsFixed(1),
              sub: reviews > 0 ? '$reviews reviews' : 'No reviews')),
          const SizedBox(width: 12),
          Expanded(child: _StatChip(
              icon: Icons.check_circle_rounded, color: _P.green,
              label: 'JOBS DONE', value: '$done',
              sub: '$done completed')),
        ]);
      },
    );
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

// ── Waiting banner (taps to Jobs) ─────────────────────────────────────────
class _WaitingBanner extends StatelessWidget {
  final bool isHindi;
  final VoidCallback? onTap;
  const _WaitingBanner({required this.isHindi, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (ctx, snap) {
        final n = snap.data?.docs.length ?? 0;
        if (n == 0) return const SizedBox.shrink();
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
                    '$n ${isHindi ? 'नए अनुरोध' : 'New Request${n > 1 ? "s" : ""}'}',
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
      },
    );
  }
}

// ── Recent activity list ──────────────────────────────────────────────────
class _ActivityList extends StatelessWidget {
  final String uid;
  const _ActivityList({required this.uid});

  static (IconData, Color) _meta(String s) {
    switch (s.toLowerCase()) {
      case 'completed':   return (Icons.check_circle_rounded,  _P.green);
      case 'accepted':    return (Icons.handshake_rounded,     _P.purple);
      case 'in_progress': return (Icons.play_circle_rounded,   AppColors.onlineGreen);
      case 'pending':     return (Icons.pending_rounded,       _P.amber);
      default:            return (Icons.cancel_rounded,        AppColors.danger);
    }
  }

  static String _ago(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    return '${d.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('helperId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: _P.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _P.border)),
            child: const Center(child: Text('No activity yet',
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
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(children: snap.data!.docs.asMap().entries.map((e) {
            final d      = e.value.data() as Map<String, dynamic>;
            final status = d['status'] as String? ?? 'pending';
            final svc    = d['serviceName'] as String? ?? 'Service';
            final amt    = ((d['amount'] ?? 0) as num).toDouble();
            final ts     = (d['createdAt'] as Timestamp?)?.toDate();
            final isLast = e.key == snap.data!.docs.length - 1;
            final (icon, color) = _meta(status);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                child: Row(children: [
                  Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(svc,
                            style: const TextStyle(
                                color: _P.t1, fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text(status.toUpperCase(),
                            style: const TextStyle(
                                color: _P.t3, fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5)),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(status == 'completed'
                        ? '+₹${amt.toStringAsFixed(0)}'
                        : '₹${amt.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: status == 'completed' ? _P.green : _P.t2,
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    if (ts != null)
                      Text(_ago(ts),
                          style: const TextStyle(color: _P.t3, fontSize: 10)),
                  ]),
                ]),
              ),
              if (!isLast)
                Divider(height: 1, color: _P.div, indent: 14, endIndent: 14),
            ]);
          }).toList()),
        );
      },
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

// ─── Online toggle button — locked until profile complete + KYC approved ────
// ─── Online toggle button — locked until profile complete + KYC approved ────
class _OnlineToggleBtn extends StatelessWidget {
  final HelperModel? helper;
  final bool isHindi, isOnline;
  const _OnlineToggleBtn(
      {required this.helper, required this.isHindi, required this.isOnline});

  bool _canGoOnline(Map<String, dynamic> d) {
    // ✅ FIX: Check BOTH status=='approved' OR kycStatus=='approved'
    final kycApproved = helper?.isApproved ?? false;
    if (!kycApproved) return false;
    final checks = [
      (helper?.name ?? '').isNotEmpty,
      (helper?.phone ?? '').isNotEmpty,
      (helper?.area ?? '').isNotEmpty,
      (helper?.services ?? []).isNotEmpty,
      (d['serviceType'] as String? ?? '').isNotEmpty,
      (d['description'] as String? ?? '').isNotEmpty,
      (d['experience']  as String? ?? '').isNotEmpty,
      ((d['pricePerVisit'] ?? 0) as num) > 0,
      (d['skills'] as List? ?? []).isNotEmpty,
    ];
    return checks.every((b) => b);
  }

  @override
  Widget build(BuildContext context) {
    final uid = helper?.uid ?? '';
    if (uid.isEmpty) return _lockedChip(context, isHindi);
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpers').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final canToggle = _canGoOnline(d);
        if (!canToggle) return _lockedChip(context, isHindi);
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
                borderRadius: BorderRadius.circular(22)),
            child: Text(
              isOnline
                  ? (isHindi ? 'ऑनलाइन' : 'ACTIVE')
                  : (isHindi ? 'लाइव जाएं' : 'GO LIVE'),
              style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w800,
                  letterSpacing: 0.5),
            ),
          ),
        );
      },
    );
  }

  Widget _lockedChip(BuildContext context, bool hi) {
    return GestureDetector(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(hi
            ? 'प्रोफ़ाइल 100% पूरी करें और KYC अनुमोदित कराएं'
            : 'Complete 100% profile & get KYC approved to go online'),
        backgroundColor: _P.amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _P.amber.withOpacity(0.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.lock_rounded, color: _P.amber, size: 12),
          const SizedBox(width: 5),
          Text(hi ? 'लॉक्ड' : 'LOCKED',
              style: const TextStyle(
                  color: _P.amber, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// KYC STATUS SCREENS (unchanged logic, light-theme only)
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
      action: _KycBtn(label: 'Upload KYC Documents',
          icon: Icons.upload_rounded,
          onTap: (ctx) => Navigator.push(
              ctx, SmoothRoute(page: const KycScreen()))));
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
      action: _KycBtn(
          label: 'Check Status', icon: Icons.refresh_rounded, outline: true,
          onTap: (ctx) => ctx.read<AuthProvider>().refreshProfile()));
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
      action: _KycBtn(
          label: 'Re-upload Documents', icon: Icons.upload_rounded,
          color: AppColors.danger,
          onTap: (ctx) => Navigator.push(
              ctx, SmoothRoute(page: const KycScreen()))));
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
      action: null);
}

// ── KYC shell ─────────────────────────────────────────────────────────────
class _KycShell extends StatelessWidget {
  final HelperModel helper;
  final Color color;
  final String label, title, body;
  final IconData icon;
  final List<(String, bool)> steps;
  final Widget? action;
  const _KycShell({
    required this.helper, required this.color,
    required this.label, required this.title, required this.body,
    required this.icon, required this.steps, required this.action,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _P.bg,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(children: [
        // top bar
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
        if (action != null) action!,
        const SizedBox(height: 12),
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