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

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  // Purple gradient family (header / drawer)
  static const deepPurple  = Color(0xFF1A0848);   // darkest top
  static const midPurple   = Color(0xFF3B1882);   // header mid
  static const cardPurple  = Color(0xFF2A1270);   // card bg top
  static const brightPurple= Color(0xFF5028D0);   // card bg bottom / active
  static const iconBg      = Color(0xFF3D24A0);   // icon container
  static const violet      = Color(0xFF7C3AED);   // primary accent
  static const lavender    = Color(0xFFEDE8FF);   // avatar circle bg
  static const avatarText  = Color(0xFF5B21B6);   // avatar letter
  static const editGradA   = Color(0xFF9333EA);   // pencil/edit gradient A
  static const editGradB   = Color(0xFFBE29EC);   // pencil/edit gradient B

  // Body
  static const bodyBg      = Color(0xFFEEEDF5);   // light lavender body

  // Semantic / accent kept
  static const teal        = Color(0xFF00D4AA);   // online / success accent
  static const amber       = Color(0xFFFFA940);   // warnings / completion
  static const rose        = Color(0xFFFF5C7A);   // danger / logout
  static const blue        = Color(0xFF4A90FF);   // info
  static const green       = Color(0xFF36D399);   // success

  // Text
  static const t1          = Color(0xFFF1F5F9);   // primary on dark
  static const t3          = Color(0xFF94A3B8);   // secondary on dark

  // Drawer
  static const drawerBg    = Color(0xFF1A0848);   // very dark purple
}

// ─── Opacity helper ───────────────────────────────────────────────────────────
extension _Alpha on Color {
  Color op(double opacity) => withValues(alpha: opacity);
}

// ═══════════════════════════════════════════════════════════════════════════
// ROOT
// ═══════════════════════════════════════════════════════════════════════════
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

// ── Slide-up route ────────────────────────────────────────────────────────────
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

// ═══════════════════════════════════════════════════════════════════════════
// DRAWER
// ═══════════════════════════════════════════════════════════════════════════
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
      // ✅ Hide KYC Status once approved — replaced by the KYC Approved badge above
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
                      // ✅ KYC Approved special button (shown when approved)
                      if (kycApproved)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Opacity(
                            opacity: 0.60, // dull compared to other items
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
                                  // ✅ Green tick badge
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
            ? const LinearGradient(
            colors: [_P.editGradA, _P.editGradB])
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

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE BODY
// ═══════════════════════════════════════════════════════════════════════════
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
                  _UpSlide(page: const HelperProfileEditScreen()),
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

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final HelperModel? helper;
  final bool hi;
  final VoidCallback onMenu, onEdit;
  const _Header({
    required this.helper, required this.hi,
    required this.onMenu, required this.onEdit,
  });

  // ✅ FIX: Derive display status from helper model getters, not raw status string
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
              // Edit button
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
              // Settings / Menu button
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

          // Avatar with online dot
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
            // Edit pencil badge on avatar
            Container(
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
          ]),

          const SizedBox(height: 14),

          // Name
          Text(
            helper?.name ?? 'Sarthi Helper',
            style: const TextStyle(
              color: _P.t1, fontSize: 22,
              fontWeight: FontWeight.w800, letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),

          // Email / display ID row
          if ((helper?.email ?? '').isNotEmpty)
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.email_outlined, color: _P.t3, size: 12),
              const SizedBox(width: 4),
              Text(helper!.email,
                  style: const TextStyle(color: _P.t3, fontSize: 12)),
            ]),

          const SizedBox(height: 10),

          // Status chips
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

// ─── Customer Preview Card ────────────────────────────────────────────────────
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
        final rating  = ((d['rating'] ?? 0.0) as num).toDouble();
        final reviews = ((d['totalReviews'] ?? 0) as num).toInt();
        final price   = ((d['pricePerVisit'] ?? 0) as num).toInt();
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
              // Header bar
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
                    hi
                        ? 'ग्राहक दृश्य — आपका प्रोफ़ाइल'
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
                  // Avatar
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
                          border: Border.all(
                              color: _P.violet.op(0.20)),
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

// ─── Profile Completion Card ──────────────────────────────────────────────────
class _CompletionCard extends StatelessWidget {
  final HelperModel? helper;
  final bool hi;
  final String uid;
  const _CompletionCard(
      {required this.helper, required this.hi, required this.uid});

  static double _pct(Map<String, dynamic> d, HelperModel? h) {
    final checks = [
      (h?.name ?? '').isNotEmpty,
      (h?.phone ?? '').isNotEmpty,
      (h?.email ?? '').isNotEmpty,
      (h?.area ?? '').isNotEmpty,
      (h?.services ?? []).isNotEmpty,
      (d['serviceType'] as String? ?? '').isNotEmpty,
      (d['description'] as String? ?? '').isNotEmpty,
      (d['experience']  as String? ?? '').isNotEmpty,
      ((d['pricePerVisit'] ?? 0) as num) > 0,
      (d['skills'] as List? ?? []).isNotEmpty,
      (h?.kycDone ?? false),
      h?.status == 'approved',
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
        if (!(helper?.name.isNotEmpty ?? false))         missing.add('Name');
        if (!(helper?.area.isNotEmpty ?? false))         missing.add('Area');
        if ((helper?.services ?? []).isEmpty)            missing.add('Services');
        if ((d['serviceType'] as String? ?? '').isEmpty) missing.add('Service Type');
        if ((d['description'] as String? ?? '').isEmpty) missing.add('Description');
        if ((d['experience']  as String? ?? '').isEmpty) missing.add('Experience');
        if (((d['pricePerVisit'] ?? 0) as num) <= 0)     missing.add('Price');
        if ((d['skills'] as List? ?? []).isEmpty)        missing.add('Skills');
        if (!(helper?.kycDone ?? false))                 missing.add('KYC');

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                _P.violet.op(0.04),
              ],
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
                          : '5 fields pending — tap to see what\'s missing',
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
              // Progress bar
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
                      _UpSlide(page: const HelperProfileEditScreen())),
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
                        hi ? 'अभी पूरा करें' : "What's missing?",
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

// ─── Achievements ─────────────────────────────────────────────────────────────
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
        final rating  = ((d['rating']       ?? 0.0) as num).toDouble();
        final done    = ((d['completedJobs'] ?? 0)   as num).toInt();
        final balance = ((d['totalBalance']  ?? 0.0) as num).toDouble();
        final reviews = ((d['totalReviews']  ?? 0)   as num).toInt();
        final rank    = d['rank']   as String? ?? '';
        final streak  = ((d['streak'] ?? 0)  as num).toInt();

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

// ─── Services Section ─────────────────────────────────────────────────────────
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
        final prices   =
        Map<String, dynamic>.from(d['servicePrices'] ?? {});
        final current  = _activeService ??
            (services.isNotEmpty ? services.first : '');

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _SectionTitle(widget.hi ? 'मेरी सेवाएं' : 'My Services'),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(ctx,
                  _UpSlide(page: const HelperProfileEditScreen())),
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
            ctx, _UpSlide(page: const HelperProfileEditScreen())),
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
    final price      =
    ((prices[serviceName] ?? data['pricePerVisit'] ?? 0) as num).toInt();
    final experience = data['experience'] as String? ?? '';
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
                ctx, _UpSlide(page: const HelperProfileEditScreen())),
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

// ─── About Section ────────────────────────────────────────────────────────────
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

// ─── Shared widgets ───────────────────────────────────────────────────────────
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

// ═══════════════════════════════════════════════════════════════════════════
// PROFILE EDIT SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class HelperProfileEditScreen extends StatefulWidget {
  const HelperProfileEditScreen({super.key});
  @override
  State<HelperProfileEditScreen> createState() =>
      _HelperProfileEditScreenState();
}

class _HelperProfileEditScreenState extends State<HelperProfileEditScreen>
    with SingleTickerProviderStateMixin {

  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _areaCtrl  = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _expCtrl   = TextEditingController();
  final _skillCtrl = TextEditingController();

  String       _serviceType = '';
  List<String> _services    = [];
  List<String> _skills      = [];
  bool         _isAvailable = false;
  bool         _saving      = false;
  bool         _loaded      = false;
  String?      _activeTab;

  final Map<String, TextEditingController> _priceControllers = {};
  late final TabController _tabCtrl;

  static const _serviceTypes = [
    'Plumbing', 'Electrical', 'Cleaning', 'Carpentry',
    'Painting', 'AC Repair', 'Appliance Repair', 'Pest Control',
    'Security', 'Driver', 'Gardening', 'Cooking', 'Tutoring', 'Other',
  ];
  static const _allServices = [
    'Plumber', 'Electrician', 'AC Repair', 'Carpenter', 'Painter',
    'House Cleaning', 'Appliance Repair', 'Pest Control',
    'Security Guard', 'Driver', 'Cook / Chef', 'Gardener', 'Tutor',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _phoneCtrl.dispose(); _emailCtrl.dispose();
    _areaCtrl.dispose(); _descCtrl.dispose(); _expCtrl.dispose();
    _skillCtrl.dispose();
    for (final c in _priceControllers.values) { c.dispose(); }
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final h = context.read<AuthProvider>().helper;
    if (h == null) return;
    _nameCtrl.text  = h.name;
    _phoneCtrl.text = h.phone;
    _emailCtrl.text = h.email;
    _areaCtrl.text  = h.area;
    _services       = List.from(h.services);
    try {
      final doc    = await FirebaseFirestore.instance
          .collection('helpers').doc(h.uid).get();
      final d      = doc.data() ?? {};
      _serviceType   = d['serviceType'] as String? ?? '';
      _descCtrl.text = d['description'] as String? ?? '';
      _expCtrl.text  = d['experience']  as String? ?? '';
      _skills        = List<String>.from(d['skills'] ?? []);
      _isAvailable   = (d['isAvailable'] as bool?) ?? false;

      final prices      = Map<String, dynamic>.from(d['servicePrices'] ?? {});
      final legacyPrice = ((d['pricePerVisit'] ?? 0) as num).toInt();
      for (final svc in _services) {
        final p = prices[svc] ?? legacyPrice;
        _priceControllers[svc] =
            TextEditingController(text: p > 0 ? '$p' : '');
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _loaded    = true;
        _activeTab = _services.isNotEmpty ? _services.first : null;
      });
    }
  }

  void _toggleService(String svc) {
    setState(() {
      if (_services.contains(svc)) {
        _services.remove(svc);
        _priceControllers[svc]?.dispose();
        _priceControllers.remove(svc);
        if (_activeTab == svc) {
          _activeTab = _services.isNotEmpty ? _services.first : null;
        }
      } else {
        _services.add(svc);
        _priceControllers[svc] = TextEditingController();
        _activeTab = svc;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceType.isEmpty) {
      _snack('Please select a service type', err: true);
      return;
    }
    if (_services.isEmpty) {
      _snack('Add at least one service', err: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    final auth = context.read<AuthProvider>();
    final uid  = auth.helper?.uid ?? '';

    final Map<String, int> servicePrices = {};
    int legacyPrice = 0;
    for (final svc in _services) {
      final p =
          int.tryParse(_priceControllers[svc]?.text.trim() ?? '') ?? 0;
      servicePrices[svc] = p;
      legacyPrice = p;
    }

    try {
      await FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .update({
        'name':          _nameCtrl.text.trim(),
        'phone':         _phoneCtrl.text.trim(),
        'email':         _emailCtrl.text.trim(),
        'area':          _areaCtrl.text.trim(),
        'services':      _services,
        'serviceType':   _serviceType,
        'description':   _descCtrl.text.trim(),
        'experience':    _expCtrl.text.trim(),
        'pricePerVisit': legacyPrice,
        'servicePrices': servicePrices,
        'skills':        _skills,
        'isAvailable':   _isAvailable,
        'updatedAt':     FieldValue.serverTimestamp(),
      });
      await auth.refreshProfile();
      if (mounted) {
        _snack('Saved!');
        Navigator.pop(context);
      }
    } catch (_) {
      _snack('Save failed', err: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: err ? _P.rose : _P.violet,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ));

  void _addSkill(String s) {
    final t = s.trim();
    if (t.isEmpty || _skills.contains(t)) return;
    setState(() {
      _skills.add(t);
      _skillCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hi = context.watch<LanguageProvider>().isHindi;
    return Scaffold(
      backgroundColor: _P.bodyBg,
      body: Column(children: [
        _EditHeader(
          hi: hi, saving: _saving,
          onBack: () => Navigator.pop(context),
          onSave: _save,
        ),
        Container(
          color: _P.deepPurple,
          child: TabBar(
            controller: _tabCtrl,
            indicatorColor: _P.editGradB,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: _P.t3,
            labelStyle: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: hi ? 'व्यक्तिगत' : 'Personal'),
              Tab(text: hi ? 'सेवाएं'    : 'Services'),
            ],
          ),
        ),
        Expanded(
          child: !_loaded
              ? const Center(
              child: CircularProgressIndicator(color: _P.violet))
              : Form(
            key: _formKey,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _PersonalTab(
                  hi: hi,
                  nameCtrl: _nameCtrl,
                  phoneCtrl: _phoneCtrl,
                  emailCtrl: _emailCtrl,
                  areaCtrl: _areaCtrl,
                  descCtrl: _descCtrl,
                  isAvailable: _isAvailable,
                  onAvailableChanged: (v) =>
                      setState(() => _isAvailable = v),
                ),
                _ServicesTab(
                  hi: hi,
                  serviceType: _serviceType,
                  services: _services,
                  activeTab: _activeTab,
                  priceControllers: _priceControllers,
                  skills: _skills,
                  skillCtrl: _skillCtrl,
                  expCtrl: _expCtrl,
                  serviceTypes: _serviceTypes,
                  allServices: _allServices,
                  onServiceTypeChanged: (t) =>
                      setState(() => _serviceType = t),
                  onToggleService: _toggleService,
                  onSetActiveTab: (t) =>
                      setState(() => _activeTab = t),
                  onAddSkill: _addSkill,
                  onRemoveSkill: (s) =>
                      setState(() => _skills.remove(s)),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Personal Tab ──────────────────────────────────────────────────────────────
class _PersonalTab extends StatelessWidget {
  final bool hi;
  final TextEditingController nameCtrl, phoneCtrl, emailCtrl,
      areaCtrl, descCtrl;
  final bool isAvailable;
  final ValueChanged<bool> onAvailableChanged;

  const _PersonalTab({
    required this.hi,
    required this.nameCtrl, required this.phoneCtrl,
    required this.emailCtrl, required this.areaCtrl,
    required this.descCtrl,
    required this.isAvailable, required this.onAvailableChanged,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
    child: Column(children: [
      _EditSec(
        title: hi ? 'व्यक्तिगत जानकारी' : 'Personal Info',
        child: Column(children: [
          _EF(ctrl: nameCtrl,
              label: hi ? 'पूरा नाम' : 'Full Name',
              hint: 'Ramesh Kumar',
              icon: Icons.person_outline_rounded,
              valid: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 10),
          _EF(ctrl: phoneCtrl,
              label: hi ? 'मोबाइल' : 'Mobile',
              hint: '9876543210',
              icon: Icons.phone_android_rounded,
              type: TextInputType.phone,
              valid: (v) => v!.length < 10 ? 'Invalid' : null),
          const SizedBox(height: 10),
          _EF(ctrl: emailCtrl,
              label: hi ? 'ईमेल' : 'Email',
              hint: 'you@example.com',
              icon: Icons.email_outlined,
              type: TextInputType.emailAddress,
              valid: (v) => !v!.contains('@') ? 'Invalid' : null),
          const SizedBox(height: 10),
          _EF(ctrl: areaCtrl,
              label: hi ? 'सेवा क्षेत्र' : 'Service Area',
              hint: 'e.g. City, State',
              icon: Icons.location_on_outlined,
              valid: (v) => v!.isEmpty ? 'Required' : null),
        ]),
      ),
      const SizedBox(height: 12),
      _EditSec(
        title: hi ? 'परिचय' : 'About You',
        child: TextFormField(
          controller: descCtrl, maxLines: 4,
          style: const TextStyle(
              color: Color(0xFF1E1348), fontSize: 13),
          decoration: _editDec(hi
              ? 'अपनी सेवाओं का विवरण...'
              : 'Describe your expertise...'),
          validator: (v) => v!.isEmpty ? 'Required' : null,
        ),
      ),
      const SizedBox(height: 12),
      _EditSec(
        title: hi ? 'उपलब्धता' : 'Availability',
        child: Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isAvailable
                    ? (hi ? 'बुकिंग के लिए उपलब्ध' : 'Available for bookings')
                    : (hi ? 'अभी उपलब्ध नहीं' : 'Not available'),
                style: TextStyle(
                  color: isAvailable
                      ? _P.violet : const Color(0xFF64748B),
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                hi ? 'ऑनलाइन टॉगल से अलग' : 'Separate from online toggle',
                style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 10,
                ),
              ),
            ],
          )),
          Switch(
            value: isAvailable,
            activeColor: _P.violet,
            onChanged: onAvailableChanged,
          ),
        ]),
      ),
    ]),
  );
}

// ── Services Tab ──────────────────────────────────────────────────────────────
class _ServicesTab extends StatelessWidget {
  final bool hi;
  final String serviceType;
  final List<String> services;
  final String? activeTab;
  final Map<String, TextEditingController> priceControllers;
  final List<String> skills;
  final TextEditingController skillCtrl, expCtrl;
  final List<String> serviceTypes, allServices;
  final ValueChanged<String> onServiceTypeChanged, onSetActiveTab;
  final ValueChanged<String> onToggleService;
  final ValueChanged<String> onAddSkill, onRemoveSkill;

  const _ServicesTab({
    required this.hi, required this.serviceType,
    required this.services, required this.activeTab,
    required this.priceControllers, required this.skills,
    required this.skillCtrl, required this.expCtrl,
    required this.serviceTypes, required this.allServices,
    required this.onServiceTypeChanged, required this.onToggleService,
    required this.onSetActiveTab, required this.onAddSkill,
    required this.onRemoveSkill,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
    child: Column(children: [

      // Primary service type
      _EditSec(
        title: hi ? 'मुख्य सेवा प्रकार' : 'Primary Service Type',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hi ? 'एक प्रकार चुनें' : 'Select one type',
              style: const TextStyle(
                  color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6,
            children: serviceTypes.map((t) {
              final sel = serviceType == t;
              return GestureDetector(
                onTap: () => onServiceTypeChanged(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                        colors: [_P.cardPurple, _P.brightPurple])
                        : null,
                    color: sel ? null : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: sel ? _P.brightPurple
                            : const Color(0xFFE4DCFF)),
                  ),
                  child: Text(t,
                      style: TextStyle(
                        color: sel ? Colors.white
                            : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              );
            }).toList(),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Multi-service selection
      _EditSec(
        title: hi ? 'सेवाएं (एक से अधिक)' : 'Services (select multiple)',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _P.violet.op(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
              '${services.length} ${hi ? 'चुने' : 'selected'}',
              style: const TextStyle(
                color: _P.violet, fontSize: 10, fontWeight: FontWeight.w700,
              )),
        ),
        child: Wrap(spacing: 6, runSpacing: 6,
          children: allServices.map((sv) {
            final sel = services.contains(sv);
            return GestureDetector(
              onTap: () => onToggleService(sv),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                    horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  gradient: sel
                      ? const LinearGradient(
                      colors: [_P.cardPurple, _P.brightPurple])
                      : null,
                  color: sel ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: sel ? _P.brightPurple
                          : const Color(0xFFE4DCFF)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (sel) ...[
                    const Icon(Icons.check_rounded,
                        size: 11, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(sv,
                      style: TextStyle(
                        color: sel ? Colors.white
                            : const Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight:
                        sel ? FontWeight.w600 : FontWeight.w400,
                      )),
                ]),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 12),

      // Per-service pricing
      if (services.isNotEmpty) ...[
        _EditSec(
          title: hi ? 'प्रति सेवा मूल्य' : 'Price Per Service',
          child: Column(children: [
            if (services.length > 1) ...[
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: services.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(width: 5),
                  itemBuilder: (_, i) {
                    final svc   = services[i];
                    final isAct = svc == activeTab;
                    return GestureDetector(
                      onTap: () => onSetActiveTab(svc),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          gradient: isAct
                              ? const LinearGradient(colors: [
                            _P.cardPurple, _P.brightPurple,
                          ])
                              : null,
                          color: isAct ? null : Colors.white,
                          borderRadius: BorderRadius.circular(16),
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
                              fontSize: 10,
                              fontWeight: isAct
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            )),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (activeTab != null &&
                priceControllers[activeTab] != null) ...[
              Row(children: [
                const Icon(Icons.currency_rupee_rounded,
                    color: _P.violet, size: 13),
                const SizedBox(width: 6),
                Text(
                  '$activeTab ${hi ? 'के लिए मूल्य' : 'price per visit'}',
                  style: const TextStyle(
                    color: Color(0xFF475569), fontSize: 11,
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              TextFormField(
                controller: priceControllers[activeTab],
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: Color(0xFF1E1348), fontSize: 13),
                decoration: _editDec('150').copyWith(
                  prefixIcon: const Icon(
                    Icons.currency_rupee_rounded,
                    color: _P.violet, size: 16,
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (int.tryParse(v) == null) return 'Invalid number';
                  return null;
                },
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
      ],

      // Experience
      _EditSec(
        title: hi ? 'अनुभव' : 'Experience',
        child: _EF(
          ctrl: expCtrl,
          label: hi ? 'वर्षों में' : 'Years of experience',
          hint: '4',
          icon: Icons.timeline_rounded,
          type: TextInputType.number,
          valid: (v) => v!.isEmpty ? 'Required' : null,
        ),
      ),
      const SizedBox(height: 12),

      // Skills
      _EditSec(
        title: hi ? 'कौशल' : 'Skills',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: skillCtrl,
                  style: const TextStyle(
                      color: Color(0xFF1E1348), fontSize: 13),
                  decoration: _editDec(
                      hi ? 'कौशल जोड़ें...' : 'Type a skill...'),
                  onSubmitted: onAddSkill,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onAddSkill(skillCtrl.text),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [_P.editGradA, _P.brightPurple]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ]),
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 5, runSpacing: 5,
                children: skills.map((sk) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _P.violet.op(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _P.violet.op(0.22)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(sk,
                          style: const TextStyle(
                            color: _P.violet, fontSize: 10,
                            fontWeight: FontWeight.w600,
                          )),
                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () => onRemoveSkill(sk),
                        child: const Icon(Icons.close_rounded,
                            size: 11, color: _P.violet),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    ]),
  );
}

InputDecoration _editDec(String hint) => InputDecoration(
  hintText: hint,
  hintStyle: const TextStyle(
      color: Color(0xFFCBD5E1), fontSize: 12),
  filled: true,
  fillColor: Colors.white,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE4DCFF)),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFE4DCFF)),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: _P.violet, width: 1.5),
  ),
  contentPadding: const EdgeInsets.all(12),
);

// ── Edit Header ────────────────────────────────────────────────────────────────
class _EditHeader extends StatelessWidget {
  final bool hi, saving;
  final VoidCallback onBack, onSave;
  const _EditHeader({
    required this.hi, required this.saving,
    required this.onBack, required this.onSave,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 10,
      bottom: 12, left: 4, right: 14,
    ),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_P.deepPurple, _P.midPurple],
      ),
    ),
    child: Row(children: [
      IconButton(
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _P.t1, size: 18),
      ),
      Expanded(
        child: Text(
          hi ? 'प्रोफ़ाइल संपादित करें' : 'Edit Profile',
          style: const TextStyle(
            color: _P.t1, fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      saving
          ? const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        ),
      )
          : GestureDetector(
        onTap: onSave,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_P.editGradA, _P.editGradB],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _P.editGradA.op(0.40),
                blurRadius: 8, offset: const Offset(0, 3),
              ),
            ],
          ),
          child: const Text('SAVE',
              style: TextStyle(
                color: Colors.white, fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              )),
        ),
      ),
    ]),
  );
}

// ── Edit Section ──────────────────────────────────────────────────────────────
class _EditSec extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const _EditSec(
      {required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4DCFF)),
      boxShadow: [
        BoxShadow(
          color: _P.violet.op(0.05),
          blurRadius: 8, offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title,
            style: const TextStyle(
              color: Color(0xFF1E1348), fontSize: 13,
              fontWeight: FontWeight.w700,
            )),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

// ── Edit Form Field ────────────────────────────────────────────────────────────
class _EF extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType? type;
  final String? Function(String?)? valid;
  const _EF({
    required this.ctrl, required this.label, required this.hint,
    required this.icon, this.type, this.valid,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Icon(icon, size: 12, color: _P.violet),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
              color: Color(0xFF475569), fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ]),
      const SizedBox(height: 5),
      TextFormField(
        controller: ctrl, keyboardType: type,
        style: const TextStyle(
            color: Color(0xFF1E1348), fontSize: 13),
        decoration: _editDec(hint).copyWith(
          prefixIcon: Icon(icon, color: _P.violet, size: 16),
        ),
        validator: valid,
      ),
    ],
  );
}