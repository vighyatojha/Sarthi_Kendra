// lib/screens/profile/helper_profile_screen.dart
//
// DROP-IN REPLACEMENT — embedded HelperProfileEditScreen removed.
// All edit buttons now navigate to EditProfileScreen from edit_profile_screen.dart.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../models/helper_model.dart';
import '../../utils/smooth_route.dart';
import '../auth/helper_login_screen.dart';
import '../kyc/kyc_screen.dart';
import '../support/support_screen.dart';
import '../trust/trust_safety_screen.dart';
import '../jobs/job_history_screen.dart';
import '../notifications/notifications_screen.dart';
import '../chat/helper_chat_screen.dart';
import 'edit_profile_screen.dart'; // ← your new edit screen

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  static const deepPurple  = Color(0xFF1A0848);
  static const midPurple   = Color(0xFF3B1882);
  static const cardPurple  = Color(0xFF2A1270);
  static const brightPurple= Color(0xFF5028D0);
  static const violet      = Color(0xFF7C3AED);
  static const lavender    = Color(0xFFEDE8FF);
  static const avatarText  = Color(0xFF5B21B6);
  static const editGradA   = Color(0xFF9333EA);
  static const editGradB   = Color(0xFFBE29EC);
  static const bodyBg      = Color(0xFFEEEDF5);
  static const teal        = Color(0xFF00D4AA);
  static const amber       = Color(0xFFFFA940);
  static const rose        = Color(0xFFFF5C7A);
  static const blue        = Color(0xFF4A90FF);
  static const t1          = Color(0xFFF1F5F9);
  static const t3          = Color(0xFF94A3B8);
  static const drawerBg    = Color(0xFF1A0848);
}

double _safeDouble(dynamic v) =>
    v == null ? 0.0 : v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

int _safeInt(dynamic v) =>
    v == null ? 0 : v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;

extension _Alpha on Color {
  Color op(double opacity) => withValues(alpha: opacity);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ROOT
// ═══════════════════════════════════════════════════════════════════════════════
class HelperProfileScreen extends StatefulWidget {
  const HelperProfileScreen({super.key});
  @override
  State<HelperProfileScreen> createState() => _HelperProfileScreenState();
}

class _HelperProfileScreenState extends State<HelperProfileScreen>
    with SingleTickerProviderStateMixin {

  late final AnimationController _ctrl;
  late final Animation<double>   _progress;

  static const double _slidePercent = 0.62;
  static const double _scaleTarget  = 0.88;

  bool get _isOpen => _ctrl.value > 0.5;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _progress = CurvedAnimation(
        parent: _ctrl, curve: Curves.easeInOutCubic);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _open()  { HapticFeedback.lightImpact(); _ctrl.forward(); }
  void _close() { _ctrl.reverse(); }

  void _navTo(Widget page) {
    _close();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (mounted) Navigator.push(context, _UpSlide(page: page));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        final p         = _progress.value;
        final cardScale = 1.0 - (1.0 - _scaleTarget) * p;
        final cardTx    = -(sw * _slidePercent) * p;

        return Scaffold(
          backgroundColor: _P.drawerBg,
          body: Stack(children: [
            Positioned.fill(
              child: _DrawerContent(
                progress: p,
                onClose: _close,
                onNavTo: _navTo,
              ),
            ),
            Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..translateByDouble(cardTx, 0.0, 0.0, 1.0)
                ..scaleByDouble(cardScale, cardScale, 1.0, 1.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(p * 28),
                child: GestureDetector(
                  onHorizontalDragEnd: (d) {
                    if ((d.primaryVelocity ?? 0) < -400 && !_isOpen) _open();
                    if ((d.primaryVelocity ?? 0) >  400 && _isOpen)  _close();
                  },
                  onTap: _isOpen ? _close : null,
                  child: AbsorbPointer(
                    absorbing: _isOpen,
                    child: _ProfileBody(onOpenDrawer: _open),
                  ),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Slide-up route ─────────────────────────────────────────────────────────────
class _UpSlide extends PageRouteBuilder {
  _UpSlide({required Widget page}) : super(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// DRAWER
// ═══════════════════════════════════════════════════════════════════════════════
class _DrawerContent extends StatelessWidget {
  final double progress;
  final VoidCallback onClose;
  final void Function(Widget) onNavTo;

  const _DrawerContent({
    required this.progress,
    required this.onClose,
    required this.onNavTo,
  });

  @override
  Widget build(BuildContext context) {
    final langProv = context.watch<LanguageProvider>();
    final hi       = langProv.isHindi;
    final helper   = context.watch<AuthProvider>().helper;
    final sw       = MediaQuery.of(context).size.width;
    final leftPad  = sw * 0.30;

    final kycApproved = helper?.isApproved ?? false;

    final drawerItems = <(IconData, String, Color, Widget)>[
      if (!kycApproved)
        (Icons.verified_user_rounded, hi ? 'KYC स्थिति' : 'KYC Status', _P.violet, const KycScreen()),
      (Icons.account_balance_rounded, hi ? 'बैंक विवरण'         : 'Bank Details',   _P.blue,   const KycScreen()),
      (Icons.shield_rounded,          hi ? 'विश्वास और सुरक्षा' : 'Trust & Safety', _P.teal,   const TrustSafetyScreen()),
      (Icons.work_history_rounded,    hi ? 'जॉब इतिहास'         : 'Job History',    _P.amber,  const JobHistoryScreen()),
      (Icons.chat_bubble_rounded,     hi ? 'मेसेज'              : 'Messages',       _P.blue,   const HelperChatScreen()),
      (Icons.notifications_rounded,   hi ? 'नोटिफिकेशन'         : 'Notifications',  _P.amber,  const NotificationsScreen()),
      (Icons.headset_mic_rounded,     hi ? 'सहायता'             : 'Support',        _P.rose,   const SupportScreen()),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: leftPad, right: 20, top: 28, bottom: 24),
        child: Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mini avatar
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [_P.editGradA, _P.editGradB],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      helper?.initials ?? 'SK',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      helper?.name ?? 'Helper',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _P.t1, fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      helper?.displayId ?? '',
                      style: const TextStyle(color: _P.t3, fontSize: 10),
                    ),
                  ],
                )),
              ]),

              const SizedBox(height: 20),

              // Language toggle
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white.op(0.06),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white.op(0.10)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _LangChip(
                    label: 'EN',
                    active: !hi,
                    onTap: () { if (hi) langProv.setLanguage('en'); },
                  ),
                  const SizedBox(width: 2),
                  _LangChip(
                    label: 'हिं',
                    active: hi,
                    onTap: () { if (!hi) langProv.setLanguage('hi'); },
                  ),
                ]),
              ),

              const SizedBox(height: 22),
              Container(height: 1, color: Colors.white.op(0.07)),
              const SizedBox(height: 20),

              // Nav items
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // KYC Approved badge (shown when approved, non-tappable)
                      if (kycApproved)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Opacity(
                            opacity: 0.60,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: _P.teal.op(0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _P.teal.op(0.25)),
                              ),
                              child: Row(children: [
                                Stack(clipBehavior: Clip.none, children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: BoxDecoration(
                                      color: _P.teal.op(0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                        Icons.verified_user_rounded,
                                        color: _P.teal, size: 16),
                                  ),
                                  Positioned(
                                    top: -4, right: -4,
                                    child: Container(
                                      width: 14, height: 14,
                                      decoration: BoxDecoration(
                                        color: _P.teal,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _P.drawerBg, width: 1.5),
                                      ),
                                      child: const Icon(
                                          Icons.check_rounded,
                                          color: Colors.white, size: 9),
                                    ),
                                  ),
                                ]),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    hi ? 'KYC स्वीकृत ✓' : 'KYC Approved ✓',
                                    style: TextStyle(
                                      color: _P.teal.op(0.85),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Icon(Icons.lock_open_rounded,
                                    color: _P.teal.op(0.5), size: 14),
                              ]),
                            ),
                          ),
                        ),

                      // Regular drawer items
                      ...drawerItems.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: GestureDetector(
                            onTap: () => onNavTo(item.$4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.op(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.white.op(0.04)),
                              ),
                              child: Row(children: [
                                Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    color: item.$3.op(0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(item.$1,
                                      color: item.$3, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text(
                                    item.$2,
                                    style: const TextStyle(
                                      color: _P.t1, fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: _P.t3, size: 14),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              Container(height: 1, color: Colors.white.op(0.07)),
              const SizedBox(height: 16),

              // Logout
              GestureDetector(
                onTap: () async {
                  onClose();
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (!context.mounted) return;
                  final auth = context.read<AuthProvider>();
                  final uid  = auth.helper?.uid;
                  if (uid != null) {
                    try {
                      await FirebaseFirestore.instance
                          .collection('helpers')
                          .doc(uid)
                          .update({'isOnline': false});
                    } catch (_) {}
                  }
                  await auth.logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    SmoothRoute(page: const HelperLoginScreen()),
                        (_) => false,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _P.rose.op(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _P.rose.op(0.25)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _P.rose.op(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: _P.rose, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      hi ? 'लॉगआउट' : 'Logout',
                      style: const TextStyle(
                        color: _P.rose, fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        gradient: active
            ? const LinearGradient(colors: [_P.editGradA, _P.editGradB])
            : null,
        color: active ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : _P.t3,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// PROFILE BODY
// ═══════════════════════════════════════════════════════════════════════════════
class _ProfileBody extends StatelessWidget {
  final VoidCallback onOpenDrawer;
  const _ProfileBody({required this.onOpenDrawer});

  @override
  Widget build(BuildContext context) {
    final helper = context.watch<AuthProvider>().helper;
    final hi     = context.watch<LanguageProvider>().isHindi;
    final uid    = helper?.uid ?? '';

    return Scaffold(
      backgroundColor: _P.bodyBg,
      body: RefreshIndicator(
        color: _P.violet,
        onRefresh: () => context.read<AuthProvider>().refreshProfile(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                helper: helper, hi: hi, onMenu: onOpenDrawer,
                onEdit: () => Navigator.push(
                  context,
                  _UpSlide(page: const EditProfileScreen()), // ← new screen
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 14),
                  _PreviewCard(helper: helper, uid: uid, hi: hi),
                  const SizedBox(height: 12),
                  _CompletionCard(helper: helper, hi: hi, uid: uid),
                  const SizedBox(height: 12),
                  _AchievementsSection(uid: uid, hi: hi),
                  const SizedBox(height: 12),
                  _ServicesSection(helper: helper, uid: uid, hi: hi),
                  const SizedBox(height: 12),
                  _AboutSection(uid: uid, hi: hi),
                  const SizedBox(height: 20),
                  const Center(
                    child: Text('Sarthi Kendra v1.0.0',
                        style: TextStyle(
                            color: Color(0xFF94A3B8), fontSize: 10)),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text('© 2024 Trouble Sarthi Platform',
                        style: TextStyle(
                            color: Color(0xFFCBD5E1), fontSize: 10)),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final HelperModel? helper;
  final bool hi;
  final VoidCallback onMenu, onEdit;
  const _Header({
    required this.helper, required this.hi,
    required this.onMenu, required this.onEdit,
  });

  Color _sc(HelperModel? h) {
    if (h?.isApproved ?? false)  return _P.teal;
    if (h?.isRejected ?? false)  return _P.rose;
    if (h?.isSubmitted ?? false) return _P.blue;
    return _P.amber;
  }

  String _sl(HelperModel? h) {
    if (h?.isApproved ?? false)  return hi ? 'स्वीकृत'    : 'APPROVED';
    if (h?.isRejected ?? false)  return hi ? 'अस्वीकृत'   : 'REJECTED';
    if (h?.isSubmitted ?? false) return hi ? 'समीक्षाधीन' : 'IN REVIEW';
    return hi ? 'KYC बाकी' : 'PENDING KYC';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_P.deepPurple, _P.midPurple, Color(0xFF4A22A0)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Text(
                hi ? 'मेरी प्रोफ़ाइल' : 'Profile',
                style: const TextStyle(
                  color: _P.t1, fontSize: 20,
                  fontWeight: FontWeight.w800, letterSpacing: -0.4,
                ),
              ),
              const Spacer(),
              // Edit button → EditProfileScreen
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_P.editGradA, _P.editGradB],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _P.editGradA.op(0.45),
                        blurRadius: 10, offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      hi ? 'संपादित' : 'Edit',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              // Settings / Menu
              GestureDetector(
                onTap: onMenu,
                child: Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.op(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.op(0.20)),
                  ),
                  child: const Icon(Icons.settings_rounded,
                      color: _P.t1, size: 18),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 26),

          // Avatar
          Stack(alignment: Alignment.bottomRight, children: [
            Container(
              width: 86, height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _P.lavender,
                boxShadow: [
                  BoxShadow(
                    color: _P.editGradA.op(0.35),
                    blurRadius: 24, spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  helper?.initials ?? 'SK',
                  style: const TextStyle(
                    color: _P.avatarText, fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: onEdit,
              child: Container(
                width: 26, height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [_P.editGradA, _P.editGradB],
                  ),
                  border: Border.all(
                      color: const Color(0xFF3B1882), width: 2),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 12),
              ),
            ),
          ]),

          const SizedBox(height: 14),

          Text(
            helper?.name ?? 'Sarthi Helper',
            style: const TextStyle(
              color: _P.t1, fontSize: 22,
              fontWeight: FontWeight.w800, letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),

          if ((helper?.email ?? '').isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.email_outlined, color: _P.t3, size: 12),
              const SizedBox(width: 4),
              Text(helper!.email,
                  style: const TextStyle(color: _P.t3, fontSize: 12)),
            ]),

          const SizedBox(height: 10),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _HeaderChip(
                label: helper?.displayId ?? 'SK-0000',
                color: _P.violet),
            const SizedBox(width: 6),
            _HeaderChip(
                label: _sl(helper),
                color: _sc(helper),
                dot: true),
          ]),

          if (helper?.area.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_rounded,
                  color: _P.t3, size: 12),
              const SizedBox(width: 3),
              Text(helper!.area,
                  style: const TextStyle(color: _P.t3, fontSize: 11)),
            ]),
          ],

          const SizedBox(height: 22),
        ]),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool dot;
  const _HeaderChip(
      {required this.label, required this.color, this.dot = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.op(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.op(0.35)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (dot) ...[
        Container(
          width: 5, height: 5,
          decoration: BoxDecoration(
              color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
      ],
      Text(
        label,
        style: TextStyle(
          color: color, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 0.5,
        ),
      ),
    ]),
  );
}

// ─── Customer Preview Card ─────────────────────────────────────────────────────
class _PreviewCard extends StatelessWidget {
  final HelperModel? helper;
  final String uid;
  final bool hi;
  const _PreviewCard(
      {required this.helper, required this.uid, required this.hi});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final d       = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rating  = _safeDouble(d['rating']);
        final reviews = _safeInt(d['totalReviews']);
        final price   = _safeInt(d['pricePerVisit']);
        final sType   = d['serviceType'] as String? ?? '';
        final services =
        List<String>.from(d['services'] ?? helper?.services ?? []);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE4DCFF)),
            boxShadow: [
              BoxShadow(
                color: _P.violet.op(0.08),
                blurRadius: 14, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_P.cardPurple, _P.brightPurple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft:  Radius.circular(17),
                    topRight: Radius.circular(17),
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.visibility_rounded,
                      color: _P.lavender, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    hi ? 'ग्राहक दृश्य — आपका प्रोफ़ाइल'
                        : 'Customer View — Your Profile',
                    style: const TextStyle(
                      color: _P.t1, fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _P.lavender.op(0.20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('PREVIEW',
                        style: TextStyle(
                          color: _P.lavender, fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        )),
                  ),
                ]),
              ),

              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 54, height: 54,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _P.lavender,
                    ),
                    child: Center(
                      child: Text(
                        helper?.initials ?? 'SK',
                        style: const TextStyle(
                          color: _P.avatarText, fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helper?.name ?? 'Sarthi Helper',
                        style: const TextStyle(
                          color: Color(0xFF1E1348), fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (sType.isNotEmpty)
                        Text(sType,
                            style: const TextStyle(
                              color: Color(0xFF64748B), fontSize: 11,
                            )),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.star_rounded,
                            color: Color(0xFFFFA940), size: 12),
                        const SizedBox(width: 3),
                        Text(
                          rating == 0
                              ? (hi ? 'अभी तक कोई रेटिंग नहीं'
                              : 'No rating yet')
                              : '${rating.toStringAsFixed(1)} ($reviews)',
                          style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11,
                          ),
                        ),
                        if (price > 0) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 4, height: 4,
                            decoration: const BoxDecoration(
                              color: Color(0xFFCBD5E1),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '₹$price${hi ? '/विज़िट' : '/visit'}',
                            style: const TextStyle(
                              color: _P.violet, fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ]),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: helper?.isOnline == true
                          ? _P.teal.op(0.12)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      helper?.isOnline == true
                          ? (hi ? 'ऑनलाइन' : 'Online')
                          : (hi ? 'ऑफलाइन' : 'Offline'),
                      style: TextStyle(
                        color: helper?.isOnline == true
                            ? _P.teal
                            : const Color(0xFF94A3B8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
              ),

              if (services.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Wrap(
                    spacing: 5, runSpacing: 5,
                    children: services.take(4).map((s) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _P.violet.op(0.07),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _P.violet.op(0.20)),
                        ),
                        child: Text(s,
                            style: const TextStyle(
                              color: _P.avatarText, fontSize: 10,
                              fontWeight: FontWeight.w500,
                            )),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Profile Completion Card ───────────────────────────────────────────────────
class _CompletionCard extends StatelessWidget {
  final HelperModel? helper;
  final bool hi;
  final String uid;
  const _CompletionCard(
      {required this.helper, required this.hi, required this.uid});

  static double _pct(Map<String, dynamic> d, HelperModel? h) {
    final checks = <bool>[
      (d['photoUrl'] as String? ?? '').isNotEmpty,
      (h?.name ?? '').isNotEmpty,
      (h?.phone ?? '').length == 10,
      (h?.area ?? '').isNotEmpty,
      ((d['bio'] ?? d['description'] ?? '') as String).isNotEmpty,
      _safeDouble(d['experience']) > 0,
      _safeDouble(d['pricePerVisit']) > 0,
      ((d['services'] as List?)?.isNotEmpty ?? (h?.services ?? []).isNotEmpty),
      (d['availDays'] as List? ?? []).isNotEmpty,
      (d['availSlots'] as List? ?? []).isNotEmpty,
    ];
    return checks.where((b) => b).length / checks.length;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final d      = snap.data?.data() as Map<String, dynamic>? ?? {};
        final p      = _pct(d, helper);
        final done   = p >= 1.0;
        final pctInt = (p * 100).round();

        if (done) return const SizedBox.shrink();

        final missing = <String>[];
        if ((d['photoUrl'] as String? ?? '').isEmpty)                       missing.add('Photo');
        if (!(helper?.name.isNotEmpty ?? false))                            missing.add('Name');
        if ((helper?.phone ?? '').length != 10)                             missing.add('Phone');
        if (!(helper?.area.isNotEmpty ?? false))                            missing.add('Area');
        if (((d['bio'] ?? d['description'] ?? '') as String).isEmpty)       missing.add('About You');
        if (_safeDouble(d['experience']) <= 0)                              missing.add('Experience');
        if (_safeDouble(d['pricePerVisit']) <= 0)                           missing.add('Price');
        if ((d['services'] as List? ?? (helper?.services ?? [])).isEmpty)   missing.add('Services');
        if ((d['availDays'] as List? ?? []).isEmpty)                        missing.add('Work Days');
        if ((d['availSlots'] as List? ?? []).isEmpty)                       missing.add('Work Hours');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, _P.violet.op(0.04)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _P.violet.op(0.25)),
            boxShadow: [
              BoxShadow(
                color: _P.violet.op(0.08),
                blurRadius: 14, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _P.violet.op(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined,
                      color: _P.violet, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hi ? 'प्रोफ़ाइल पूर्णता' : 'Profile Completion',
                      style: const TextStyle(
                        color: Color(0xFF1E1348), fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hi ? '100% पूरा करें → ऑनलाइन जाएं'
                          : "Some fields pending — tap to complete",
                      style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10,
                      ),
                    ),
                  ],
                )),
                Text('$pctInt%',
                    style: const TextStyle(
                      color: _P.violet, fontSize: 18,
                      fontWeight: FontWeight.w900,
                    )),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: p, minHeight: 6,
                  backgroundColor: _P.violet.op(0.12),
                  valueColor:
                  const AlwaysStoppedAnimation<Color>(_P.violet),
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 5, runSpacing: 4,
                  children: missing.take(5).map((m) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _P.violet.op(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _P.violet.op(0.20)),
                      ),
                      child: Text(m,
                          style: const TextStyle(
                            color: _P.violet, fontSize: 9,
                            fontWeight: FontWeight.w600,
                          )),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => Navigator.push(ctx,
                      _UpSlide(page: const EditProfileScreen())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_P.editGradA, _P.brightPurple],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _P.editGradA.op(0.30),
                          blurRadius: 10, offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        hi ? 'अभी पूरा करें' : "Complete Profile",
                        style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ─── Achievements ──────────────────────────────────────────────────────────────
class _AchievementsSection extends StatelessWidget {
  final String uid;
  final bool hi;
  const _AchievementsSection({required this.uid, required this.hi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final d       = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rating  = _safeDouble(d['rating']);
        final done    = _safeInt(d['completedJobs']);
        final balance = _safeDouble(d['totalBalance']);
        final reviews = _safeInt(d['totalReviews']);
        final rank    = d['rank']   as String? ?? '';
        final streak  = _safeInt(d['streak']);

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionTitle(hi ? 'उपलब्धियां' : 'Achievements'),
          const SizedBox(height: 8),
          Row(children: [
            _StatCard(
              icon: Icons.star_rounded, iconColor: _P.amber,
              bgColor: const Color(0xFFFFFBEB),
              value: rating == 0 ? '—' : rating.toStringAsFixed(1),
              label: hi ? 'रेटिंग' : 'Rating',
              sub: reviews > 0
                  ? '$reviews ${hi ? 'समीक्षाएं' : 'reviews'}' : '',
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.check_circle_rounded, iconColor: _P.teal,
              bgColor: const Color(0xFFF0FDF4),
              value: '$done',
              label: hi ? 'जॉब्स' : 'Jobs Done',
              sub: done > 0
                  ? '${(done * 0.95).round()}% ${hi ? 'सफलता' : 'success'}'
                  : '',
            ),
            const SizedBox(width: 8),
            _StatCard(
              icon: Icons.account_balance_wallet_rounded,
              iconColor: _P.violet,
              bgColor: _P.lavender.op(0.5),
              value: '₹${balance.toStringAsFixed(0)}',
              label: hi ? 'कुल कमाई' : 'Earned',
              sub: '',
            ),
          ]),
          if (rank.isNotEmpty || streak > 0) ...[
            const SizedBox(height: 8),
            Row(children: [
              if (rank.isNotEmpty)
                Expanded(child: _BadgeCard(
                  icon: Icons.military_tech_rounded, color: _P.blue,
                  label: hi ? 'रैंक' : 'Rank', value: rank,
                )),
              if (rank.isNotEmpty && streak > 0) const SizedBox(width: 8),
              if (streak > 0)
                Expanded(child: _BadgeCard(
                  icon: Icons.local_fire_department_rounded, color: _P.rose,
                  label: hi ? 'स्ट्रीक' : 'Streak',
                  value: '$streak ${hi ? 'दिन' : 'days'}',
                )),
            ]),
          ],
        ]);
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String value, label, sub;
  const _StatCard({
    required this.icon, required this.iconColor,
    required this.bgColor, required this.value,
    required this.label, required this.sub,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DCFF)),
        boxShadow: [
          BoxShadow(
            color: _P.violet.op(0.06),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
              color: Color(0xFF1E1348), fontSize: 15,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
              color: Color(0xFF64748B), fontSize: 9,
            ),
            textAlign: TextAlign.center),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(sub,
              style: TextStyle(
                color: iconColor, fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center),
        ],
      ]),
    ),
  );
}

class _BadgeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label, value;
  const _BadgeCard({
    required this.icon, required this.color,
    required this.label, required this.value,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4DCFF)),
      boxShadow: [
        BoxShadow(
          color: _P.violet.op(0.06),
          blurRadius: 10, offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.op(0.10),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
              color: Color(0xFF94A3B8), fontSize: 9,
            )),
        Text(value,
            style: TextStyle(
              color: color, fontSize: 12,
              fontWeight: FontWeight.w700,
            )),
      ]),
    ]),
  );
}

// ─── Services Section ──────────────────────────────────────────────────────────
class _ServicesSection extends StatefulWidget {
  final HelperModel? helper;
  final String uid;
  final bool hi;
  const _ServicesSection(
      {required this.helper, required this.uid, required this.hi});

  @override
  State<_ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<_ServicesSection> {
  String? _activeService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('helpers')
          .doc(widget.uid)
          .snapshots(),
      builder: (ctx, snap) {
        final d        = snap.data?.data() as Map<String, dynamic>? ?? {};
        final services = List<String>.from(
            d['services'] ?? widget.helper?.services ?? []);
        final prices   = Map<String, dynamic>.from(d['servicePrices'] ?? {});
        final current  = _activeService ??
            (services.isNotEmpty ? services.first : '');

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _SectionTitle(widget.hi ? 'मेरी सेवाएं' : 'My Services'),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(ctx,
                  _UpSlide(page: const EditProfileScreen())), // ← new screen
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _P.violet.op(0.10),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _P.violet.op(0.25)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add_rounded,
                      color: _P.violet, size: 12),
                  const SizedBox(width: 4),
                  Text(widget.hi ? 'जोड़ें' : 'Add',
                      style: const TextStyle(
                        color: _P.violet, fontSize: 10,
                        fontWeight: FontWeight.w700,
                      )),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 8),

          if (services.isEmpty)
            _EmptyServicesCard(hi: widget.hi, ctx: ctx)
          else ...[
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final svc   = services[i];
                  final isAct = svc == current;
                  return GestureDetector(
                    onTap: () => setState(() => _activeService = svc),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isAct
                            ? const LinearGradient(colors: [
                          _P.cardPurple, _P.brightPurple,
                        ])
                            : null,
                        color: isAct ? null : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isAct
                              ? _P.brightPurple
                              : const Color(0xFFE4DCFF),
                        ),
                      ),
                      child: Text(svc,
                          style: TextStyle(
                            color: isAct
                                ? Colors.white
                                : const Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: isAct
                                ? FontWeight.w700 : FontWeight.w500,
                          )),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            if (current.isNotEmpty)
              _ServiceDetailCard(
                serviceName: current,
                data: d,
                prices: prices,
                hi: widget.hi,
                ctx: ctx,
              ),
          ],
        ]);
      },
    );
  }
}

class _EmptyServicesCard extends StatelessWidget {
  final bool hi;
  final BuildContext ctx;
  const _EmptyServicesCard({required this.hi, required this.ctx});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4DCFF)),
    ),
    child: Column(children: [
      Icon(Icons.construction_rounded,
          color: _P.violet.op(0.3), size: 32),
      const SizedBox(height: 8),
      Text(hi ? 'कोई सेवा नहीं जोड़ी गई' : 'No services added yet',
          style: const TextStyle(
            color: Color(0xFF64748B), fontSize: 12,
            fontWeight: FontWeight.w600,
          )),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () => Navigator.push(
            ctx, _UpSlide(page: const EditProfileScreen())), // ← new screen
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_P.editGradA, _P.brightPurple]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(hi ? 'सेवा जोड़ें' : 'Add Service',
              style: const TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w700,
              )),
        ),
      ),
    ]),
  );
}

class _ServiceDetailCard extends StatelessWidget {
  final String serviceName;
  final Map<String, dynamic> data;
  final Map<String, dynamic> prices;
  final bool hi;
  final BuildContext ctx;
  const _ServiceDetailCard({
    required this.serviceName, required this.data,
    required this.prices, required this.hi, required this.ctx,
  });

  @override
  Widget build(BuildContext context) {
    final price      = _safeInt(prices[serviceName] ?? data['pricePerVisit']);
    final expYrs     = _safeInt(data['experience']);
    final experience = expYrs > 0 ? '$expYrs yrs' : '';
    final skills     = List<String>.from(data['skills'] ?? []);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4DCFF)),
        boxShadow: [
          BoxShadow(
            color: _P.violet.op(0.06),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _P.violet.op(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.work_rounded, color: _P.violet, size: 15),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(serviceName,
              style: const TextStyle(
                color: Color(0xFF1E1348), fontSize: 13,
                fontWeight: FontWeight.w700,
              ))),
          GestureDetector(
            onTap: () => Navigator.push(
                ctx, _UpSlide(page: const EditProfileScreen())),
            child: const Icon(Icons.edit_rounded,
                color: Color(0xFF94A3B8), size: 14),
          ),
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: _P.violet.op(0.08)),
        const SizedBox(height: 10),
        Row(children: [
          if (price > 0) ...[
            _InfoChip(
              icon: Icons.currency_rupee_rounded,
              label: '₹$price${hi ? '/विज़िट' : '/visit'}',
              color: _P.violet,
            ),
            const SizedBox(width: 6),
          ],
          if (experience.isNotEmpty)
            _InfoChip(
              icon: Icons.timeline_rounded,
              label: '$experience ${hi ? 'वर्ष' : 'yrs exp'}',
              color: _P.blue,
            ),
        ]),
        if (skills.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 5, runSpacing: 5,
            children: skills.map((s) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _P.violet.op(0.07),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(s,
                    style: const TextStyle(
                      color: _P.avatarText, fontSize: 9,
                      fontWeight: FontWeight.w500,
                    )),
              );
            }).toList(),
          ),
        ],
      ]),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.op(0.08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 10),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(
            color: color, fontSize: 10,
            fontWeight: FontWeight.w600,
          )),
    ]),
  );
}

// ─── About Section ─────────────────────────────────────────────────────────────
class _AboutSection extends StatelessWidget {
  final String uid;
  final bool hi;
  const _AboutSection({required this.uid, required this.hi});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .snapshots(),
      builder: (ctx, snap) {
        final d    = snap.data?.data() as Map<String, dynamic>? ?? {};
        final desc = d['description'] as String? ?? '';
        if (desc.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(hi ? 'परिचय' : 'About'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4DCFF)),
              ),
              child: Text(desc,
                  style: const TextStyle(
                    color: Color(0xFF475569), fontSize: 12,
                    height: 1.6,
                  )),
            ),
          ],
        );
      },
    );
  }
}

// ─── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        color: Color(0xFF1E1348), fontSize: 13,
        fontWeight: FontWeight.w700, letterSpacing: -0.2,
      ));
}