// lib/screens/dashboard/helper_dashboard.dart
// ═══════════════════════════════════════════════════════════════════════════
//  SARTHI KENDRA — Complete Dashboard Redesign
//  Reference: Images 1-3 (Kinetic Editorial style, light theme)
//
//  Architecture:
//    Tab 0 — JOBS  (primary, badge count)
//    Tab 1 — HOME  (summary dashboard)
//    Tab 2 — EARN  (day/week/month toggle + bar chart)
//    Tab 3 — ME    (profile, UPI, language, support)
//
//  Features:
//    • Image-1 style greeting header (welcome pill + emoji + location pill)
//    • Image-2/3 style Jobs tab (status banner, live timer, quick replies,
//      dominant ACCEPT / ghost DECLINE, distance, service icons)
//    • Background GPS → Firestore (no visible map on home)
//    • Full Firestore backend: accept · decline · quick-reply · mark-complete
//    • Earnings tab: day/week/month + bar chart + withdrawal button
//    • Me tab: UPI details, language toggle, support, logout
//    • KYC gates unchanged
//
//  pubspec.yaml additions:
//    url_launcher: ^6.2.5
//    fl_chart: ^0.68.0        ← for earnings bar chart
//    (google_maps_flutter + geolocator already present)
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
import '../jobs/ongoing_job_screen.dart';
import '../support/support_screen.dart';
import '../../widgets/notification_bell.dart';

// ───────────────────────────────────────────────────────────────────────────
// Design tokens (light-first palette matching reference images)
// ───────────────────────────────────────────────────────────────────────────
class _C {
  // backgrounds
  static const bg       = Color(0xFFF4F3FF);   // very pale lavender
  static const white    = Colors.white;

  // brand
  static const purple   = Color(0xFF7C3AED);
  static const indigo   = Color(0xFF2D1B69);
  static const violet   = Color(0xFF5B21B6);

  // semantic
  static const green    = Color(0xFF16A34A);
  static const amber    = Color(0xFFF59E0B);
  static const red      = Color(0xFFEF4444);
  static const cyan     = Color(0xFF06B6D4);

  // text
  static const t1       = Color(0xFF1E1B4B);   // primary
  static const t2       = Color(0xFF64748B);   // secondary
  static const t3       = Color(0xFF94A3B8);   // muted

  // borders / dividers
  static const border   = Color(0xFFEDE9FE);
  static const divider  = Color(0xFFF1F0FF);
}

// ───────────────────────────────────────────────────────────────────────────
// Root scaffold
// ───────────────────────────────────────────────────────────────────────────
class HelperDashboard extends StatefulWidget {
  const HelperDashboard({super.key});
  @override
  State<HelperDashboard> createState() => _HelperDashboardState();
}

class _HelperDashboardState extends State<HelperDashboard>
    with SingleTickerProviderStateMixin {

  // ── tabs ─────────────────────────────────────────────────────────
  int _tab = 0;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // ── location (background, silent) ────────────────────────────────
  StreamSubscription<Position>? _locSub;
  Position? _myPos;

  // ── Jobs-tab badge counter ────────────────────────────────────────
  StreamSubscription<QuerySnapshot>? _badgeSub;
  int _pendingCount = 0;

  // ── Firestore ref ─────────────────────────────────────────────────
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
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

  // ── background GPS ────────────────────────────────────────────────
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
    _db.collection('helpers').doc(uid).update({
      'location': GeoPoint(pos.latitude, pos.longitude),
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  // ── badge counter ─────────────────────────────────────────────────
  void _initBadge() {
    _badgeSub = _db.collection('bookings')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((s) {
      if (mounted) setState(() => _pendingCount = s.docs.length);
    });
  }

  // ── tab switch ────────────────────────────────────────────────────
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // KYC gates
    if (helper != null) {
      if (helper.isPending)   return _KycPending(helper: helper);
      if (helper.isSubmitted) return _KycUnderReview(helper: helper);
      if (helper.isRejected)  return _KycRejected(helper: helper);
      if (helper.isInactive)  return _KycInactive(helper: helper);
    }

    final pages = [
      _JobsTab(myPos: _myPos, pendingCount: _pendingCount, onHomeTab: () => _switchTab(1)),
      _HomeTab(myPos: _myPos, onGoJobs: () => _switchTab(0)),
      const _EarnTab(),
      const _MeTab(),
    ];

    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : _C.bg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(index: _tab, children: pages),
      ),
      bottomNavigationBar: _NavBar(
        selected: _tab,
        onSelect: _switchTab,
        isDark: isDark,
        lang: lang,
        badge: _pendingCount,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM NAV  (4 tabs, red badge on JOBS)
// ═══════════════════════════════════════════════════════════════════════════
class _NavBar extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  final bool isDark;
  final LanguageProvider lang;
  final int badge;
  const _NavBar({
    required this.selected, required this.onSelect,
    required this.isDark, required this.lang, required this.badge,
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
        color: isDark ? AppColors.cardDark : _C.white,
        border: Border(
          top: BorderSide(
              color: isDark ? AppColors.borderDark : const Color(0xFFECEBFF),
              width: 1),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.22 : 0.07),
              blurRadius: 20, offset: const Offset(0, -4)),
        ],
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
                    color: sel ? _C.purple.withOpacity(0.10) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      Icon(
                        sel ? fill : out, size: 24,
                        color: sel ? _C.purple
                            : (isDark ? AppColors.textSoftDark : _C.t3),
                      ),
                      if (hasBadge)
                        Positioned(
                          top: -5, right: -8,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 17),
                            height: 17,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                                color: _C.red,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                    color: isDark ? AppColors.cardDark : _C.white,
                                    width: 1.5)),
                            child: Center(child: Text(
                              badge > 9 ? '9+' : '$badge',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9,
                                  fontWeight: FontWeight.w800),
                            )),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(lbl, style: TextStyle(
                      fontSize: 9,
                      fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                      color: sel ? _C.purple
                          : (isDark ? AppColors.textSoftDark : _C.t3),
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
  final VoidCallback? onHomeTab;
  const _JobsTab({this.myPos, required this.pendingCount, this.onHomeTab});

  @override
  Widget build(BuildContext context) {
    final helper  = context.watch<AuthProvider>().helper;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LanguageProvider>().isHindi;
    final uid     = helper?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : _C.bg,
      body: CustomScrollView(slivers: [
        // ── compact purple header (image-2 style) ──────────────
        SliverToBoxAdapter(child: _CompactHeader(
            helper: helper, isDark: isDark, isHindi: isHindi)),
        // ── status banner ──────────────────────────────────────
        SliverToBoxAdapter(child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _StatusBanner(
              helper: helper, count: pendingCount,
              isDark: isDark, isHindi: isHindi),
        )),
        // ── body ───────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Ongoing job
            _OngoingJobSection(uid: uid, isDark: isDark, isHindi: isHindi),
            // Section header
            _SecHead(
              title: isHindi ? 'नए अनुरोध' : 'Pending Requests',
              badge: pendingCount > 0 ? '${pendingCount} Nearby' : null,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            // Request list
            _PendingList(uid: uid, isDark: isDark, isHindi: isHindi, myPos: myPos),
            const SizedBox(height: 22),
            // Job history
            _HistoryBtn(isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 12),
          ])),
        ),
      ]),
    );
  }
}

// ── compact header (image-2: avatar + name + ONLINE chip) ────────
class _CompactHeader extends StatelessWidget {
  final HelperModel? helper;
  final bool isDark, isHindi;
  const _CompactHeader(
      {required this.helper, required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    final isOnline = helper?.isOnline ?? false;
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14, left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [_C.indigo, _C.violet, _C.purple],
        ),
      ),
      child: Row(children: [
        // avatar
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.32), width: 2)),
          child: Center(child: Text(helper?.initials ?? 'SK',
              style: const TextStyle(color: Colors.white,
                  fontSize: 14, fontWeight: FontWeight.w800))),
        ),
        const SizedBox(width: 11),
        // name
        Expanded(child: Text(helper?.name ?? 'Helper',
            style: const TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w700))),
        // ONLINE chip
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
            Text(
              isOnline
                  ? (isHindi ? 'ऑनलाइन' : 'ONLINE')
                  : (isHindi ? 'ऑफलाइन' : 'OFFLINE'),
              style: const TextStyle(color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        const NotificationBell(isDark: false),
      ]),
    );
  }
}

// ── status banner (image-2: wifi icon + text + ACTIVE pill) ──────
class _StatusBanner extends StatelessWidget {
  final HelperModel? helper;
  final int count;
  final bool isDark, isHindi;
  const _StatusBanner({
    required this.helper, required this.count,
    required this.isDark, required this.isHindi,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = helper?.isOnline ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isOnline
                ? AppColors.onlineGreen.withOpacity(0.25)
                : (isDark ? AppColors.borderDark : _C.border)),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        // wifi icon
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: (isOnline ? AppColors.onlineGreen : _C.t3).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.wifi_tethering_rounded,
              color: isOnline ? AppColors.onlineGreen : _C.t3, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isOnline
              ? (isHindi ? 'आप ऑनलाइन हैं' : "You're Online")
              : (isHindi ? 'आप ऑफलाइन हैं' : "You're Offline"),
              style: TextStyle(
                  color: isDark ? Colors.white : _C.t1,
                  fontSize: 14, fontWeight: FontWeight.w700)),
          Text(count > 0
              ? '$count ${isHindi ? 'अनुरोध पास में' : 'Request${count > 1 ? "s" : ""} nearby'}'
              : (isHindi ? 'पास में कोई अनुरोध नहीं' : 'No requests nearby'),
              style: TextStyle(
                  color: isDark ? AppColors.textMidDark : _C.t2,
                  fontSize: 11)),
        ])),
        // Toggle pill
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.read<AuthProvider>().toggleOnlineStatus();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: isOnline ? AppColors.onlineGreen : _C.purple,
                borderRadius: BorderRadius.circular(22)),
            child: Text(
              isOnline
                  ? (isHindi ? 'ऑनलाइन' : 'ACTIVE')
                  : (isHindi ? 'लाइव जाएं' : 'GO LIVE'),
              style: const TextStyle(color: Colors.white,
                  fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── ongoing job section ───────────────────────────────────────────
class _OngoingJobSection extends StatelessWidget {
  final String uid;
  final bool isDark, isHindi;
  const _OngoingJobSection(
      {required this.uid, required this.isDark, required this.isHindi});

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
            Text('ONGOING JOB', style: TextStyle(
                color: isDark ? Colors.white : _C.t1,
                fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            _Chip(label: 'IN PROGRESS', bg: AppColors.onlineGreen.withOpacity(0.12),
                fg: AppColors.onlineGreen),
          ]),
          const SizedBox(height: 12),
          _OngoingCard(
              bookingId: doc.id, data: d,
              uid: uid, isDark: isDark, isHindi: isHindi),
          const SizedBox(height: 26),
        ]);
      },
    );
  }
}

// ── ongoing card (stateful: live timer + backend actions) ─────────
class _OngoingCard extends StatefulWidget {
  final String bookingId, uid;
  final Map<String, dynamic> data;
  final bool isDark, isHindi;
  const _OngoingCard({
    required this.bookingId, required this.uid, required this.data,
    required this.isDark, required this.isHindi,
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
    final start = (widget.data['acceptedAt'] as Timestamp?)?.toDate() ?? DateTime.now();
    _elapsed = DateTime.now().difference(start);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  String get _clock {
    final h = _elapsed.inHours.toString().padLeft(2, '0');
    final m = (_elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── quick reply → Firestore chat ──────────────────────────────
  Future<void> _reply(String msg) async {
    HapticFeedback.lightImpact();
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final msgRef = db.collection('chats').doc(widget.bookingId)
        .collection('messages').doc();
    batch.set(msgRef, {
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
      backgroundColor: _C.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── mark complete ─────────────────────────────────────────────
  Future<void> _complete() async {
    setState(() => _completing = true);
    try {
      final db = FirebaseFirestore.instance;
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
          backgroundColor: _C.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  // ── open in maps ──────────────────────────────────────────────
  Future<void> _openMaps() async {
    final loc  = widget.data['userLocation'] as GeoPoint?;
    final addr = widget.data['address'] as String?
        ?? widget.data['userAddress'] as String? ?? '';
    Uri uri;
    if (loc != null) {
      uri = Uri.parse('https://maps.google.com/?q=${loc.latitude},${loc.longitude}');
    } else if (addr.isNotEmpty) {
      uri = Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(addr)}');
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
    final isDark  = widget.isDark;
    final isHindi = widget.isHindi;

    final replies = isHindi
        ? ['मैं रास्ते पर हूँ', 'पहुँच गया', 'काम शुरू हुआ', '5 मिनट में आता हूँ']
        : ["I'm on my way", 'Arrived at location', 'Job started', '5 mins away'];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : _C.border),
        boxShadow: [BoxShadow(
            color: _C.purple.withOpacity(0.07),
            blurRadius: 18, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        // ── timer strip ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.15)
                : const Color(0xFFF5F3FF),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // clock (image-2: large violet)
              Text(_clock, style: const TextStyle(
                  color: _C.purple, fontSize: 28, fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontFeatures: [FontFeature.tabularFigures()])),
              Text('CURRENT SESSION TIME', style: TextStyle(
                  color: isDark ? AppColors.textSoftDark : _C.t3,
                  fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            ]),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('₹${amount.toStringAsFixed(2)}', style: TextStyle(
                  color: isDark ? Colors.white : _C.t1,
                  fontSize: 22, fontWeight: FontWeight.w800)),
              Text('Fixed Rate', style: TextStyle(
                  color: isDark ? AppColors.textSoftDark : _C.t3, fontSize: 10)),
            ]),
          ]),
        ),

        // ── address block ───────────────────────────────────────
        if (address.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.10)
                    : const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isDark ? AppColors.borderDark : _C.border),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, color: _C.purple, size: 15),
                const SizedBox(width: 8),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('DESTINATION', style: TextStyle(
                      color: isDark ? AppColors.textSoftDark : _C.t3,
                      fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                  const SizedBox(height: 3),
                  Text(address, style: TextStyle(
                      color: isDark ? Colors.white : _C.t1,
                      fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _openMaps,
                    child: const Text('Open in Maps ↗',
                        style: TextStyle(
                            color: _C.purple, fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ])),
              ]),
            ),
          ),

        // ── quick replies ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('QUICK REPLIES', style: TextStyle(
                color: isDark ? AppColors.textSoftDark : _C.t3,
                fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 7,
              children: replies.map((r) => GestureDetector(
                onTap: () => _reply(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 7),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : _C.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: isDark ? AppColors.borderDark
                              : const Color(0xFFDDD6FE))),
                  child: Text(r, style: TextStyle(
                      color: isDark ? AppColors.textMidDark : _C.t2,
                      fontSize: 12, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ]),
        ),

        // ── mark complete (image-2: full-width dark green) ──────
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
              label: Text(isHindi ? 'काम पूरा करें' : 'Mark Complete',
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

// ── pending requests list ─────────────────────────────────────────
class _PendingList extends StatelessWidget {
  final String uid;
  final bool isDark, isHindi;
  final Position? myPos;
  const _PendingList({
    required this.uid, required this.isDark,
    required this.isHindi, this.myPos,
  });

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
          return _VisibilityCard(isDark: isDark, isHindi: isHindi);
        }
        return Column(
          children: snap.data!.docs.map((doc) => _RequestCard(
            bookingId: doc.id,
            data: doc.data() as Map<String, dynamic>,
            uid: uid, isDark: isDark, isHindi: isHindi, myPos: myPos,
          )).toList(),
        );
      },
    );
  }
}

// ── single request card (image-2: service icon, distance, ₹, ACCEPT+DECLINE)
class _RequestCard extends StatelessWidget {
  final String bookingId, uid;
  final Map<String, dynamic> data;
  final bool isDark, isHindi;
  final Position? myPos;
  const _RequestCard({
    required this.bookingId, required this.uid, required this.data,
    required this.isDark, required this.isHindi, this.myPos,
  });

  // distance string
  String _dist() {
    final loc = data['userLocation'] as GeoPoint?;
    if (loc == null || myPos == null) return '';
    final m = Geolocator.distanceBetween(
        myPos!.latitude, myPos!.longitude, loc.latitude, loc.longitude);
    return m < 1000
        ? '${m.toInt()} m away'
        : '${(m / 1000).toStringAsFixed(1)} km away';
  }

  // time ago
  String _ago(DateTime? dt) {
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }

  // service icon + color
  static (IconData, Color) _svcIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('plumb'))   return (Icons.plumbing_rounded,             Color(0xFF0EA5E9));
    if (n.contains('electr'))  return (Icons.electrical_services_rounded,  Color(0xFFF59E0B));
    if (n.contains('clean'))   return (Icons.cleaning_services_rounded,    Color(0xFF10B981));
    if (n.contains('carpen') || n.contains('wood'))
      return (Icons.handyman_rounded, Color(0xFF8B5CF6));
    if (n.contains('paint'))   return (Icons.format_paint_rounded,         Color(0xFFEF4444));
    if (n.contains('ac') || n.contains('air'))
      return (Icons.ac_unit_rounded, Color(0xFF06B6D4));
    if (n.contains('pest'))    return (Icons.pest_control_rounded,         Color(0xFF84CC16));
    if (n.contains('laundry') || n.contains('wash'))
      return (Icons.local_laundry_service_rounded, Color(0xFF6366F1));
    if (n.contains('garden') || n.contains('yard'))
      return (Icons.yard_rounded, Color(0xFF22C55E));
    if (n.contains('pet'))     return (Icons.pets_rounded,                 Color(0xFFF97316));
    if (n.contains('secur') || n.contains('lock'))
      return (Icons.security_rounded, Color(0xFF64748B));
    return (Icons.home_repair_service_rounded, _C.purple);
  }

  @override
  Widget build(BuildContext context) {
    final svc    = data['serviceName'] as String? ?? 'Service';
    final user   = data['userName']    as String? ?? 'Customer';
    final amount = ((data['amount'] ?? 0) as num).toDouble();
    final ts     = (data['createdAt'] as Timestamp?)?.toDate();
    final dist   = _dist();
    final (icon, color) = _svcIcon(svc);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.borderDark : _C.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // info
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            // service icon box
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
              Text(svc, style: TextStyle(
                  color: isDark ? Colors.white : _C.t1,
                  fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              // distance + time row (image-2 style)
              Row(children: [
                if (dist.isNotEmpty) ...[
                  const Icon(Icons.near_me_rounded, size: 11, color: _C.purple),
                  const SizedBox(width: 3),
                  Text(dist, style: const TextStyle(
                      color: _C.purple, fontSize: 11,
                      fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(width: 3, height: 3, decoration: BoxDecoration(
                      color: _C.t3, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                ],
                if (ts != null)
                  Text(_ago(ts), style: TextStyle(
                      color: isDark ? AppColors.textSoftDark : _C.t3,
                      fontSize: 11)),
              ]),
            ])),
            // amount (image-2: large, right)
            Text('₹${amount.toStringAsFixed(0)}', style: TextStyle(
                color: isDark ? Colors.white : _C.t1,
                fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
        ),

        Divider(height: 1, color: isDark ? AppColors.borderDark : _C.border),

        // buttons (image-2: green ACCEPT pill / plain DECLINE text)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            // ACCEPT — dominant green pill
            Expanded(flex: 3, child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                _accept(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.green, foregroundColor: Colors.white,
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
            // DECLINE — ghost text (image-2 style)
            Expanded(flex: 2, child: TextButton(
              onPressed: _decline,
              style: TextButton.styleFrom(
                foregroundColor: isDark ? AppColors.textMidDark : _C.t2,
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

// ── visibility active (empty state, image-2 bottom card) ─────────
class _VisibilityCard extends StatelessWidget {
  final bool isDark, isHindi;
  const _VisibilityCard({required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
    decoration: BoxDecoration(
      color: isDark ? AppColors.cardDark : const Color(0xFFF0EEFF),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFDDD6FE)),
    ),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
            color: _C.purple.withOpacity(0.10), shape: BoxShape.circle),
        child: const Icon(Icons.gps_fixed_rounded, color: _C.purple, size: 28),
      ),
      const SizedBox(height: 16),
      Text(isHindi ? 'विज़िबिलिटी एक्टिव' : 'Visibility Active',
          style: TextStyle(
              color: isDark ? Colors.white : _C.purple,
              fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      RichText(text: TextSpan(
        style: TextStyle(
            color: isDark ? AppColors.textMidDark : _C.t2,
            fontSize: 13, height: 1.6),
        children: [
          TextSpan(text: isHindi
              ? 'आप ऑनलाइन हैं और '
              : "You're online and visible to customers in a "),
          const TextSpan(text: '5 km radius',
              style: TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: isHindi
              ? ' के ग्राहकों को दिख रहे हैं।\nनए अनुरोध तुरंत यहाँ दिखेंगे।'
              : '. New requests will appear here instantly.'),
        ],
      )),
    ]),
  );
}

// ── history button ────────────────────────────────────────────────
class _HistoryBtn extends StatelessWidget {
  final bool isDark, isHindi;
  const _HistoryBtn({required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.push(
        context, SmoothRoute(page: const JobHistoryScreen())),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.borderDark : _C.border)),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
              color: _C.purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.work_history_rounded,
              color: _C.purple, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(
            isHindi ? 'सभी पुराने काम देखें' : 'View All Job History',
            style: TextStyle(
                color: isDark ? Colors.white : _C.t1,
                fontSize: 14, fontWeight: FontWeight.w600))),
        Icon(Icons.arrow_forward_ios_rounded, size: 12,
            color: isDark ? AppColors.textSoftDark : _C.t3),
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
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final uid     = helper?.uid ?? '';
    final isHindi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : _C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _GreetingHeader(helper: helper)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // 1. Online toggle
            _ToggleCard(helper: helper, isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 14),
            // 2. Today's earnings + goal ring
            _EarningsCard(uid: uid, isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 14),
            // 3. Stats chips
            _StatsRow(uid: uid, isDark: isDark),
            const SizedBox(height: 18),
            // 4. Requests waiting banner
            _WaitingBanner(isDark: isDark, isHindi: isHindi, onTap: onGoJobs),
            const SizedBox(height: 22),
            // 5. Recent activity
            _SecHead(title: isHindi ? 'हालिया गतिविधि' : 'Recent Activity',
                isDark: isDark),
            const SizedBox(height: 12),
            _ActivityList(uid: uid, isDark: isDark),
          ])),
        ),
      ]),
    );
  }
}

// ── greeting header (image-1 style) ──────────────────────────────
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
    _p = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _a = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _p, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _p.dispose(); super.dispose(); }

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
          colors: [_C.indigo, Color(0xFF4C1D95), _C.purple],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Row: welcome pill + avatar with pulse
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // welcome pill (image-1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.25))),
            child: const Text('WELCOME BACK', style: TextStyle(
                color: Colors.white, fontSize: 9,
                fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ),
          const Spacer(),
          // avatar + pulse dot (image-1 right side)
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.35), width: 2)),
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
                              color: AppColors.onlineGreen.withOpacity(_a.value * 0.8),
                              blurRadius: 8, spreadRadius: 2)]),
                    )),
              ),
          ]),
        ]),
        const SizedBox(height: 20),
        // greeting (image-1)
        Text('${_greet()} ${_emoji()}, $first', style: const TextStyle(
            color: Colors.white, fontSize: 26,
            fontWeight: FontWeight.w800, height: 1.2)),
        const SizedBox(height: 16),
        // location pill (image-1)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.22))),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.location_on_rounded, color: Colors.white70, size: 13),
            SizedBox(width: 5),
            Text('Surat, Gujarat', style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white60, size: 15),
          ]),
        ),
      ]),
    );
  }
}

// ── online toggle ─────────────────────────────────────────────────
class _ToggleCard extends StatelessWidget {
  final HelperModel? helper;
  final bool isDark, isHindi;
  const _ToggleCard(
      {required this.helper, required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) {
    final on = helper?.isOnline ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : _C.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: on
                  ? AppColors.onlineGreen.withOpacity(0.25)
                  : (isDark ? AppColors.borderDark : _C.border)),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.10 : 0.04),
              blurRadius: 8, offset: const Offset(0, 2))]),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('SERVICE STATUS', style: TextStyle(
              color: isDark ? AppColors.textSoftDark : _C.t3,
              fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(on
              ? (isHindi ? 'अभी ऑनलाइन हैं' : 'Currently Online')
              : (isHindi ? 'अभी ऑफलाइन हैं' : 'Currently Offline'),
              style: TextStyle(
                  color: isDark ? Colors.white : _C.t1,
                  fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const Spacer(),
        Transform.scale(scale: 1.1, child: Switch(
          value: on, activeColor: AppColors.onlineGreen,
          onChanged: (_) {
            HapticFeedback.mediumImpact();
            context.read<AuthProvider>().toggleOnlineStatus();
          },
        )),
      ]),
    );
  }
}

// ── today earnings + goal ring ────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final String uid;
  final bool isDark, isHindi;
  const _EarningsCard(
      {required this.uid, required this.isDark, required this.isHindi});

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
              color: isDark ? AppColors.cardDark : _C.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : _C.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.10 : 0.04),
                  blurRadius: 12, offset: const Offset(0, 3))]),
          child: Row(children: [
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(isHindi ? 'आज की कमाई' : "Today's Earnings",
                  style: TextStyle(
                      color: isDark ? AppColors.textMidDark : _C.t2,
                      fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('₹ ${total.toStringAsFixed(2)}', style: TextStyle(
                  color: isDark ? Colors.white : _C.t1,
                  fontSize: 28, fontWeight: FontWeight.w800)),
              if (jobs > 0) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.check_circle_rounded, color: _C.green, size: 13),
                  const SizedBox(width: 4),
                  Text('$jobs ${isHindi ? 'काम पूरे' : 'job${jobs > 1 ? "s" : ""} done'}',
                      style: const TextStyle(
                          color: _C.green, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Text(isHindi ? 'लक्ष्य' : 'Daily Goal', style: TextStyle(
                    color: isDark ? AppColors.textSoftDark : _C.t3,
                    fontSize: 10)),
                const Spacer(),
                Text('₹${total.toStringAsFixed(0)} / ₹${goal.toInt()}',
                    style: TextStyle(
                        color: isDark ? AppColors.textSoftDark : _C.t3,
                        fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 5,
                  backgroundColor:
                  isDark ? AppColors.borderDark : const Color(0xFFEDE9FE),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      pct >= 1.0 ? _C.green : _C.purple),
                ),
              ),
            ])),
            const SizedBox(width: 18),
            SizedBox(width: 80, height: 80,
              child: Stack(alignment: Alignment.center, children: [
                CustomPaint(size: const Size(80, 80),
                    painter: _RingPainter(pct: pct, isDark: isDark)),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(pct * 100).toInt()}%', style: TextStyle(
                      color: isDark ? Colors.white : _C.t1,
                      fontSize: 16, fontWeight: FontWeight.w800)),
                  Text(isHindi ? 'लक्ष्य' : 'goal', style: TextStyle(
                      color: isDark ? AppColors.textSoftDark : _C.t3,
                      fontSize: 9)),
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
  final double pct; final bool isDark;
  const _RingPainter({required this.pct, required this.isDark});
  @override
  void paint(Canvas c, Size sz) {
    final cx = sz.width / 2, cy = sz.height / 2, r = cx - 6;
    final track = Paint()
      ..color = isDark ? const Color(0xFF3B2070) : const Color(0xFFEDE9FE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..shader = const LinearGradient(
          colors: [_C.purple, Color(0xFF06B6D4)])
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 ..strokeCap = StrokeCap.round;
    c.drawCircle(Offset(cx, cy), r, track);
    if (pct > 0) {
      c.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -math.pi / 2, 2 * math.pi * pct, false, fill);
    }
  }
  @override bool shouldRepaint(_RingPainter o) => o.pct != pct;
}

// ── stats row ─────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String uid; final bool isDark;
  const _StatsRow({required this.uid, required this.isDark});

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
              icon: Icons.star_rounded, color: _C.amber, label: 'RATING',
              value: rating == 0 ? '–' : rating.toStringAsFixed(1),
              sub: reviews > 0 ? '$reviews reviews' : 'No reviews',
              isDark: isDark)),
          const SizedBox(width: 12),
          Expanded(child: _StatChip(
              icon: Icons.check_circle_rounded, color: _C.green,
              label: 'JOBS DONE', value: '$done',
              sub: '$done completed', isDark: isDark)),
        ]);
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon; final Color color;
  final String label, value, sub; final bool isDark;
  const _StatChip({
    required this.icon, required this.color,
    required this.label, required this.value,
    required this.sub, required this.isDark,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : _C.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.10 : 0.03),
            blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(
          color: isDark ? AppColors.textSoftDark : _C.t3,
          fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
      const SizedBox(height: 8),
      Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 7),
        Text(value, style: TextStyle(
            color: isDark ? Colors.white : _C.t1,
            fontSize: 22, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 2),
      Text(sub, style: TextStyle(
          color: isDark ? AppColors.textMidDark : _C.t2, fontSize: 11)),
    ]),
  );
}

// ── waiting banner ────────────────────────────────────────────────
class _WaitingBanner extends StatelessWidget {
  final bool isDark, isHindi;
  final VoidCallback? onTap;
  const _WaitingBanner(
      {required this.isDark, required this.isHindi, this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('status', isEqualTo: 'pending').snapshots(),
      builder: (ctx, snap) {
        final n = snap.data?.docs.length ?? 0;
        if (n == 0) return const SizedBox.shrink();
        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _C.purple.withOpacity(0.07),
                _C.purple.withOpacity(0.02),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.purple.withOpacity(0.18)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: _C.purple.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12)),
                child: Stack(alignment: Alignment.center, children: [
                  const Icon(Icons.notifications_active_rounded,
                      color: _C.purple, size: 22),
                  Positioned(top: 6, right: 6, child: Container(
                      width: 8, height: 8, decoration: const BoxDecoration(
                      color: _C.red, shape: BoxShape.circle))),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$n ${isHindi ? 'नए अनुरोध' : 'New Request${n > 1 ? "s" : ""}'}',
                    style: TextStyle(
                        color: isDark ? Colors.white : _C.t1,
                        fontSize: 14, fontWeight: FontWeight.w700)),
                Text(isHindi ? 'जॉब्स टैब पर देखें' : 'Tap to view in Jobs tab',
                    style: TextStyle(
                        color: isDark ? AppColors.textMidDark : _C.t2,
                        fontSize: 11)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: _C.purple),
            ]),
          ),
        );
      },
    );
  }
}

// ── recent activity list ──────────────────────────────────────────
class _ActivityList extends StatelessWidget {
  final String uid; final bool isDark;
  const _ActivityList({required this.uid, required this.isDark});

  static (IconData, Color) _meta(String s) {
    switch (s.toLowerCase()) {
      case 'completed':   return (Icons.check_circle_rounded,  _C.green);
      case 'accepted':    return (Icons.handshake_rounded,     _C.purple);
      case 'in_progress': return (Icons.play_circle_rounded,   AppColors.onlineGreen);
      case 'pending':     return (Icons.pending_rounded,       _C.amber);
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
          .limit(6).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : _C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark ? AppColors.borderDark : _C.border)),
            child: Center(child: Text('No activity yet',
                style: TextStyle(
                    color: isDark ? AppColors.textMidDark : _C.t2,
                    fontSize: 13))),
          );
        }
        return Container(
          decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : _C.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : _C.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.10 : 0.03),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(children: snap.data!.docs.asMap().entries.map((e) {
            final doc    = e.value;
            final d      = doc.data() as Map<String, dynamic>;
            final status = d['status'] as String? ?? 'pending';
            final svc    = d['serviceName'] as String? ?? 'Service';
            final amt    = ((d['amount'] ?? 0) as num).toDouble();
            final ts     = (d['createdAt'] as Timestamp?)?.toDate();
            final isLast = e.key == snap.data!.docs.length - 1;
            final (icon, color) = _meta(status);
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(children: [
                  Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(icon, color: color, size: 16)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(svc, style: TextStyle(
                        color: isDark ? Colors.white : _C.t1,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(status.toUpperCase(), style: TextStyle(
                        color: isDark ? AppColors.textMidDark : _C.t3,
                        fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(status == 'completed'
                        ? '+₹${amt.toStringAsFixed(0)}'
                        : '₹${amt.toStringAsFixed(0)}',
                        style: TextStyle(
                            color: status == 'completed' ? _C.green
                                : (isDark ? AppColors.textMidDark : _C.t2),
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    if (ts != null) Text(_ago(ts), style: TextStyle(
                        color: isDark ? AppColors.textSoftDark : _C.t3,
                        fontSize: 10)),
                  ]),
                ]),
              ),
              if (!isLast) Divider(height: 1,
                  color: isDark ? AppColors.borderDark : _C.divider,
                  indent: 14, endIndent: 14),
            ]);
          }).toList()),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EARN TAB — Day / Week / Month toggle + simple bar chart + transactions
// ═══════════════════════════════════════════════════════════════════════════
class _EarnTab extends StatefulWidget {
  const _EarnTab();
  @override
  State<_EarnTab> createState() => _EarnTabState();
}

class _EarnTabState extends State<_EarnTab> {
  int _period = 0; // 0 = Day, 1 = Week, 2 = Month

  DateTime get _start {
    final n = DateTime.now();
    if (_period == 0) return DateTime(n.year, n.month, n.day);
    if (_period == 1) return n.subtract(Duration(days: n.weekday - 1));
    return DateTime(n.year, n.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final helper  = context.watch<AuthProvider>().helper;
    final uid     = helper?.uid ?? '';
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final isHindi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : _C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _EarnHeader(isDark: isDark, isHindi: isHindi)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Period toggle
            _PeriodToggle(selected: _period,
                onSelect: (i) => setState(() => _period = i),
                isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 16),
            // Summary + chart
            _EarnSummary(uid: uid, start: _start,
                period: _period, isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 16),
            // Withdraw button
            _WithdrawBtn(isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 22),
            // Transactions
            _SecHead(title: isHindi ? 'लेनदेन' : 'Transactions', isDark: isDark),
            const SizedBox(height: 12),
            _TransactionList(uid: uid, start: _start, isDark: isDark),
          ])),
        ),
      ]),
    );
  }
}

class _EarnHeader extends StatelessWidget {
  final bool isDark, isHindi;
  const _EarnHeader({required this.isDark, required this.isHindi});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      bottom: 18, left: 16, right: 16,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_C.indigo, _C.violet, _C.purple],
      ),
    ),
    child: Row(children: [
      Container(width: 38, height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.wallet_rounded, color: Colors.white, size: 20)),
      const SizedBox(width: 12),
      Text(isHindi ? 'मेरी कमाई' : 'My Earnings', style: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const Spacer(),
      const NotificationBell(isDark: false),
    ]),
  );
}

class _PeriodToggle extends StatelessWidget {
  final int selected;
  final void Function(int) onSelect;
  final bool isDark, isHindi;
  const _PeriodToggle({
    required this.selected, required this.onSelect,
    required this.isDark, required this.isHindi,
  });

  @override
  Widget build(BuildContext context) {
    final labels = isHindi
        ? ['आज', 'इस हफ्ते', 'इस महीने']
        : ['Today', 'This Week', 'This Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.borderDark : _C.border)),
      child: Row(children: labels.asMap().entries.map((e) {
        final sel = selected == e.key;
        return Expanded(child: GestureDetector(
          onTap: () => onSelect(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
                color: sel ? _C.purple : Colors.transparent,
                borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(e.value, style: TextStyle(
                color: sel ? Colors.white
                    : (isDark ? AppColors.textMidDark : _C.t2),
                fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500))),
          ),
        ));
      }).toList()),
    );
  }
}

class _EarnSummary extends StatelessWidget {
  final String uid;
  final DateTime start;
  final int period;
  final bool isDark, isHindi;
  const _EarnSummary({
    required this.uid, required this.start, required this.period,
    required this.isDark, required this.isHindi,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .snapshots(),
      builder: (ctx, snap) {
        double total = 0; int jobs = 0;
        final Map<int, double> byDay = {}; // day index → amount

        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m   = d.data() as Map<String, dynamic>;
            final amt = ((m['amount'] ?? 0) as num).toDouble();
            final ts  = (m['createdAt'] as Timestamp?)?.toDate();
            total += amt; jobs++;
            if (ts != null) {
              final key = period == 2
                  ? ts.day
                  : (period == 1 ? ts.weekday : ts.hour);
              byDay[key] = (byDay[key] ?? 0) + amt;
            }
          }
        }
        final maxBar = byDay.isEmpty ? 1.0 : byDay.values.reduce(math.max);

        return Container(
          decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : _C.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : _C.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.10 : 0.04),
                  blurRadius: 12, offset: const Offset(0, 3))]),
          child: Column(children: [
            // total
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isHindi ? 'कुल कमाई' : 'Total Earned', style: TextStyle(
                      color: isDark ? AppColors.textMidDark : _C.t2,
                      fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('₹ ${total.toStringAsFixed(2)}', style: TextStyle(
                      color: isDark ? Colors.white : _C.t1,
                      fontSize: 30, fontWeight: FontWeight.w800)),
                ]),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _Chip(label: '$jobs jobs', bg: _C.green.withOpacity(0.10),
                      fg: _C.green),
                ]),
              ]),
            ),
            // mini bar chart
            if (byDay.isNotEmpty) Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: _MiniBarChart(
                  data: byDay, maxVal: maxBar, isDark: isDark, period: period),
            ),
          ]),
        );
      },
    );
  }
}

// ── mini bar chart (pure Flutter, no library needed) ─────────────
class _MiniBarChart extends StatelessWidget {
  final Map<int, double> data;
  final double maxVal;
  final bool isDark;
  final int period;
  const _MiniBarChart({
    required this.data, required this.maxVal,
    required this.isDark, required this.period,
  });

  @override
  Widget build(BuildContext context) {
    // Build 7 buckets for week, 12h for day, 30 for month
    final int buckets = period == 0 ? 12 : (period == 1 ? 7 : 30);
    final labels = period == 1
        ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : null;

    return SizedBox(height: 90, child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(buckets, (i) {
        final key = period == 0 ? (i * 2) : (i + 1);
        final val = data[key] ?? 0;
        final pct = maxVal > 0 ? (val / maxVal).clamp(0.0, 1.0) : 0.0;
        final isToday = (period == 1
            ? (key == DateTime.now().weekday)
            : (period == 2
            ? (key == DateTime.now().day)
            : false));

        return Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.end, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              height: 60 * pct + (val > 0 ? 4 : 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: pct > 0
                    ? (isToday ? _C.purple : _C.purple.withOpacity(0.4))
                    : (isDark ? AppColors.borderDark : _C.border),
              ),
            ),
            if (labels != null && i < labels.length) ...[
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(
                  color: isDark ? AppColors.textSoftDark : _C.t3,
                  fontSize: 9)),
            ],
          ]),
        ));
      }),
    ));
  }
}

class _WithdrawBtn extends StatelessWidget {
  final bool isDark, isHindi;
  const _WithdrawBtn({required this.isDark, required this.isHindi});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.purple.withOpacity(0.3))),
    child: ElevatedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Withdrawal coming soon!'),
          behavior: SnackBarBehavior.floating,
        ));
      },
      icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
      label: Text(isHindi ? 'निकासी करें' : 'Withdraw Earnings',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: isDark ? AppColors.cardDark : _C.white,
        foregroundColor: _C.purple,
        elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class _TransactionList extends StatelessWidget {
  final String uid;
  final DateTime start;
  final bool isDark;
  const _TransactionList(
      {required this.uid, required this.start, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .where('createdAt', isGreaterThanOrEqualTo: start)
          .orderBy('createdAt', descending: true)
          .limit(20).snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : _C.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark ? AppColors.borderDark : _C.border)),
            child: Center(child: Text('No transactions found',
                style: TextStyle(
                    color: isDark ? AppColors.textMidDark : _C.t2,
                    fontSize: 13))),
          );
        }
        return Container(
          decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : _C.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : _C.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.10 : 0.03),
                  blurRadius: 8, offset: const Offset(0, 2))]),
          child: Column(children: snap.data!.docs.asMap().entries.map((e) {
            final d   = e.value.data() as Map<String, dynamic>;
            final svc = d['serviceName'] as String? ?? 'Service';
            final amt = ((d['amount'] ?? 0) as num).toDouble();
            final ts  = (d['createdAt'] as Timestamp?)?.toDate();
            final last = e.key == snap.data!.docs.length - 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: _C.green.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.check_circle_rounded,
                          color: _C.green, size: 17)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(svc, style: TextStyle(
                        color: isDark ? Colors.white : _C.t1,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                    if (ts != null) Text(
                        '${ts.day}/${ts.month}/${ts.year}  ${ts.hour}:${ts.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                            color: isDark ? AppColors.textSoftDark : _C.t3,
                            fontSize: 10)),
                  ])),
                  Text('+₹${amt.toStringAsFixed(0)}', style: const TextStyle(
                      color: _C.green, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
              ),
              if (!last) Divider(height: 1,
                  color: isDark ? AppColors.borderDark : _C.divider,
                  indent: 14, endIndent: 14),
            ]);
          }).toList()),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ME TAB — profile, UPI, language, support, logout
// ═══════════════════════════════════════════════════════════════════════════
class _MeTab extends StatelessWidget {
  const _MeTab();
  @override
  Widget build(BuildContext context) {
    final helper  = context.watch<AuthProvider>().helper;
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final lang    = context.watch<LanguageProvider>();
    final isHindi = lang.isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : _C.bg,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _MeHeader(helper: helper, isDark: isDark)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          sliver: SliverList(delegate: SliverChildListDelegate([
            // Profile card
            _MeProfileCard(helper: helper, isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 16),
            // UPI
            _MeUpiCard(helper: helper, isDark: isDark, isHindi: isHindi),
            const SizedBox(height: 16),
            // Settings
            _MeSection(isDark: isDark, title: isHindi ? 'सेटिंग' : 'Settings',
              items: [
                _MeItem(icon: Icons.language_rounded,
                    label: isHindi ? 'भाषा: हिंदी' : 'Language: English',
                    isDark: isDark,
                    onTap: () => lang.setLanguage(lang.isHindi ? 'en' : 'hi')),
                _MeItem(icon: Icons.dark_mode_rounded,
                    label: isDark
                        ? (isHindi ? 'लाइट मोड' : 'Switch to Light Mode')
                        : (isHindi ? 'डार्क मोड' : 'Switch to Dark Mode'),
                    isDark: isDark,
                    onTap: () {
                      // Toggle via ThemeNotifier if wired
                    }),
              ],
            ),
            const SizedBox(height: 14),
            _MeSection(isDark: isDark, title: isHindi ? 'सहायता' : 'Help',
              items: [
                _MeItem(icon: Icons.headset_mic_rounded,
                    label: isHindi ? 'सपोर्ट से बात करें' : 'Contact Support',
                    isDark: isDark,
                    onTap: () => Navigator.push(context,
                        SmoothRoute(page: const SupportScreen()))),
                _MeItem(icon: Icons.history_rounded,
                    label: isHindi ? 'जॉब इतिहास' : 'Job History',
                    isDark: isDark,
                    onTap: () => Navigator.push(context,
                        SmoothRoute(page: const JobHistoryScreen()))),
              ],
            ),
            const SizedBox(height: 22),
            // Logout
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout_rounded, color: _C.red),
              label: Text(isHindi ? 'लॉगआउट' : 'Logout',
                  style: const TextStyle(
                      color: _C.red, fontSize: 14, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: _C.red.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            )),
          ])),
        ),
      ]),
    );
  }
}

class _MeHeader extends StatelessWidget {
  final HelperModel? helper; final bool isDark;
  const _MeHeader({required this.helper, required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      bottom: 18, left: 16, right: 16,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_C.indigo, _C.violet, _C.purple],
      ),
    ),
    child: Row(children: [
      Container(width: 38, height: 38,
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.person_rounded, color: Colors.white, size: 20)),
      const SizedBox(width: 12),
      Text('My Profile', style: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
      const Spacer(),
      const NotificationBell(isDark: false),
    ]),
  );
}

class _MeProfileCard extends StatelessWidget {
  final HelperModel? helper; final bool isDark, isHindi;
  const _MeProfileCard(
      {required this.helper, required this.isDark, required this.isHindi});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.borderDark : _C.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.10 : 0.04),
            blurRadius: 10, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_C.indigo, _C.purple]),
            shape: BoxShape.circle),
        child: Center(child: Text(helper?.initials ?? 'SK',
            style: const TextStyle(color: Colors.white,
                fontSize: 20, fontWeight: FontWeight.w800))),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(helper?.name ?? 'Helper', style: TextStyle(
            color: isDark ? Colors.white : _C.t1,
            fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(helper?.phone ?? '', style: TextStyle(
            color: isDark ? AppColors.textMidDark : _C.t2, fontSize: 13)),
        const SizedBox(height: 6),
        _Chip(label: helper?.displayId ?? 'SK-0000',
            bg: _C.purple.withOpacity(0.08), fg: _C.purple),
      ])),
    ]),
  );
}

class _MeUpiCard extends StatelessWidget {
  final HelperModel? helper; final bool isDark, isHindi;
  const _MeUpiCard(
      {required this.helper, required this.isDark, required this.isHindi});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : _C.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_balance_wallet_rounded,
            color: _C.purple, size: 18),
        const SizedBox(width: 8),
        Text(isHindi ? 'UPI / बैंक विवरण' : 'UPI / Bank Details',
            style: TextStyle(
                color: isDark ? Colors.white : _C.t1,
                fontSize: 14, fontWeight: FontWeight.w700)),
        const Spacer(),
        GestureDetector(
          onTap: () {},
          child: Text(isHindi ? 'बदलें' : 'Edit', style: const TextStyle(
              color: _C.purple, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: _C.purple.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _C.purple.withOpacity(0.15))),
        child: Row(children: [
          const Icon(Icons.smartphone_rounded, color: _C.purple, size: 14),
          const SizedBox(width: 8),
          Text(
            (helper?.toMap()['upiId'] as String?) ?? 'Not set',
            style: TextStyle(
                color: isDark ? AppColors.textMidDark : _C.t2,
                fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    ]),
  );
}

class _MeSection extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<_MeItem> items;
  const _MeSection(
      {required this.isDark, required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title.toUpperCase(), style: TextStyle(
        color: isDark ? AppColors.textSoftDark : _C.t3,
        fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
    const SizedBox(height: 8),
    Container(
      decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : _C.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.borderDark : _C.border)),
      child: Column(children: items.asMap().entries.map((e) {
        final item = e.value;
        final last = e.key == items.length - 1;
        return Column(children: [
          GestureDetector(
            onTap: item.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(children: [
                Icon(item.icon, color: _C.purple, size: 20),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label, style: TextStyle(
                    color: isDark ? Colors.white : _C.t1,
                    fontSize: 13, fontWeight: FontWeight.w500))),
                Icon(Icons.arrow_forward_ios_rounded, size: 11,
                    color: isDark ? AppColors.textSoftDark : _C.t3),
              ]),
            ),
          ),
          if (!last) Divider(height: 1,
              color: isDark ? AppColors.borderDark : _C.divider,
              indent: 14, endIndent: 14),
        ]);
      }).toList()),
    ),
  ]);
}

class _MeItem {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback? onTap;
  const _MeItem({
    required this.icon, required this.label,
    required this.isDark, this.onTap,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════
class _SecHead extends StatelessWidget {
  final String title;
  final String? badge;
  final bool isDark;
  const _SecHead({required this.title, required this.isDark, this.badge});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 18,
        decoration: BoxDecoration(
            color: _C.purple, borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 10),
    Text(title, style: TextStyle(
        color: isDark ? Colors.white : _C.t1,
        fontSize: 17, fontWeight: FontWeight.w800)),
    if (badge != null) ...[
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: _C.purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.purple.withOpacity(0.18))),
        child: Text(badge!, style: const TextStyle(
            color: _C.purple, fontSize: 11, fontWeight: FontWeight.w700)),
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
    child: Text(label, style: TextStyle(
        color: fg, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// KYC STATUS SCREENS
// ═══════════════════════════════════════════════════════════════════════════
class _KycPending extends StatelessWidget {
  final HelperModel helper;
  const _KycPending({required this.helper});
  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return _KycShell(helper: helper, isDark: dk,
        color: AppColors.warning, label: 'Action Required',
        icon: Icons.upload_file_rounded,
        title: 'Complete Your KYC',
        body: 'Upload your Aadhaar & PAN to get verified.',
        steps: const [
          ('Registration Complete', true), ('Upload Aadhaar & PAN', false),
          ('Admin Approval', false), ('Go Live & Earn', false),
        ],
        action: _KycActionBtn(label: 'Upload KYC Documents',
            icon: Icons.upload_rounded,
            onTap: () => Navigator.push(context,
                SmoothRoute(page: const KycScreen()))));
  }
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
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return _KycShell(helper: widget.helper, isDark: dk,
        color: _C.purple, label: 'Under Review',
        icon: Icons.manage_search_rounded,
        title: 'Documents Under Review',
        body: 'KYC submitted. Admin will review within 24 hours.',
        steps: const [
          ('Registration Complete', true), ('KYC Documents Uploaded', true),
          ('Admin Approval', false), ('Go Live & Earn', false),
        ],
        action: _KycActionBtn(label: 'Check Status',
            icon: Icons.refresh_rounded, outline: true,
            onTap: () => context.read<AuthProvider>().refreshProfile()));
  }
}

class _KycRejected extends StatelessWidget {
  final HelperModel helper;
  const _KycRejected({required this.helper});
  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return _KycShell(helper: helper, isDark: dk,
        color: AppColors.danger, label: 'KYC Rejected',
        icon: Icons.cancel_rounded,
        title: 'KYC Rejected',
        body: helper.kycRejectedReason ?? 'Please re-upload clear, valid documents.',
        steps: const [],
        action: _KycActionBtn(label: 'Re-upload Documents',
            icon: Icons.upload_rounded, color: AppColors.danger,
            onTap: () => Navigator.push(context,
                SmoothRoute(page: const KycScreen()))));
  }
}

class _KycInactive extends StatelessWidget {
  final HelperModel helper;
  const _KycInactive({required this.helper});
  @override
  Widget build(BuildContext context) {
    final dk = Theme.of(context).brightness == Brightness.dark;
    return _KycShell(helper: helper, isDark: dk,
        color: _C.t2, label: 'Deactivated',
        icon: Icons.block_rounded,
        title: 'Account Deactivated',
        body: 'Contact support to reactivate your account.',
        steps: const [], action: null);
  }
}

class _KycShell extends StatelessWidget {
  final HelperModel helper;
  final bool isDark;
  final Color color;
  final String label, title, body;
  final IconData icon;
  final List<(String, bool)> steps;
  final Widget? action;
  const _KycShell({
    required this.helper, required this.isDark, required this.color,
    required this.label, required this.title, required this.body,
    required this.icon, required this.steps, required this.action,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: isDark ? AppColors.bgDark : _C.bg,
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(24),
      child: Column(children: [
        // top bar
        Row(children: [
          Container(width: 44, height: 44,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Center(child: Text(helper.initials, style: TextStyle(
                  color: color, fontSize: 15, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(helper.name, style: TextStyle(
                    color: isDark ? Colors.white : _C.t1,
                    fontSize: 15, fontWeight: FontWeight.w700)),
                Container(margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withOpacity(0.3))),
                    child: Text(label, style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w700))),
              ])),
        ]),
        const Spacer(),
        Container(width: 100, height: 100,
            decoration: BoxDecoration(
                color: color.withOpacity(0.08), shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3), width: 2)),
            child: Icon(icon, size: 48, color: color)),
        const SizedBox(height: 24),
        Text(title, style: TextStyle(
            color: isDark ? Colors.white : _C.t1,
            fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(body, textAlign: TextAlign.center,
            style: TextStyle(
                color: isDark ? AppColors.textMidDark : _C.t2,
                fontSize: 14, height: 1.6)),
        if (steps.isNotEmpty) ...[
          const SizedBox(height: 28),
          _KycSteps(isDark: isDark, steps: steps),
        ],
        const Spacer(),
        if (action != null) action!,
        const SizedBox(height: 12),
        // logout
        TextButton.icon(
          onPressed: () => context.read<AuthProvider>().logout(),
          icon: const Icon(Icons.logout_rounded, size: 16, color: _C.red),
          label: const Text('Logout',
              style: TextStyle(color: _C.red, fontSize: 13)),
        ),
      ]),
    )),
  );
}

class _KycActionBtn extends StatelessWidget {
  final String label; final IconData icon;
  final VoidCallback onTap;
  final Color? color; final bool outline;
  const _KycActionBtn({
    required this.label, required this.icon, required this.onTap,
    this.color, this.outline = false,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: outline
        ? OutlinedButton.icon(
        onPressed: onTap, icon: Icon(icon), label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
          foregroundColor: _C.purple, side: const BorderSide(color: _C.purple),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ))
        : ElevatedButton.icon(
        onPressed: onTap, icon: Icon(icon),
        label: Text(label, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        )),
  );
}

class _KycSteps extends StatelessWidget {
  final bool isDark;
  final List<(String, bool)> steps;
  const _KycSteps({required this.isDark, required this.steps});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : _C.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : _C.border)),
    child: Column(children: steps.asMap().entries.map((e) {
      final (lbl, done) = e.value;
      final last = e.key == steps.length - 1;
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              width: 22, height: 22,
              decoration: BoxDecoration(
                  color: done ? _C.green : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: done ? _C.green
                          : (isDark ? AppColors.borderDark : _C.border),
                      width: 2)),
              child: Center(child: done
                  ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
                  : Container(width: 6, height: 6, decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : _C.border,
                  shape: BoxShape.circle)))),
          if (!last) Container(width: 2, height: 26,
              color: done ? _C.green.withOpacity(0.3)
                  : (isDark ? AppColors.borderDark : _C.border)),
        ]),
        const SizedBox(width: 12),
        Padding(padding: const EdgeInsets.only(top: 3),
            child: Text(lbl, style: TextStyle(
                color: done ? _C.green
                    : (isDark ? AppColors.textMidDark : _C.t2),
                fontSize: 13,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400))),
      ]);
    }).toList()),
  );
}