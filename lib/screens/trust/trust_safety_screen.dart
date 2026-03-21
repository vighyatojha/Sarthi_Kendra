// lib/screens/trust/trust_safety_screen.dart
// Adapted from user-app AboutScreen for HELPER side
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class TrustSafetyScreen extends StatefulWidget {
  const TrustSafetyScreen({super.key});
  @override
  State<TrustSafetyScreen> createState() => _TrustSafetyScreenState();
}

class _TrustSafetyScreenState extends State<TrustSafetyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stagger;
  late final List<Animation<double>> _fades;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fades = List.generate(6, (i) {
      final s = (i * 0.13).clamp(0.0, 0.78);
      final e = (s + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _stagger,
            curve: Interval(s, e, curve: Curves.easeOut)),
      );
    });
  }

  @override
  void dispose() { _stagger.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid    = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF4F6FB),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _TrustHero(stagger: _stagger)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),

                _FadeIn(animation: _fades[0],
                    child: _TrustScoreCard(uid: uid, isDark: isDark)),
                const SizedBox(height: 28),

                _sectionLabel('VERIFICATION STATUS', isDark),
                const SizedBox(height: 12),
                _FadeIn(animation: _fades[1],
                    child: _VerificationRow(uid: uid)),
                const SizedBox(height: 28),

                _sectionLabel('RATINGS FROM CUSTOMERS', isDark),
                const SizedBox(height: 4),
                _FadeIn(animation: _fades[2],
                    child: _subLabel(
                        'What customers said about your work.', isDark)),
                const SizedBox(height: 12),
                _FadeIn(animation: _fades[3],
                    child: _CustomerRatingsFeed(uid: uid, isDark: isDark)),
                const SizedBox(height: 28),

                _sectionLabel('REPORT HISTORY', isDark),
                const SizedBox(height: 12),
                _FadeIn(animation: _fades[4],
                    child: _ReportHistory(uid: uid, isDark: isDark)),
                const SizedBox(height: 28),

                _FadeIn(animation: _fades[5],
                    child: _SafetyTips(isDark: isDark)),
                const SizedBox(height: 28),

                const Center(child: Row(
                    mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.lock_rounded, size: 12, color: Color(0xFFB0B8CC)),
                  SizedBox(width: 5),
                  Text('Your data is end-to-end encrypted',
                      style: TextStyle(fontSize: 11, color: Color(0xFFB0B8CC))),
                ])),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) => Text(text,
      style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.4,
        color: isDark ? AppColors.textSoftDark : const Color(0xFF9CA3AF),
      ));

  Widget _subLabel(String text, bool isDark) => Text(text,
      style: TextStyle(fontSize: 12, height: 1.4,
          color: isDark ? AppColors.textMidDark : const Color(0xFF9CA3AF)));
}

class _FadeIn extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeIn({required this.animation, required this.child});
  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: animation, child: child);
}

// ── Hero ──────────────────────────────────────────────────────────────────────
class _TrustHero extends StatelessWidget {
  final AnimationController stagger;
  const _TrustHero({required this.stagger});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid,
            AppColors.gradientEnd],
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(children: [
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
            const SizedBox(width: 14),
            const Text('Trust & Safety', style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const Spacer(),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.shield_rounded,
                  color: Colors.white, size: 18),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        // Static shield
        Stack(alignment: Alignment.center, children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyanAccent.withOpacity(0.15),
            ),
          ),
          Container(
            width: 78, height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0.22),
                Colors.white.withOpacity(0.08),
              ]),
              border: Border.all(
                  color: Colors.white.withOpacity(0.28), width: 1.5),
            ),
            child: const Icon(Icons.shield_rounded,
                size: 38, color: Colors.white),
          ),
        ]),
        const SizedBox(height: 18),
        const Text('Your Reputation\nIs Your Business',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                color: Colors.white, height: 1.25)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Verified profile · Customer ratings · Clean record',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12,
                color: Colors.white.withOpacity(0.65), height: 1.5),
          ),
        ),
        const SizedBox(height: 26),
        Container(height: 26,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.bgDark : const Color(0xFFF4F6FB),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28), topRight: Radius.circular(28)),
            )),
      ])),
    );
  }
}

// ── Trust Score Card ──────────────────────────────────────────────────────────
class _TrustScoreCard extends StatelessWidget {
  final String uid;
  final bool   isDark;
  const _TrustScoreCard({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: uid.isNotEmpty
          ? FirebaseFirestore.instance.collection('helpers').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (context, snap) {
        final data        = snap.data?.data() as Map<String, dynamic>? ?? {};
        final avgRating   = ((data['rating'] ?? data['avgRating'] ?? 0.0) as num).toDouble();
        final reviewCount = ((data['reviewCount'] ?? data['totalJobs'] ?? 0) as num).toInt();

        String badge = 'New Helper';
        if (avgRating >= 4.8)      badge = 'Top Rated Helper';
        else if (avgRating >= 4.5) badge = 'Excellent Helper';
        else if (avgRating >= 4.0) badge = 'Trusted Helper';
        else if (avgRating >= 3.0) badge = 'Good Standing';

        final display = reviewCount == 0 ? '—' : avgRating.toStringAsFixed(1);

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientMid,
                AppColors.gradientEnd],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
              color:      AppColors.gradientEnd.withOpacity(0.28),
              blurRadius: 20, offset: const Offset(0, 8),
            )],
          ),
          child: Column(children: [
            Text('YOUR TRUST SCORE', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.6,
              color: AppColors.cyanAccent.withOpacity(0.9),
            )),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 42),
                  const SizedBox(width: 8),
                  Text(display, style: const TextStyle(
                    fontSize: 48, fontWeight: FontWeight.bold,
                    color: Colors.white, height: 1.0,
                  )),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('/5', style: TextStyle(
                        fontSize: 18, color: Color(0xFFB2E8E8),
                        fontWeight: FontWeight.w500)),
                  ),
                ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.20)),
              ),
              child: Text(
                reviewCount == 0 ? 'No ratings yet' : badge,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            if (reviewCount > 0) ...[
              const SizedBox(height: 10),
              Text('Based on $reviewCount customer rating${reviewCount == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withOpacity(0.55))),
            ],
          ]),
        );
      },
    );
  }
}

// ── Verification Row ──────────────────────────────────────────────────────────
class _VerificationRow extends StatelessWidget {
  final String uid;
  const _VerificationRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    final user           = FirebaseAuth.instance.currentUser;
    final emailVerified  = user?.emailVerified ?? false;
    final phoneVerified  = user?.phoneNumber   != null;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid.isNotEmpty
          ? FirebaseFirestore.instance.collection('helpers').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (context, snap) {
        final data    = snap.data?.data() as Map<String, dynamic>? ?? {};
        final kycDone = (data['kycDone'] as bool?) ?? false;

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 10,
                offset: const Offset(0, 3))],
          ),
          child: Row(children: [
            _VerifChip(icon: Icons.phone_android_rounded,
                label: 'Mobile\nVerified',  done: phoneVerified),
            _VerifChip(icon: Icons.email_rounded,
                label: 'Email\nVerified',   done: emailVerified),
            _VerifChip(icon: Icons.fingerprint_rounded,
                label: 'KYC\nDone',          done: kycDone),
          ]),
        );
      },
    );
  }
}

class _VerifChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     done;
  const _VerifChip({required this.icon, required this.label, required this.done});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: done
            ? AppColors.brandPurple.withOpacity(0.12)
            : const Color(0xFFF3F4F6),
        shape: BoxShape.circle,
      ),
      child: Icon(icon,
          color: done ? AppColors.brandPurple : const Color(0xFFD1D5DB),
          size: 24),
    ),
    const SizedBox(height: 8),
    Text(label, textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w600,
            color: Color(0xFF374151), height: 1.4)),
    const SizedBox(height: 5),
    Icon(done ? Icons.check_circle_rounded : Icons.cancel_rounded,
        size: 16,
        color: done ? AppColors.success : const Color(0xFFD1D5DB)),
  ]));
}

// ── Customer Ratings Feed ─────────────────────────────────────────────────────
class _CustomerRatingsFeed extends StatelessWidget {
  final String uid;
  final bool   isDark;
  const _CustomerRatingsFeed({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _empty(isDark);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status',   isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _Shimmer(count: 2);
        }
        final docs = snap.data?.docs ?? [];
        // Only show docs that have a rating
        final rated = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['userRating'] != null && (data['userRating'] as num) > 0;
        }).toList();

        if (rated.isEmpty) return _empty(isDark);

        return Column(children: rated.map((doc) {
          final d      = doc.data() as Map<String, dynamic>;
          final user   = (d['userName']   ?? 'Customer') as String;
          final stars  = ((d['userRating'] ?? 0)   as num).toInt();
          final review = (d['userReview'] ?? '') as String;
          final ts     = (d['completedAt'] as Timestamp?)?.toDate();
          final svc    = (d['serviceName'] ?? '') as String;

          return Container(
            margin:  const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                  blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color:  AppColors.cyanAccent.withOpacity(0.15),
                  shape:  BoxShape.circle,
                ),
                child: Center(child: Text(
                  user.isNotEmpty ? user[0].toUpperCase() : 'U',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                      color: AppColors.cyanAccent),
                )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(user, style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDarkLight,
                  ))),
                  Row(children: [
                    Text('$stars.0', style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: AppColors.warning)),
                    const SizedBox(width: 3),
                    const Icon(Icons.star_rounded,
                        color: AppColors.warning, size: 16),
                  ]),
                ]),
                if (svc.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(svc, style: TextStyle(fontSize: 11,
                      color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight)),
                ],
                if (review.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text('"$review"', style: TextStyle(
                    fontSize: 12, fontStyle: FontStyle.italic, height: 1.4,
                    color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
                  )),
                ],
                if (ts != null) ...[
                  const SizedBox(height: 6),
                  Text(_ago(ts), style: const TextStyle(
                      fontSize: 10, color: Color(0xFFB0B8CC))),
                ],
              ])),
            ]),
          );
        }).toList());
      },
    );
  }

  Widget _empty(bool isDark) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    decoration: BoxDecoration(
      color:        isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(18),
      border:       Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: Column(children: [
      Container(width: 56, height: 56,
          decoration: BoxDecoration(
            color:  AppColors.brandPurple.withOpacity(0.1),
            shape:  BoxShape.circle,
          ),
          child: const Icon(Icons.star_outline_rounded,
              size: 26, color: AppColors.brandPurple)),
      const SizedBox(height: 12),
      Text('No customer ratings yet', style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : AppColors.textDarkLight,
      )),
      const SizedBox(height: 5),
      Text('Complete bookings to earn ratings from customers',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5,
              color: isDark ? AppColors.textMidDark : AppColors.textMidLight)),
    ]),
  );

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 30) return '${diff.inDays}d ago';
    return DateFormat('d MMM yyyy').format(dt);
  }
}

// ── Report History ────────────────────────────────────────────────────────────
class _ReportHistory extends StatelessWidget {
  final String uid;
  final bool   isDark;
  const _ReportHistory({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_reports')
          .where('helperId', isEqualTo: uid)
          .limit(5)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
            decoration: BoxDecoration(
              color:        isDark ? AppColors.cardDark : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
              SizedBox(width: 12),
              Text('No reports — clean record!', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: AppColors.success)),
            ]),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color:        isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(children: docs.asMap().entries.map((e) {
            final d      = e.value.data() as Map<String, dynamic>;
            final reason = (d['reason'] ?? 'Report') as String;
            final ts     = (d['timestamp'] as Timestamp?)?.toDate();
            final status = ((d['status'] ?? 'pending') as String).toLowerCase();
            final isLast = e.key == docs.length - 1;

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: BoxDecoration(
                border: isLast ? null : Border(
                    bottom: BorderSide(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight)),
              ),
              child: Row(children: [
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(reason, style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.textDarkLight)),
                  if (ts != null) Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text('Reported on ${DateFormat('d MMM yyyy').format(ts)}',
                        style: const TextStyle(fontSize: 11,
                            color: Color(0xFF9CA3AF))),
                  ),
                ])),
                _StatusBadge(status: status),
              ]),
            );
          }).toList()),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg; String label;
    switch (status) {
      case 'resolved':
        bg = AppColors.success.withOpacity(0.12);
        fg = AppColors.success;
        label = 'RESOLVED'; break;
      case 'under_review':
        bg = AppColors.brandPurple.withOpacity(0.12);
        fg = AppColors.brandPurple;
        label = 'REVIEWING'; break;
      default:
        bg = AppColors.warning.withOpacity(0.12);
        fg = AppColors.warning;
        label = 'PENDING';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(
          fontSize: 9, fontWeight: FontWeight.bold,
          color: fg, letterSpacing: 0.4)),
    );
  }
}

// ── Safety Tips ───────────────────────────────────────────────────────────────
class _SafetyTips extends StatelessWidget {
  final bool isDark;
  const _SafetyTips({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final tips = [
      (Icons.badge_rounded,          AppColors.brandPurple, 'Always carry your Sarthi ID'),
      (Icons.photo_camera_rounded,   AppColors.cyanAccent,  'Take before/after photos of work'),
      (Icons.no_photography_rounded, AppColors.warning,     'Never share OTP or bank details'),
      (Icons.support_agent_rounded,  AppColors.success,     'Report issues to 24/7 support'),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color:        AppColors.brandPurple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                color: AppColors.brandPurple, size: 20),
          ),
          const SizedBox(width: 12),
          Text('Safety Tips for Helpers', style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.textDarkLight,
          )),
        ]),
        const SizedBox(height: 16),
        ...tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color:        t.$2.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(t.$1, color: t.$2, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(t.$3, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
            ))),
          ]),
        )),
      ]),
    );
  }
}

// ── Shimmer ───────────────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final int count;
  const _Shimmer({required this.count});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) => Column(children: List.generate(widget.count, (_) =>
        Container(
          margin: const EdgeInsets.only(bottom: 10), height: 90,
          decoration: BoxDecoration(
            color: Color.lerp(const Color(0xFFF3F4F6),
                const Color(0xFFE5E7EB), _c.value),
            borderRadius: BorderRadius.circular(18),
          ),
        )
    )),
  );
}