// lib/screens/jobs/job_history_screen.dart
// FIXES APPLIED:
//  ✅ Removed .orderBy('createdAt') from Firestore query → sorted in-memory
//     This eliminates the "requires a composite index" error entirely.
//  ✅ All status filters work client-side (no extra indexes needed)
//  ✅ keepAlive prevents tab data from disappearing
//  ✅ Redesigned with curved card / teal-dark header matching Image 3 aesthetic

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/auth_provider.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const _kTeal1   = Color(0xFF0D3D56);   // deep teal (header top)
const _kTeal2   = Color(0xFF0A5C78);   // mid teal
const _kTeal3   = Color(0xFF0891B2);   // bright teal accent
const _kPurple  = Color(0xFF5B21D4);
const _kBg      = Color(0xFFF0F9FF);   // ice-blue bg
const _kWhite   = Colors.white;
const _kT1      = Color(0xFF0F172A);
const _kT2      = Color(0xFF475569);
const _kT3      = Color(0xFF94A3B8);
const _kBorder  = Color(0xFFE0F2FE);
const _kGreen   = Color(0xFF059669);
const _kAmber   = Color(0xFFD97706);
const _kRed     = Color(0xFFDC2626);

enum _Filter { all, completed, upcoming, cancelled }

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});
  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;
  final _filters = const [
    (_Filter.all,       'All'),
    (_Filter.completed, 'Completed'),
    (_Filter.upcoming,  'Upcoming'),
    (_Filter.cancelled, 'Cancelled'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _filters.length, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.select<AuthProvider, String>(
            (a) => a.helper?.uid ?? '');

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        _buildCurvedHeader(context, uid),
        const SizedBox(height: 12),
        _buildSlidingTabBar(),
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: _filters.map((f) =>
              _FilteredList(uid: uid, filter: f.$1, key: ValueKey(f.$1))
          ).toList(),
        )),
      ]),
    );
  }

  // ── Curved header — inspired by Image 3 (teal gradient + shield/icon) ───────
  Widget _buildCurvedHeader(BuildContext context, String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: uid.isEmpty
          ? const Stream.empty()
          : FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
      // ✅ NO .orderBy() here — sorted in memory below
          .snapshots(),
      builder: (ctx, snap) {
        final docs   = snap.data?.docs ?? [];
        int total     = docs.length;
        int completed = docs.where((d) =>
        (d.data() as Map)['status'] == 'completed').length;
        int upcoming  = docs.where((d) {
          final m  = d.data() as Map;
          final ts = (m['scheduledAt'] as Timestamp?)?.toDate();
          return m['status'] == 'accepted' &&
              ts != null && ts.isAfter(DateTime.now());
        }).length;

        return ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 14,
              bottom: 52,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kTeal1, _kTeal2, Color(0xFF0E7490)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back + title row
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text('Job History',
                      style: TextStyle(color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.w800)),
                  const Spacer(),
                  // Shield icon like Image 3
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.work_history_rounded,
                        color: Colors.white, size: 20),
                  ),
                ]),
                const SizedBox(height: 22),
                // Stats row inside header card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.13),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.20)),
                  ),
                  child: Row(children: [
                    _HeaderStat('Total', '$total', Icons.list_alt_rounded),
                    _vLine(),
                    _HeaderStat('Done', '$completed', Icons.check_circle_outline_rounded),
                    _vLine(),
                    _HeaderStat('Upcoming', '$upcoming', Icons.event_available_rounded),
                  ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _vLine() => Container(
      width: 1, height: 36,
      color: Colors.white.withOpacity(0.25),
      margin: const EdgeInsets.symmetric(horizontal: 8));

  Widget _buildSlidingTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
            color: _kTeal3.withOpacity(0.10),
            blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
              colors: [_kTeal1, _kTeal3],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(11),
          boxShadow: [BoxShadow(
              color: _kTeal3.withOpacity(0.30),
              blurRadius: 8, offset: const Offset(0, 3))],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        labelColor: Colors.white,
        unselectedLabelColor: _kT2,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: _filters.map((f) => Tab(text: f.$2)).toList(),
      ),
    );
  }
}

// ── Curved bottom clipper ─────────────────────────────────────────────────────
class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path()
      ..lineTo(0, size.height - 30)
      ..quadraticBezierTo(
          size.width / 2, size.height + 22, size.width, size.height - 30)
      ..lineTo(size.width, 0)
      ..close();
    return p;
  }
  @override bool shouldReclip(CustomClipper<Path> old) => false;
}

// ── Header stat widget ────────────────────────────────────────────────────────
class _HeaderStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _HeaderStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: Colors.white.withOpacity(0.80), size: 18),
      const SizedBox(height: 6),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          color: Colors.white.withOpacity(0.65), fontSize: 10,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Per-tab filtered list ─────────────────────────────────────────────────────
class _FilteredList extends StatefulWidget {
  final String uid;
  final _Filter filter;
  const _FilteredList({required this.uid, required this.filter, super.key});
  @override
  State<_FilteredList> createState() => _FilteredListState();
}

class _FilteredListState extends State<_FilteredList>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.uid.isEmpty) return _empty();

    // ✅ KEY FIX: Removed .orderBy('createdAt') — this was causing the
    // "requires a composite index" error. We sort in-memory instead.
    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .limit(150);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _kTeal3));
        }
        if (snap.hasError) {
          return Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error: ${snap.error}',
                style: const TextStyle(color: _kRed, fontSize: 13),
                textAlign: TextAlign.center),
          ));
        }

        var docs = snap.data?.docs ?? [];
        final now = DateTime.now();

        // ── In-memory filter ──────────────────────────────────────────────────
        switch (widget.filter) {
          case _Filter.completed:
            docs = docs.where((doc) =>
            (doc.data() as Map)['status'] == 'completed').toList();
          case _Filter.cancelled:
            docs = docs.where((doc) =>
            (doc.data() as Map)['status'] == 'cancelled').toList();
          case _Filter.upcoming:
            docs = docs.where((doc) {
              final d  = doc.data() as Map<String, dynamic>;
              final ts = (d['scheduledAt'] as Timestamp?)?.toDate();
              return d['status'] == 'accepted' &&
                  ts != null && ts.isAfter(now);
            }).toList();
          case _Filter.all:
          // Exclude pending/booked — these are not history items yet
            docs = docs.where((doc) {
              final s = (doc.data() as Map)['status'] as String? ?? '';
              return s != 'booked' && s != 'pending';
            }).toList();
            break;
        }

        // ── In-memory sort by createdAt descending (replaces .orderBy) ───────
        docs.sort((a, b) {
          final ta = ((a.data() as Map)['createdAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ?? 0;
          final tb = ((b.data() as Map)['createdAt'] as Timestamp?)
              ?.millisecondsSinceEpoch ?? 0;
          return tb.compareTo(ta);
        });

        if (docs.isEmpty) return _empty();

        // ── Group by month ────────────────────────────────────────────────────
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in docs) {
          final d  = doc.data() as Map<String, dynamic>;
          final ts = ((d['scheduledAt'] ?? d['createdAt']) as Timestamp?)
              ?.toDate();
          final key = ts != null
              ? DateFormat('MMMM yyyy').format(ts) : 'Earlier';
          grouped.putIfAbsent(key, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _SummaryBar(docs: docs),
            const SizedBox(height: 16),
            ...grouped.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  Container(width: 3, height: 14,
                      decoration: BoxDecoration(
                          color: _kTeal3,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(entry.key,
                      style: const TextStyle(
                          color: _kT1, fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5)),
                ]),
              ),
              ...entry.value.map((doc) =>
                  _JobCard(key: ValueKey(doc.id), doc: doc)),
              const SizedBox(height: 8),
            ]),
          ],
        );
      },
    );
  }

  Widget _empty() => Center(child: Column(
      mainAxisSize: MainAxisSize.min, children: [
    Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: _kTeal3.withOpacity(0.10), shape: BoxShape.circle),
        child: const Icon(Icons.work_history_rounded,
            color: _kTeal3, size: 34)),
    const SizedBox(height: 16),
    const Text('No jobs found',
        style: TextStyle(color: _kT1, fontSize: 16,
            fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    const Text('Your jobs will appear here',
        style: TextStyle(color: _kT2, fontSize: 13)),
  ]));
}

// ── Summary bar ───────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  const _SummaryBar({required this.docs});

  @override
  Widget build(BuildContext context) {
    int completed = 0; double earned = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      if (d['status'] == 'completed') {
        completed++;
        earned += (d['baseAmount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    final historyTotal = docs.where((d) {
      final s = (d.data() as Map)['status'] as String? ?? '';
      return s != 'booked' && s != 'pending';
    }).length;
    return Row(children: [
      Expanded(child: _Chip('Total Jobs', '$historyTotal', _kTeal3)),
      const SizedBox(width: 8),
      Expanded(child: _Chip('Completed',  '$completed',    _kGreen)),
      const SizedBox(width: 8),
      Expanded(child: _Chip('Earned',
          '₹${earned.toStringAsFixed(0)}',                 _kAmber)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Chip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.20)),
      boxShadow: [BoxShadow(
          color: color.withOpacity(0.07),
          blurRadius: 8, offset: const Offset(0, 3))],
    ),
    child: Column(children: [
      Text(value, style: TextStyle(
          color: color, fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(color: _kT3, fontSize: 10)),
    ]),
  );
}

// ── Job card ──────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  const _JobCard({super.key, required this.doc});

  (Color, IconData, String) _statusInfo(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return (_kGreen,  Icons.check_circle_rounded,    'DONE');
      case 'ongoing':   return (_kTeal3,  Icons.play_circle_rounded,     'IN PROGRESS');
      case 'accepted':  return (_kPurple, Icons.event_available_rounded, 'UPCOMING');
      case 'booked':    return (_kAmber,  Icons.pending_rounded,         'PENDING');
      case 'pending':   return (_kAmber,  Icons.pending_rounded,         'PENDING');
      case 'cancelled': return (_kRed,    Icons.cancel_rounded,          'CANCELLED');
      default:          return (_kAmber,  Icons.help_outline_rounded,     s.toUpperCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;

    final status      = (d['status']       as String?) ?? 'pending';
    final svc         = (d['serviceName']  as String?) ?? 'Service';
    final category    = (d['categoryName'] as String?) ?? '';
    final bookingCode = (d['bookingCode']  as String?)
        ?? doc.id.substring(0, 8).toUpperCase();
    final amount      = (d['baseAmount']   as num?)?.toDouble()
        ?? (d['totalAmount'] as num?)?.toDouble() ?? 0.0;

    final scheduledAt = (d['scheduledAt'] as Timestamp?)?.toDate();
    final createdAt   = (d['createdAt']   as Timestamp?)?.toDate();
    final displayTime = scheduledAt ?? createdAt;

    final (color, icon, label) = _statusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(svc, style: const TextStyle(
              color: _kT1, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          if (category.isNotEmpty)
            Text(category, style: const TextStyle(color: _kT2, fontSize: 12)),
          const SizedBox(height: 2),
          Text('#$bookingCode',
              style: const TextStyle(color: _kT3, fontSize: 11)),
          if (displayTime != null)
            Text(DateFormat('d MMM yyyy, h:mm a').format(displayTime.toLocal()),
                style: const TextStyle(color: _kT3, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            status == 'completed'
                ? '+₹${amount.toStringAsFixed(0)}'
                : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                color: status == 'completed' ? _kGreen : _kT1,
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
            child: Text(label, style: TextStyle(
                color: color, fontSize: 10,
                fontWeight: FontWeight.w700, letterSpacing: 0.3)),
          ),
        ]),
      ]),
    );
  }
}