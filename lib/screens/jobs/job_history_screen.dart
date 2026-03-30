// lib/screens/jobs/job_history_screen.dart
//
// FIX 9 APPLIED:
//  • _Filter.active renamed → _Filter.upcoming
//  • "Upcoming" tab = status=='accepted' AND scheduledAt > now (in-memory)
//  • Grouping by scheduledAt Timestamp (formatted 'MMMM yyyy'),
//    falls back to createdAt only if scheduledAt is null
//  • Summary "Earned" chip uses baseAmount only — platform fee never shown to helper
//  • _JobCard._statusInfo: 'active' replaced with 'accepted' + 'ongoing'

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

// FIX 9 — "active" tab renamed to "upcoming"
// Unified statuses: pending | accepted | ongoing | completed | cancelled
enum _Filter { all, completed, upcoming, cancelled }

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});
  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid    = context.watch<AuthProvider>().helper?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(children: [
        _buildHeader(context, isDark),
        _buildFilterBar(isDark),
        Expanded(child: _buildList(uid, isDark)),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 8, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF3B0764), Color(0xFF5B21B6), AppColors.brandPurple],
        ),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        const Expanded(
          child: Text('Job History',
              style: TextStyle(color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    // FIX 9 — "Active" tab replaced with "Upcoming"
    final filters = [
      (_Filter.all,       'All'),
      (_Filter.completed, 'Completed'),
      (_Filter.upcoming,  'Upcoming'),   // was 'Active'
      (_Filter.cancelled, 'Cancelled'),
    ];
    return Container(
      height: 46,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f.$1;
          return Expanded(child: GestureDetector(
            onTap: () => setState(() => _filter = f.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color:        selected ? AppColors.brandPurple : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(child: Text(f.$2,
                  style: TextStyle(
                    color:      selected ? Colors.white
                        : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                    fontSize:   12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ))),
            ),
          ));
        }).toList(),
      ),
    );
  }

  Widget _buildList(String uid, bool isDark) {
    if (uid.isEmpty) return _empty(isDark);

    // Base query: helperId + orderBy createdAt to avoid composite index.
    // All status + date filtering is done in-memory below.
    // REQUIRES INDEX: helperId ASC (single field — already exists by default)
    final query = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100);

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppColors.brandPurple));
        }

        var docs = snap.data?.docs ?? [];
        final now = DateTime.now();

        // FIX 9 — in-memory filter based on selected tab
        switch (_filter) {
          case _Filter.completed:
            docs = docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return (d['status'] as String? ?? '') == 'completed';
            }).toList();
          case _Filter.cancelled:
            docs = docs.where((doc) {
              final d = doc.data() as Map<String, dynamic>;
              return (d['status'] as String? ?? '') == 'cancelled';
            }).toList();
          case _Filter.upcoming:
          // Upcoming = status=='accepted' AND scheduledAt is in the future
            docs = docs.where((doc) {
              final d           = doc.data() as Map<String, dynamic>;
              final status      = d['status'] as String? ?? '';
              final scheduledAt = (d['scheduledAt'] as Timestamp?)?.toDate();
              return status == 'accepted' &&
                  scheduledAt != null &&
                  scheduledAt.isAfter(now);
            }).toList();
          case _Filter.all:
            break; // no filter
        }

        if (docs.isEmpty) return _empty(isDark);

        // FIX 9 — group by scheduledAt Timestamp (formatted 'MMMM yyyy').
        // Falls back to createdAt only when scheduledAt is null.
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in docs) {
          final d  = doc.data() as Map<String, dynamic>;
          // Use scheduledAt (when service happens) not createdAt (when customer booked)
          final scheduledTs = (d['scheduledAt'] as Timestamp?)?.toDate();
          final fallbackTs  = (d['createdAt']   as Timestamp?)?.toDate();
          final ts = scheduledTs ?? fallbackTs;
          final key = ts != null
              ? DateFormat('MMMM yyyy').format(ts)
              : 'Earlier';
          grouped.putIfAbsent(key, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _SummaryBar(docs: docs, isDark: isDark),
            const SizedBox(height: 16),
            ...grouped.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(entry.key,
                    style: TextStyle(
                        color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                        fontSize: 11, fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
              ...entry.value.map((doc) =>
                  _JobCard(key: ValueKey(doc.id), doc: doc, isDark: isDark)),
              const SizedBox(height: 8),
            ]),
          ],
        );
      },
    );
  }

  Widget _empty(bool isDark) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
              color:  AppColors.brandPurple.withOpacity(0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.work_history_rounded,
              color: AppColors.brandPurple, size: 34)),
      const SizedBox(height: 16),
      Text('No jobs found',
          style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Your jobs will appear here',
          style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13)),
    ]));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SummaryBar extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool isDark;
  const _SummaryBar({required this.docs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    int completed = 0; double earned = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final s = d['status'] as String? ?? '';
      if (s == 'completed') {
        completed++;
        // FIX 9 — Earned uses baseAmount ONLY. Platform fee is app revenue,
        // never shown to the helper.
        earned += (d['baseAmount'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return Row(children: [
      Expanded(child: _SummaryChip(
          label: 'Total Jobs', value: '${docs.length}',
          color: AppColors.brandPurple, isDark: isDark)),
      const SizedBox(width: 8),
      Expanded(child: _SummaryChip(
          label: 'Completed', value: '$completed',
          color: AppColors.success, isDark: isDark)),
      const SizedBox(width: 8),
      Expanded(child: _SummaryChip(
          label: 'Earned', value: '₹${earned.toStringAsFixed(0)}',
          color: AppColors.warning, isDark: isDark)),
    ]);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  final bool   isDark;
  const _SummaryChip({
    required this.label, required this.value,
    required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value, style: TextStyle(
            color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(label, style: TextStyle(
            color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
            fontSize: 11)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB CARD
// ─────────────────────────────────────────────────────────────────────────────
class _JobCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isDark;
  const _JobCard({super.key, required this.doc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final d = doc.data() as Map<String, dynamic>;

    final status      = (d['status']       as String?) ?? 'pending';
    final svc         = (d['serviceName']  as String?) ?? 'Service';
    final category    = (d['categoryName'] as String?) ?? '';
    final bookingCode = (d['bookingCode']  as String?)
        ?? doc.id.substring(0, 8).toUpperCase();
    final helperName  = (d['helperName']   as String?) ?? '';

    // FIX 9 — baseAmount = helper's payment. Platform fee never shown.
    final amount = (d['baseAmount']  as num?)?.toDouble()
        ?? (d['totalAmount'] as num?)?.toDouble()
        ?? 0.0;

    // FIX 9 — display scheduledAt (service date), fallback to createdAt
    final scheduledAt = (d['scheduledAt'] as Timestamp?)?.toDate();
    final createdAt   = (d['createdAt']   as Timestamp?)?.toDate();
    final displayTime = scheduledAt ?? createdAt;

    final (color, icon, label) = _statusInfo(status);

    return Container(
      key:    ValueKey(doc.id),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          // Service icon
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(svc, style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            if (category.isNotEmpty || helperName.isNotEmpty)
              Text(
                helperName.isNotEmpty ? helperName : category,
                style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 12),
              ),
            const SizedBox(height: 2),
            Text('#$bookingCode',
                style: TextStyle(
                    color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                    fontSize: 11)),
            // FIX 9 — show scheduledAt (service date) not createdAt
            if (displayTime != null)
              Text(
                  DateFormat('d MMM yyyy, h:mm a').format(
                      displayTime.toLocal()),
                  style: TextStyle(
                      color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                      fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              status == 'completed'
                  ? '+₹${amount.toStringAsFixed(0)}'
                  : '₹${amount.toStringAsFixed(0)}',
              style: TextStyle(
                  color:      status == 'completed' ? AppColors.success
                      : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                  fontSize:   14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color:        color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
            ),
          ]),
        ]),
      ),
    );
  }

  // FIX 9 — unified status set: pending/accepted/ongoing/completed/cancelled
  // 'active' removed; 'accepted' + 'ongoing' added
  (Color, IconData, String) _statusInfo(String s) {
    switch (s.toLowerCase()) {
      case 'completed': return (AppColors.success,       Icons.check_circle_rounded,       'DONE');
      case 'ongoing':   return (AppColors.onlineGreen,   Icons.play_circle_rounded,        'IN PROGRESS');
      case 'accepted':  return (AppColors.brandPurple,   Icons.event_available_rounded,    'UPCOMING');
      case 'pending':   return (AppColors.warning,       Icons.pending_rounded,             'PENDING');
      case 'cancelled': return (AppColors.danger,        Icons.cancel_rounded,              'CANCELLED');
      default:          return (AppColors.warning,       Icons.help_outline_rounded,        s.toUpperCase());
    }
  }
}