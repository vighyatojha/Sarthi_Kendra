// lib/screens/trust/trust_safety_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/realtime_db_service.dart';
import '../review/mutual_review_sheet.dart';
import '../../providers/auth_provider.dart';

// ── Light-only palette ────────────────────────────────────────────────────────
const _purple = Color(0xFF7C3AED);
const _indigo = Color(0xFF2D1B69);
const _violet = Color(0xFF5B21B6);
const _green  = Color(0xFF16A34A);
const _amber  = Color(0xFFF59E0B);
const _red    = Color(0xFFEF4444);
const _bg     = Color(0xFFF8F7FF);
const _t1     = Color(0xFF1E1B4B);
const _t2     = Color(0xFF64748B);
const _t3     = Color(0xFF94A3B8);
const _border = Color(0xFFEDE9FE);

double _sd(dynamic v) =>
    v == null ? 0.0 : v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

// ═══════════════════════════════════════════════════════════════════════════════
class TrustSafetyScreen extends StatefulWidget {
  const TrustSafetyScreen({super.key});
  @override
  State<TrustSafetyScreen> createState() => _TrustSafetyScreenState();
}

class _TrustSafetyScreenState extends State<TrustSafetyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<Animation<double>> _fades;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fades = List.generate(6, (i) {
      final s = (i * 0.15).clamp(0.0, 0.75);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
            parent: _ctrl,
            curve: Interval(s, (s + 0.4).clamp(0.0, 1.0),
                curve: Curves.easeOut)),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().helper?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Hero()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _fade(0, _AvgRatingCard(uid: uid)),
                const SizedBox(height: 16),
                _fade(1, _VerificationCard(uid: uid)),
                const SizedBox(height: 16),
                _fade(2, _RateUserSection(uid: uid)),   // ← NEW: rate customers CTA
                const SizedBox(height: 16),
                _fade(3, _CustomerReviewsSection(uid: uid)),
                const SizedBox(height: 16),
                _fade(4, _ReportHistory(uid: uid)),
                const SizedBox(height: 16),
                _fade(5, const _SafetyTips()),
                const SizedBox(height: 10),
                const Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_rounded, size: 11, color: _t3),
                    SizedBox(width: 5),
                    Text('Your data is end-to-end encrypted',
                        style: TextStyle(fontSize: 11, color: _t3)),
                  ]),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fade(int i, Widget child) =>
      FadeTransition(opacity: _fades[i], child: child);
}

// ── Hero (gradient header with curve) ────────────────────────────────────────
// ── Hero (dark navy/teal — matches user-side style, reversed curve via borderRadius) ──
class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0F2042), Color(0xFF1A3A6B), Color(0xFF0D6E6E)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              const Text('Trust & Safety',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const Spacer(),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shield_rounded,
                    color: Colors.white, size: 20),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          Stack(alignment: Alignment.center, children: [
            Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0D9488).withOpacity(0.18))),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    Colors.white.withOpacity(0.22),
                    Colors.white.withOpacity(0.08),
                  ]),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.28), width: 1.5)),
              child: const Icon(Icons.verified_user_rounded,
                  size: 34, color: Colors.white),
            ),
          ]),
          const SizedBox(height: 16),
          const Text('Your Reputation',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Verified profile · Customer ratings · Clean record',
              textAlign: TextAlign.center,
              style:
              TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
            ),
          ),
          const SizedBox(height: 26),
          // ← This IS the reversed curve: concave scoop into the header
          Container(
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}


// ── Average Rating Card (top hero card) ──────────────────────────────────────
class _AvgRatingCard extends StatelessWidget {
  final String uid;
  const _AvgRatingCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('helpers')
          .doc(uid)
          .snapshots(),
      builder: (ctx, helperSnap) {
        final d =
            helperSnap.data?.data() as Map<String, dynamic>? ?? {};
        final storedAvg = _sd(d['rating'] ?? d['avgRating'] ?? 0);
        final storedCount =
            (d['totalReviews'] ?? d['reviewCount'] ?? 0) as int? ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: uid.isEmpty
              ? const Stream.empty()
              : FirebaseFirestore.instance
              .collectionGroup('user_to_helper')
              .where('revieweeId', isEqualTo: uid)
              .limit(50)
              .snapshots(),
          builder: (ctx2, reviewSnap) {
            final Map<int, int> breakdown = {
              5: 0,
              4: 0,
              3: 0,
              2: 0,
              1: 0
            };
            int ratedCount = 0;
            double sum = 0;

            if (reviewSnap.hasData) {
              for (final doc in reviewSnap.data!.docs) {
                final bd = doc.data() as Map<String, dynamic>;
                final r = ((bd['starRating'] ?? bd['userRating']) as num?)
                    ?.round()
                    .clamp(1, 5) ??
                    0;
                if (r > 0) {
                  breakdown[r] = (breakdown[r] ?? 0) + 1;
                  sum += r;
                  ratedCount++;
                }
              }
            }

            final liveAvg =
            ratedCount > 0 ? sum / ratedCount : storedAvg;
            final total =
            ratedCount > 0 ? ratedCount : storedCount;

            String badge = 'New Helper';
            Color badgeColor = _t3;
            if (liveAvg >= 4.8) {
              badge = '🏆 Top Rated';
              badgeColor = _amber;
            } else if (liveAvg >= 4.5) {
              badge = '⭐ Excellent';
              badgeColor = _green;
            } else if (liveAvg >= 4.0) {
              badge = '✅ Trusted';
              badgeColor = _purple;
            } else if (liveAvg >= 3.0) {
              badge = '👍 Good';
              badgeColor = _t2;
            }

            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                      color: _purple.withOpacity(0.10),
                      blurRadius: 20,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Column(children: [
                Row(children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('OVERALL RATING',
                            style: TextStyle(
                                color: _t3,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1)),
                        const SizedBox(height: 8),
                        Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.end,
                            children: [
                              Text(
                                total == 0
                                    ? '0.0'
                                    : liveAvg.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: _t1,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0),
                              ),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: Text(' /5',
                                    style: TextStyle(
                                        color: _t3,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600)),
                              ),
                            ]),
                        Row(
                            children: List.generate(5, (i) {
                              final filled = i < liveAvg.round();
                              return Icon(
                                filled
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: filled ? _amber : _t3,
                                size: 18,
                              );
                            })),
                        const SizedBox(height: 6),
                        Text(
                          '$total rating${total == 1 ? '' : 's'}',
                          style:
                          const TextStyle(color: _t2, fontSize: 12),
                        ),
                      ]),
                  const Spacer(),
                  Column(
                    children: [5, 4, 3, 2, 1].map((star) {
                      final count = breakdown[star] ?? 0;
                      final pct = total > 0 ? count / total : 0.0;
                      return Padding(
                        padding:
                        const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Text('$star',
                              style: const TextStyle(
                                  color: _t3,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded,
                              color: _amber, size: 10),
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 80,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                backgroundColor:
                                const Color(0xFFEDE9FE),
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                    _purple),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('$count',
                              style: const TextStyle(
                                  color: _t3, fontSize: 10)),
                        ]),
                      );
                    }).toList(),
                  ),
                ]),
                if (total > 0) ...[
                  const SizedBox(height: 16),
                  Container(height: 1, color: _border),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: badgeColor.withOpacity(0.20))),
                    child: Center(
                      child: Text(badge,
                          style: TextStyle(
                              color: badgeColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8F7FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border)),
                    child: const Column(children: [
                      Text('No ratings yet',
                          style: TextStyle(
                              color: _t2,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 3),
                      Text('Complete jobs to receive ratings',
                          style: TextStyle(color: _t3, fontSize: 11)),
                    ]),
                  ),
                ],
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Verification card ─────────────────────────────────────────────────────────
class _VerificationCard extends StatelessWidget {
  final String uid;
  const _VerificationCard({required this.uid});

  @override
  Widget build(BuildContext context) {
    final user         = FirebaseAuth.instance.currentUser;
    final phoneVerified = user?.phoneNumber != null;
    final emailVerified = user?.emailVerified ?? false;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance.collection('helpers').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final d = snap.data?.data() as Map<String, dynamic>? ?? {};
        final kycDone = d['kycDone'] as bool? ?? false;
        final isApproved = (d['kycStatus'] as String? ?? '') == 'approved';

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _RowHead(icon: Icons.verified_rounded, label: 'Verification Status'),
            const SizedBox(height: 16),
            Row(children: [
              _VerifTile(
                icon: Icons.phone_android_rounded,
                label: 'Mobile',
                done: phoneVerified,
                color: _green,
              ),
              _VerifTile(
                icon: Icons.email_rounded,
                label: 'Email',
                done: emailVerified,
                color: _purple,
              ),
              _VerifTile(
                icon: Icons.fingerprint_rounded,
                label: 'KYC',
                done: kycDone || isApproved,
                color: _amber,
              ),
            ]),
          ]),
        );
      },
    );
  }
}

class _VerifTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;
  final Color color;
  const _VerifTile(
      {required this.icon,
        required this.label,
        required this.done,
        required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color:
          done ? color.withOpacity(0.12) : const Color(0xFFF1F0FF),
          shape: BoxShape.circle,
          border: Border.all(
              color: done
                  ? color.withOpacity(0.30)
                  : const Color(0xFFEDE9FE),
              width: 1.5),
        ),
        child: Icon(icon,
            color: done ? color : _t3, size: 24),
      ),
      const SizedBox(height: 8),
      Text(label,
          style: const TextStyle(
              color: _t1, fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          done
              ? Icons.check_circle_rounded
              : Icons.radio_button_unchecked_rounded,
          size: 14,
          color: done ? _green : _t3,
        ),
        const SizedBox(width: 3),
        Text(done ? 'Verified' : 'Pending',
            style: TextStyle(
                color: done ? _green : _t3,
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]),
    ]),
  );
}

// ── Customer Reviews Section ──────────────────────────────────────────────────
class _CustomerReviewsSection extends StatelessWidget {
  final String uid;
  const _CustomerReviewsSection({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('user_to_helper')
          .where('revieweeId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                child: Row(children: [
                  const _RowHead(
                      icon: Icons.rate_review_rounded,
                      label: 'Customer Reviews'),
                  const Spacer(),
                  if (docs.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _purple.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('${docs.length} reviews',
                          style: const TextStyle(
                              color: _purple,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8F7FF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border)),
                    child: const Column(children: [
                      Icon(Icons.star_outline_rounded,
                          color: _t3, size: 32),
                      SizedBox(height: 8),
                      Text('No reviews yet',
                          style: TextStyle(
                              color: _t2,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Complete jobs to receive reviews',
                          style: TextStyle(color: _t3, fontSize: 11)),
                    ]),
                  ),
                )
              else
                ...docs.asMap().entries.map((e) {
                  final isLast = e.key == docs.length - 1;
                  return _ReviewTile(doc: e.value, isLast: isLast);
                }),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isLast;
  const _ReviewTile({required this.doc, required this.isLast});

  String _ago(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;
    // supports both review-subcollection (starRating) and booking-inline (userRating)
    final reviewerName =
    (d['reviewerName'] ?? d['userName'] ?? 'Customer') as String;
    final stars =
    ((d['starRating'] ?? d['userRating'] ?? 0) as num)
        .round()
        .clamp(1, 5);
    final svc = (d['serviceName'] ?? '') as String;
    final note = (d['additionalNote'] ?? d['userReview'] ?? '') as String;
    final answers = d['answers'] as Map<String, dynamic>? ?? {};
    final firstAnswer =
    answers.values.isNotEmpty ? answers.values.first.toString() : null;
    final displayText = note.isNotEmpty ? note : firstAnswer;
    final ts =
    (d['createdAt'] as Timestamp?)?.toDate()?.toLocal();
    final initial =
    reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'C';
    final starColor =
    stars >= 4 ? _green : (stars == 3 ? _amber : _red);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1A3A6B), Color(0xFF0D6E6E)]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(reviewerName,
                                style: const TextStyle(
                                    color: _t1,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: starColor.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: starColor.withOpacity(0.25))),
                          child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: starColor, size: 13),
                                const SizedBox(width: 3),
                                Text('$stars.0',
                                    style: TextStyle(
                                        color: starColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ]),
                        ),
                      ]),
                      if (svc.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.home_repair_service_rounded,
                              size: 11, color: _t3),
                          const SizedBox(width: 3),
                          Text(svc,
                              style: const TextStyle(
                                  color: _t3, fontSize: 11)),
                        ]),
                      ],
                      if (displayText != null &&
                          displayText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF8F7FF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _border)),
                          child: Text('"$displayText"',
                              style: const TextStyle(
                                  color: _t2,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  height: 1.5)),
                        ),
                      ],
                      if (ts != null) ...[
                        const SizedBox(height: 6),
                        Text(_ago(ts),
                            style: const TextStyle(
                                color: _t3, fontSize: 10)),
                      ],
                    ]),
              ),
            ]),
      ),
      if (!isLast)
        Divider(
            height: 1,
            color: const Color(0xFFF1F0FF),
            indent: 16,
            endIndent: 16),
    ]);
  }
}

// ── Report History ────────────────────────────────────────────────────────────
class _ReportHistory extends StatelessWidget {
  final String uid;
  const _ReportHistory({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat_reports')
          .where('helperId', isEqualTo: uid)
          .limit(5)
          .snapshots(),
      builder: (ctx, snap) {
        final docs = snap.data?.docs ?? [];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const _RowHead(
                icon: Icons.history_rounded, label: 'Report History'),
            const SizedBox(height: 14),
            if (docs.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green.withOpacity(0.20))),
                child: const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: _green, size: 20),
                  SizedBox(width: 10),
                  Text('No reports — clean record!',
                      style: TextStyle(
                          color: _green,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ]),
              )
            else
              ...docs.map((doc) {
                final d      = doc.data() as Map<String, dynamic>;
                final reason = (d['reason'] ?? 'Report') as String;
                final ts     = (d['timestamp'] as Timestamp?)?.toDate();
                final status =
                ((d['status'] ?? 'pending') as String).toLowerCase();
                Color sc; String sl;
                switch (status) {
                  case 'resolved':
                    sc = _green; sl = 'RESOLVED'; break;
                  case 'under_review':
                    sc = _purple; sl = 'REVIEWING'; break;
                  default:
                    sc = _amber; sl = 'PENDING';
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: _bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border)),
                  child: Row(children: [
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(reason,
                              style: const TextStyle(
                                  color: _t1,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          if (ts != null)
                            Text(
                              DateFormat('d MMM yyyy').format(ts),
                              style: const TextStyle(
                                  color: _t3, fontSize: 11),
                            ),
                        ])),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: sc.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(sl,
                          style: TextStyle(
                              color: sc,
                              fontSize: 9,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                );
              }),
          ]),
        );
      },
    );
  }
}

// ── Safety tips ───────────────────────────────────────────────────────────────
class _SafetyTips extends StatelessWidget {
  const _SafetyTips();

  @override
  Widget build(BuildContext context) {
    final tips = [
      (Icons.badge_rounded, _purple, 'Always carry your Sarthi ID card'),
      (Icons.photo_camera_rounded, const Color(0xFF06B6D4),
      'Take before & after photos of work'),
      (Icons.no_photography_rounded, _amber,
      'Never share OTP or bank details'),
      (Icons.support_agent_rounded, _green, 'Report issues to 24/7 support'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _RowHead(
            icon: Icons.tips_and_updates_rounded, label: 'Safety Tips'),
        const SizedBox(height: 14),
        ...tips.map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: t.$2.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(t.$1, color: t.$2, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Text(t.$3,
                    style: const TextStyle(
                        color: _t2,
                        fontSize: 13,
                        fontWeight: FontWeight.w500))),
          ]),
        )),
      ]),
    );
  }
}

// ── Rate Your Customers Section ───────────────────────────────────────────────
class _RateUserSection extends StatelessWidget {
  final String uid;
  const _RateUserSection({required this.uid});

  static const _questions = [
    _RQ('Did the customer treat you respectfully?', [
      'Very respectfully',
      'Mostly yes',
      'Somewhat rude',
      'Disrespectful'
    ]),
    _RQ('Was the service request clear and genuine?', [
      'Yes, completely',
      'Mostly clear',
      'Slightly vague',
      'Confusing/suspicious'
    ]),
    _RQ('Was the address and access provided correctly?', [
      'Yes, perfect',
      'Minor issues',
      'Wrong address',
      'No access given'
    ]),
    _RQ('Did the customer make unreasonable demands?', [
      'No, totally fair',
      'Minor extras',
      'Several extras',
      'Very unreasonable'
    ]),
    _RQ('Was payment handled smoothly?', [
      'Yes, no issues',
      'Minor delay',
      'Refused full payment',
      'Payment issues'
    ]),
    _RQ('Would you accept this customer again?', [
      'Definitely yes',
      'Maybe',
      'Hesitant',
      'No'
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .limit(10)
          .snapshots(),
      builder: (ctx, snap) {
        // Sort in-memory to avoid composite index requirement
        final sorted = (snap.data?.docs ?? [])
          ..sort((a, b) {
            final ta = ((a.data() as Map)['completedAt'] as Timestamp?)
                ?.millisecondsSinceEpoch ?? 0;
            final tb = ((b.data() as Map)['completedAt'] as Timestamp?)
                ?.millisecondsSinceEpoch ?? 0;
            return tb.compareTo(ta);
          });
        final unrated = sorted.where((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return d['helperRating'] == null;
        }).toList();

        if (unrated.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const _RowHead(
                      icon: Icons.how_to_reg_rounded,
                      label: 'Rate Your Customers'),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _amber.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${unrated.length} pending',
                        style: const TextStyle(
                            color: _amber,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 4),
                const Text(
                    'Rate customers to help maintain community quality.',
                    style: TextStyle(color: _t3, fontSize: 11)),
                const SizedBox(height: 14),
                ...unrated.map((doc) {
                  final d = doc.data() as Map<String, dynamic>;
                  final userName =
                  (d['userName'] ?? d['customerName'] ?? 'Customer')
                  as String;
                  final svc = (d['serviceName'] ?? '') as String;
                  final userId = (d['userId'] ?? '') as String;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFF1A3A6B),
                              Color(0xFF0D6E6E)
                            ]),
                            shape: BoxShape.circle),
                        child: Center(
                            child: Text(
                                userName.isNotEmpty
                                    ? userName[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(userName,
                                    style: const TextStyle(
                                        color: _t1,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                if (svc.isNotEmpty)
                                  Text(svc,
                                      style: const TextStyle(
                                          color: _t3, fontSize: 11)),
                              ])),
                      GestureDetector(
                        onTap: () => _showRateSheet(
                            context, doc.id, userId, userName, svc),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF1A3A6B),
                                    Color(0xFF0D6E6E)
                                  ]),
                              borderRadius:
                              BorderRadius.circular(10)),
                          child: const Text('Rate',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12)),
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
        );
      },
    );
  }
  void _showRateSheet(BuildContext context, String bookingId,
      String userId, String userName, String svc) {
    MutualReviewSheet.showForHelper(
      context,
      bookingId:   bookingId,
      userId:      userId,
      userName:    userName,
      serviceName: svc,
      onAfterClose: () {
        RealtimeDbService.instance.deleteChat(bookingId).then((_) {
          FirebaseFirestore.instance
              .collection('chats')
              .doc(bookingId)
              .update({'bookingStatus': 'review_done'})
              .catchError((_) {});
        });
      },
    );
  }
}

// Data class for a review question
class _RQ {
  final String question;
  final List<String> options;
  const _RQ(this.question, this.options);
}

// ── Bottom sheet: Helper rates User ──────────────────────────────────────────
class _HelperRateUserSheet extends StatefulWidget {
  final String bookingId, userId, userName, serviceName;
  final List<_RQ> questions;
  const _HelperRateUserSheet(
      {super.key,
        required this.bookingId,
        required this.userId,
        required this.userName,
        required this.serviceName,
        required this.questions});

  @override
  State<_HelperRateUserSheet> createState() =>
      _HelperRateUserSheetState();
}

class _HelperRateUserSheetState extends State<_HelperRateUserSheet> {
  int _step = 0;
  int _stars = 0;
  bool _submitting = false;
  final Map<int, int> _answers = {};

  bool get _allAnswered =>
      _answers.length == widget.questions.length;

  String get _label {
    switch (_stars) {
      case 1: return 'Very Poor 😞';
      case 2: return 'Below Average 😕';
      case 3: return 'Average 🙂';
      case 4: return 'Good 😊';
      case 5: return 'Excellent! 🌟';
      default: return 'Tap to rate';
    }
  }

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _submitting = true);
    try {
      final helperId =
          FirebaseAuth.instance.currentUser?.uid ?? '';
      final reviewData = {
        'bookingId': widget.bookingId,
        'reviewerId': helperId,
        'revieweeId': widget.userId,
        'revieweeName': widget.userName,
        'role': 'helper',
        'starRating': _stars,
        'answers': _answers.map((k, v) => MapEntry(
            widget.questions[k].question,
            widget.questions[k].options[v])),
        'serviceName': widget.serviceName,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Save to reviews subcollection
      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(widget.bookingId)
          .collection('helper_to_user')
          .add(reviewData);

      // Mark booking as helper-rated + save helperRating
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'helperRating': _stars,
        'helperRatedAt': FieldValue.serverTimestamp(),
      });

      // Update user's avgRating via transaction
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(userRef);
        final prev =
            (snap.data()?['totalRatingSum'] as num?)?.toDouble() ??
                0.0;
        final count =
            (snap.data()?['reviewCount'] as int?) ?? 0;
        final newSum = prev + _stars;
        final newCount = count + 1;
        txn.set(
          userRef,
          {
            'totalRatingSum': newSum,
            'reviewCount': newCount,
            'avgRating': double.parse(
                (newSum / newCount).toStringAsFixed(1)),
            'lastReviewedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      // Auto-flag very low rated users
      if (_stars <= 2) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({
          'flagCount': FieldValue.increment(1),
          'lastFlaggedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      setState(() { _step = 2; _submitting = false; });
    } catch (e) {
      setState(() => _submitting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: _step == 2
            ? _DoneStep(
            key: const ValueKey('done'),
            userName: widget.userName,
            onClose: () => Navigator.pop(context))
            : _step == 1
            ? _StarStep(
          key: const ValueKey('star'),
          userName: widget.userName,
          stars: _stars,
          label: _label,
          submitting: _submitting,
          onStar: (s) => setState(() => _stars = s),
          onBack: () => setState(() => _step = 0),
          onSubmit: _submit,
        )
            : _QuestionStep(
          key: const ValueKey('q'),
          userName: widget.userName,
          questions: widget.questions,
          answers: _answers,
          allAnswered: _allAnswered,
          onAnswer: (q, a) =>
              setState(() => _answers[q] = a),
          onNext: () => setState(() => _step = 1),
        ),
      ),
    );
  }
}

class _QuestionStep extends StatelessWidget {
  final String userName;
  final List<_RQ> questions;
  final Map<int, int> answers;
  final bool allAnswered;
  final Function(int, int) onAnswer;
  final VoidCallback onNext;
  const _QuestionStep(
      {super.key,
        required this.userName,
        required this.questions,
        required this.answers,
        required this.allAnswered,
        required this.onAnswer,
        required this.onNext});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.70,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 42, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
          child: Row(children: [
            Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: const Color(0xFF0D6E6E).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.rate_review_rounded,
                    color: Color(0xFF0D6E6E), size: 24)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rate $userName',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937))),
                      const Text('How was this customer?',
                          style: TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ])),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                          '${answers.length}/${questions.length} answered',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0D6E6E),
                              fontWeight: FontWeight.w600)),
                      Text(
                          '${questions.isEmpty ? 0 : ((answers.length / questions.length) * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0D6E6E),
                              fontWeight: FontWeight.bold)),
                    ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: questions.isEmpty
                        ? 0
                        : answers.length / questions.length,
                    minHeight: 6,
                    backgroundColor:
                    const Color(0xFF0D6E6E).withOpacity(0.12),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF0D6E6E)),
                  ),
                ),
              ]),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView.builder(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            itemCount: questions.length,
            itemBuilder: (_, i) {
              final q = questions[i];
              final selected = answers[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: selected != null
                      ? const Color(0xFF0D6E6E).withOpacity(0.04)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: selected != null
                          ? const Color(0xFF0D6E6E).withOpacity(0.22)
                          : const Color(0xFFF0F0F5)),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                                color: const Color(0xFF0D6E6E)
                                    .withOpacity(0.12),
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D6E6E))))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(q.question,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1F2937),
                                    height: 1.4))),
                        if (selected != null)
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF0D6E6E), size: 18),
                      ]),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: q.options.asMap().entries.map((e) {
                          final isSel = selected == e.key;
                          return GestureDetector(
                            onTap: () => onAnswer(i, e.key),
                            child: AnimatedContainer(
                              duration:
                              const Duration(milliseconds: 140),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? const Color(0xFF0D6E6E)
                                    : Colors.white,
                                borderRadius:
                                BorderRadius.circular(24),
                                border: Border.all(
                                    color: isSel
                                        ? const Color(0xFF0D6E6E)
                                        : const Color(0xFFE5E7EB),
                                    width: isSel ? 1.5 : 1),
                                boxShadow: isSel
                                    ? [
                                  BoxShadow(
                                      color: const Color(0xFF0D6E6E)
                                          .withOpacity(0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ]
                                    : null,
                              ),
                              child: Text(e.value,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSel
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSel
                                          ? Colors.white
                                          : const Color(0xFF374151))),
                            ),
                          );
                        }).toList(),
                      ),
                    ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
          child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: allAnswered ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D6E6E),
                disabledBackgroundColor:
                const Color(0xFFE5E7EB),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(
                allAnswered
                    ? 'Next — Give Star Rating →'
                    : 'Answer all ${questions.length} questions',// CHANGE MADE
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: allAnswered
                        ? Colors.white
                        : const Color(0xFF9CA3AF)),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _StarStep extends StatelessWidget {
  final String userName, label;
  final int stars;
  final bool submitting;
  final ValueChanged<int> onStar;
  final VoidCallback onBack, onSubmit;
  const _StarStep(
      {super.key,
        required this.userName,
        required this.label,
        required this.stars,
        required this.submitting,
        required this.onStar,
        required this.onBack,
        required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 42, height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 24),
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1A3A6B), Color(0xFF0D6E6E)]),
              shape: BoxShape.circle),
          child: const Icon(Icons.person_rounded,
              color: Colors.white, size: 36),
        ),
        const SizedBox(height: 14),
        Text(userName,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 6),
        const Text('Overall rating for this customer',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < stars;
            return GestureDetector(
              onTap: () => onStar(i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: filled ? 48 : 44,
                  color: filled
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFD1D5DB),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(label,
              key: ValueKey(label),
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: stars > 0
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF9CA3AF))),
        ),
        const SizedBox(height: 36),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('← Back',
                  style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed:
              stars > 0 && !submitting ? onSubmit : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6E6E),
                  disabledBackgroundColor:
                  const Color(0xFFE5E7EB),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  padding:
                  const EdgeInsets.symmetric(vertical: 14)),
              child: submitting
                  ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Rating',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _DoneStep extends StatelessWidget {
  final String userName;
  final VoidCallback onClose;
  const _DoneStep(
      {super.key, required this.userName, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF0D9488)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color:
                    const Color(0xFF059669).withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8))
              ]),
          child: const Icon(Icons.check_rounded,
              color: Colors.white, size: 46),
        ),
        const SizedBox(height: 24),
        const Text('Rating Submitted!',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937))),
        const SizedBox(height: 10),
        Text(
          'Thank you for rating $userName.\nYour feedback keeps our platform trusted.',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF6B7280), height: 1.6),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            onPressed: onClose,
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1F2937),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            child: const Text('Done',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
          ),
        ),
      ]),
    );
  }
}

// ── Shared heading row ────────────────────────────────────────────────────────
class _RowHead extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RowHead({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: _purple.withOpacity(0.10),
          borderRadius: BorderRadius.circular(9)),
      child: Icon(icon, color: _purple, size: 16),
    ),
    const SizedBox(width: 10),
    Text(label,
        style: const TextStyle(
            color: _t1,
            fontSize: 15,
            fontWeight: FontWeight.w800)),
  ]);

}