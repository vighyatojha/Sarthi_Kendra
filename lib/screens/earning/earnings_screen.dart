// lib/screens/earning/earnings_screen.dart
// FIXES APPLIED:
//  ✅ All Firestore queries that combined .where() on one field + .where() on
//     another with isGreaterThanOrEqualTo previously required composite indexes.
//     Fixed by: fetching the broader set and filtering dates in-memory.
//  ✅ _weekStream and _monthStream no longer use range filters on Firestore —
//     they fetch all completed bookings and filter by date client-side.
//  ✅ Chart card query fixed similarly.
//  ✅ Today's header query fixed.
//  ✅ Design preserved with original purple palette.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
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

// Helper: check if a Timestamp falls within a date range
bool _inRange(Timestamp? ts, DateTime start, [DateTime? end]) {
  if (ts == null) return false;
  final dt = ts.toDate().toLocal();
  if (dt.isBefore(start)) return false;
  if (end != null && dt.isAfter(end)) return false;
  return true;
}

// ═══════════════════════════════════════════════════════════════════════════════
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  int _period = 0;

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().helper?.uid ?? '';

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _EarnHeader(uid: uid)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _BalanceCard(uid: uid),
                const SizedBox(height: 16),
                _PeriodToggle(
                  period: _period,
                  onChanged: (p) => setState(() => _period = p),
                ),
                const SizedBox(height: 16),
                _ChartCard(uid: uid, period: _period),
                const SizedBox(height: 16),
                _QuickStatsRow(uid: uid),
                const SizedBox(height: 24),
                _SecHead('Recent Transactions'),
                const SizedBox(height: 12),
                _TransactionList(uid: uid),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _EarnHeader extends StatelessWidget {
  final String uid;
  const _EarnHeader({required this.uid});

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Fetch ALL completed bookings for this helper, filter today in-memory.
    // Old query used .where('completedAt', isGreaterThanOrEqualTo: start)
    // combined with helperId filter → required a composite index.
    return StreamBuilder<QuerySnapshot>(
      stream: uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (ctx, snap) {
        final today     = DateTime.now();
        final todayStart = DateTime(today.year, today.month, today.day);

        double todayTotal = 0;
        int todayJobs = 0;
        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final m  = d.data() as Map;
            final ts = d['completedAt'] as Timestamp?;
            // ✅ Date filter in-memory
            if (_inRange(ts, todayStart)) {
              todayTotal += _sd(m['baseAmount']);
              todayJobs++;
            }
          }
        }

        return ClipPath(
          clipper: _EarnCurveClipper(),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 18,
              bottom: 48,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_indigo, _violet, _purple],
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Text('Earnings',
                    style: TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                if (snap.connectionState == ConnectionState.active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                          decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80), shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 10,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ),
              ]),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.22)),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("TODAY'S EARNINGS",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 10, fontWeight: FontWeight.w700,
                            letterSpacing: 1.1)),
                    const SizedBox(height: 6),
                    Text('₹ ${todayTotal.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.white,
                            fontSize: 34, fontWeight: FontWeight.w900, height: 1.1)),
                    const SizedBox(height: 4),
                    Text('$todayJobs job${todayJobs == 1 ? '' : 's'} completed',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  ])),
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle),
                    child: const Icon(Icons.trending_up_rounded,
                        color: Colors.white, size: 26),
                  ),
                ]),
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _EarnCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 32)
      ..quadraticBezierTo(
          size.width / 2, size.height + 26, size.width, size.height - 32)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> old) => false;
}

// ── Balance card ──────────────────────────────────────────────────────────────
// ── Balance card — single shared stream for all 3 mini-stats ─────────────────
class _BalanceCard extends StatefulWidget {
  final String uid;
  const _BalanceCard({required this.uid});
  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  late final Stream<QuerySnapshot> _sharedCompletedStream;

  @override
  void initState() {
    super.initState();
    _sharedCompletedStream = widget.uid.isEmpty
        ? const Stream.empty()
        : FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'completed')
        .snapshots();
  }

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
        final d       = snap.data?.data() as Map<String, dynamic>? ?? {};
        final balance = _sd(d['totalBalance'] ?? d['walletBalance'] ?? 0);
        final pending = _sd(d['pendingBalance'] ?? 0);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(
                color: _purple.withOpacity(0.08),
                blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TOTAL BALANCE',
                    style: TextStyle(color: _t3, fontSize: 10,
                        fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                const SizedBox(height: 6),
                Text('₹ ${NumberFormat('#,##,###.##').format(balance)}',
                    style: const TextStyle(color: _t1, fontSize: 28,
                        fontWeight: FontWeight.w900)),
                // NOTE: totalBalance is set by admin/backend only.
                // It requires a Cloud Function or admin panel update
                // when a withdrawal is processed. It stays 0.0 until then.
                if (pending > 0) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 12, color: _amber),
                    const SizedBox(width: 4),
                    Text('₹${pending.toStringAsFixed(0)} pending clearance',
                        style: const TextStyle(color: _amber, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ])),
              GestureDetector(
                onTap: () => _showWithdrawSheet(context, balance),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_violet, _purple]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(
                        color: _purple.withOpacity(0.3),
                        blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: const Row(children: [
                    Icon(Icons.account_balance_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 6),
                    Text('Withdraw',
                        style: TextStyle(color: Colors.white, fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Container(height: 1, color: _border),
            const SizedBox(height: 16),
            // All 3 mini-stats share ONE StreamBuilder — no duplicate listeners
            StreamBuilder<QuerySnapshot>(
              stream: _sharedCompletedStream,
              builder: (ctx2, completedSnap) {
                return Row(children: [
                  _MiniStat(
                    label:    'This Month',
                    snapshot: completedSnap,
                    isWeek:   false,
                    isCount:  false,
                  ),
                  _vDivider(),
                  _MiniStat(
                    label:    'This Week',
                    snapshot: completedSnap,
                    isWeek:   true,
                    isCount:  false,
                  ),
                  _vDivider(),
                  _MiniStat(
                    label:    'Total Jobs',
                    snapshot: completedSnap,
                    isWeek:   false,
                    isCount:  true,
                  ),
                ]);
              },
            ),
          ]),
        );
      },
    );
  }

  Widget _vDivider() => Container(
      width: 1, height: 36, color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  void _showWithdrawSheet(BuildContext context, double balance) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(balance: balance, ctrl: ctrl),
    );
  }
}

// ── Mini stat — accepts snapshot directly, no own stream ─────────────────────
class _MiniStat extends StatelessWidget {
  final String label;
  final AsyncSnapshot<QuerySnapshot> snapshot;
  final bool isCount;
  final bool isWeek;

  const _MiniStat({
    required this.label,
    required this.snapshot,
    this.isCount = false,
    this.isWeek  = false,
  });

  @override
  Widget build(BuildContext context) {
    final now        = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final weekStart  = now.subtract(Duration(days: now.weekday - 1));
    final weekDay0   = DateTime(weekStart.year, weekStart.month, weekStart.day);

    double total = 0;
    int    count = 0;

    if (snapshot.hasData) {
      for (final d in snapshot.data!.docs) {
        final m  = d.data() as Map;
        final ts = m['completedAt'] as Timestamp?;
        final inRange = isWeek
            ? _inRange(ts, weekDay0)
            : isCount ? true : _inRange(ts, monthStart);
        if (inRange) {
          count++;
          total += _sd(m['baseAmount']);
        }
      }
    }

    return Expanded(
      child: Column(children: [
        Text(
          isCount
              ? '$count'
              : '₹${NumberFormat('#,###').format(total)}',
          style: const TextStyle(color: _purple, fontSize: 15,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(label, style: const TextStyle(color: _t3, fontSize: 10)),
      ]),
    );
  }
}

  Widget _vDivider() => Container(
      width: 1, height: 36, color: _border,
      margin: const EdgeInsets.symmetric(horizontal: 4));

  // ✅ FIX: Single stream — all completed bookings. Filter by date in-memory.
  Stream<QuerySnapshot> _completedStream(String uid) =>
      FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots();

  void _showWithdrawSheet(BuildContext context, double balance) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WithdrawSheet(balance: balance, ctrl: ctrl),
    );
  }




// ── Period toggle ─────────────────────────────────────────────────────────────
class _PeriodToggle extends StatelessWidget {
  final int period;
  final void Function(int) onChanged;
  const _PeriodToggle({required this.period, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: ['Weekly', 'Monthly'].asMap().entries.map((e) {
        final sel = period == e.key;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: sel ? _purple : Colors.transparent,
                borderRadius: BorderRadius.circular(11),
                boxShadow: sel
                    ? [BoxShadow(color: _purple.withOpacity(0.25),
                    blurRadius: 8, offset: const Offset(0, 3))]
                    : null,
              ),
              child: Center(
                child: Text(e.value,
                    style: TextStyle(
                      color: sel ? Colors.white : _t3,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    )),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );
}

// ── Chart card ────────────────────────────────────────────────────────────────
class _ChartCard extends StatelessWidget {
  final String uid;
  final int period;
  const _ChartCard({required this.uid, required this.period});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();
    final int barCount;
    final List<String> labels;
    final DateTime rangeStartDt;

    if (period == 0) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1));
      rangeStartDt = DateTime(weekStart.year, weekStart.month, weekStart.day);
      barCount = 7;
      labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    } else {
      rangeStartDt = DateTime(now.year, now.month, 1);
      barCount = 4;
      labels = ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
    }

    // ✅ FIX: Query only by helperId + status. Date filter done in-memory.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .snapshots(),
      builder: (ctx, snap) {
        final bars = List<double>.filled(barCount, 0.0);

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final d  = doc.data() as Map<String, dynamic>;
            final ts = (d['completedAt'] as Timestamp?)?.toDate()?.toLocal();
            if (ts == null || ts.isBefore(rangeStartDt)) continue;
            final amt = _sd(d['baseAmount']);

            if (period == 0) {
              final idx = ts.weekday - 1;
              if (idx >= 0 && idx < 7) bars[idx] += amt;
            } else {
              final idx = ((ts.day - 1) / 7).floor().clamp(0, 3);
              bars[idx] += amt;
            }
          }
        }

        final total  = bars.fold(0.0, (a, b) => a + b);
        final maxVal = bars.fold(0.0, (a, b) => a > b ? a : b);
        final todayBar = period == 0
            ? now.weekday - 1
            : ((now.day - 1) / 7).floor().clamp(0, 3);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12, offset: const Offset(0, 3))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(period == 0 ? 'This Week' : 'This Month',
                    style: const TextStyle(color: _t2, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('₹ ${NumberFormat('#,##,###').format(total)}',
                    style: const TextStyle(color: _t1, fontSize: 22,
                        fontWeight: FontWeight.w900)),
              ]),
              const Spacer(),
              if (snap.connectionState == ConnectionState.active)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                        decoration: const BoxDecoration(
                            color: _green, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('LIVE',
                        style: TextStyle(color: _green, fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
            ]),
            const SizedBox(height: 28),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(barCount, (i) {
                  final val   = bars[i];
                  final barH  = maxVal > 0 ? (val / maxVal) * 90 : 0.0;
                  final isNow = i == todayBar;
                  final hasAmt = val > 0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasAmt) ...[
                            Text('₹${val.toInt()}',
                                style: const TextStyle(color: _purple,
                                    fontSize: 7, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                          ],
                          AnimatedContainer(
                            duration: Duration(milliseconds: 400 + i * 60),
                            curve: Curves.easeOut,
                            height: barH.clamp(4.0, 90.0),
                            decoration: BoxDecoration(
                              gradient: (hasAmt || isNow)
                                  ? const LinearGradient(
                                colors: [_purple, Color(0xFF9D6FE8)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ) : null,
                              color: (!hasAmt && !isNow)
                                  ? const Color(0xFFEDE9FE) : null,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: hasAmt
                                  ? [BoxShadow(color: _purple.withOpacity(0.22),
                                  blurRadius: 6, offset: const Offset(0, 3))]
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(labels[i],
                              style: TextStyle(
                                color: isNow ? _purple : _t3,
                                fontSize: 10,
                                fontWeight: isNow
                                    ? FontWeight.w800 : FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ]),
        );
      },
    );
  }
}

// ── Quick stats ───────────────────────────────────────────────────────────────
class _QuickStatsRow extends StatelessWidget {
  final String uid;
  const _QuickStatsRow({required this.uid});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('helpers').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final d       = snap.data?.data() as Map<String, dynamic>? ?? {};
        final rating  = _sd(d['rating']);
        final reviews = (d['totalReviews'] as num?)?.toInt() ?? 0;
        final done    = (d['completedJobs'] as num?)?.toInt()
            ?? (d['totalJobs'] as num?)?.toInt() ?? 0;

        return Row(children: [
          _StatTile(icon: Icons.star_rounded, iconColor: _amber,
              bgColor: _amber.withOpacity(0.10), label: 'Avg Rating',
              value: rating == 0 ? '—' : rating.toStringAsFixed(1),
              sub: '$reviews reviews'),
          const SizedBox(width: 12),
          _StatTile(icon: Icons.check_circle_rounded, iconColor: _green,
              bgColor: _green.withOpacity(0.10), label: 'Jobs Done',
              value: '$done', sub: 'all time'),
        ]);
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, bgColor;
  final String label, value, sub;
  const _StatTile({required this.icon, required this.iconColor,
    required this.bgColor, required this.label,
    required this.value, required this.sub});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: bgColor,
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: _t3, fontSize: 10,
              fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: _t1, fontSize: 20,
              fontWeight: FontWeight.w800)),
          Text(sub, style: const TextStyle(color: _t3, fontSize: 10)),
        ]),
      ]),
    ),
  );
}

// ── Transaction list ──────────────────────────────────────────────────────────
class _TransactionList extends StatelessWidget {
  final String uid;
  const _TransactionList({required this.uid});

  static (IconData, Color) _svcIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('plumb'))  return (Icons.plumbing_rounded, Color(0xFF0EA5E9));
    if (n.contains('electr')) return (Icons.electrical_services_rounded, _amber);
    if (n.contains('clean'))  return (Icons.cleaning_services_rounded, Color(0xFF10B981));
    if (n.contains('paint'))  return (Icons.format_paint_rounded, _red);
    if (n.contains('ac') || n.contains('air'))
      return (Icons.ac_unit_rounded, Color(0xFF06B6D4));
    return (Icons.home_repair_service_rounded, _purple);
  }

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _emptyState();

    // ✅ FIX: No .orderBy() → sort in-memory after fetch
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('status', isEqualTo: 'completed')
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _shimmer();

        var docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyState();

        // ✅ Sort descending by completedAt in-memory
        docs = List.from(docs)..sort((a, b) {
          final ta = ((a.data() as Map)['completedAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ?? 0;
          final tb = ((b.data() as Map)['completedAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });

        // Take top 12
        if (docs.length > 12) docs = docs.sublist(0, 12);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: docs.asMap().entries.map((e) {
              final doc    = e.value;
              final d      = doc.data() as Map<String, dynamic>;
              final svc    = d['serviceName'] as String? ?? 'Service';
              final amt    = _sd(d['baseAmount']);
              final ts     = (d['completedAt'] as Timestamp?)?.toDate()?.toLocal();
              final pay    = d['paymentMethod'] as String? ?? 'Cash';
              final isCash = pay == 'Cash';
              final isLast = e.key == docs.length - 1;
              final (icon, color) = _svcIcon(svc);

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(svc, style: const TextStyle(color: _t1, fontSize: 13,
                          fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Row(children: [
                        if (ts != null)
                          Text(DateFormat('d MMM, h:mm a').format(ts),
                              style: const TextStyle(color: _t3, fontSize: 11)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isCash ? _green : _purple).withOpacity(0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(isCash ? 'Cash' : 'UPI',
                              style: TextStyle(
                                  color: isCash ? _green : _purple,
                                  fontSize: 9, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('+₹${amt.toStringAsFixed(0)}',
                          style: const TextStyle(color: _green, fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const Text('COMPLETED',
                          style: TextStyle(color: _t3, fontSize: 9,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ),
                if (!isLast) Divider(height: 1,
                    color: const Color(0xFFF1F0FF), indent: 16, endIndent: 16),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border)),
    child: Column(children: [
      Container(
        width: 64, height: 64,
        decoration: BoxDecoration(
            color: _purple.withOpacity(0.10), shape: BoxShape.circle),
        child: const Icon(Icons.receipt_long_rounded, color: _purple, size: 28),
      ),
      const SizedBox(height: 14),
      const Text('No transactions yet',
          style: TextStyle(color: _t1, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('Completed bookings will appear here',
          style: TextStyle(color: _t2, fontSize: 12)),
    ]),
  );

  Widget _shimmer() => Column(
    children: List.generate(3, (_) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 72,
      decoration: BoxDecoration(
          color: const Color(0xFFF1F0FF),
          borderRadius: BorderRadius.circular(14)),
    )),
  );
}

// ── Section heading ───────────────────────────────────────────────────────────
class _SecHead extends StatelessWidget {
  final String title;
  const _SecHead(this.title);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 4, height: 18,
        decoration: BoxDecoration(color: _purple,
            borderRadius: BorderRadius.circular(4))),
    const SizedBox(width: 10),
    Text(title, style: const TextStyle(color: _t1, fontSize: 17,
        fontWeight: FontWeight.w800)),
  ]);
}

// ── Withdraw bottom sheet ─────────────────────────────────────────────────────
class _WithdrawSheet extends StatelessWidget {
  final double balance;
  final TextEditingController ctrl;
  const _WithdrawSheet({required this.balance, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final safeB = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 0, 24, safeB + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFDEE2E6),
                  borderRadius: BorderRadius.circular(2))),
        ),
        const Text('Withdraw Earnings',
            style: TextStyle(color: _t1, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Available: ₹${NumberFormat('#,##,###.##').format(balance)}',
            style: const TextStyle(color: _t2, fontSize: 13)),
        const SizedBox(height: 24),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: _t1, fontSize: 22, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            prefixText: '₹ ',
            prefixStyle: const TextStyle(color: _purple, fontSize: 22,
                fontWeight: FontWeight.w800),
            hintText: '0',
            hintStyle: const TextStyle(color: _t3),
            filled: true,
            fillColor: const Color(0xFFF8F7FF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _purple, width: 2)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity, height: 54,
          child: ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim()) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Enter a valid amount'),
                  backgroundColor: _red,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              if (amount > balance) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Amount exceeds balance (₹${balance.toStringAsFixed(0)})'),
                  backgroundColor: _red,
                  behavior: SnackBarBehavior.floating,
                ));
                return;
              }
              Navigator.pop(context);
              // TODO: Call withdrawal API
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple, foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Request Withdrawal',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}