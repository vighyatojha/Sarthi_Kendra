// lib/screens/jobs/job_history_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

enum _Filter { all, completed, accepted, declined }

class JobHistoryScreen extends StatefulWidget {
  const JobHistoryScreen({super.key});
  @override
  State<JobHistoryScreen> createState() => _JobHistoryScreenState();
}

class _JobHistoryScreenState extends State<JobHistoryScreen> {
  _Filter _filter = _Filter.all;

  String? get _statusFilter {
    switch (_filter) {
      case _Filter.completed: return 'completed';
      case _Filter.accepted:  return 'accepted';
      case _Filter.declined:  return 'declined';
      case _Filter.all:       return null;
    }
  }

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
    final filters = [
      (_Filter.all,       'All'),
      (_Filter.completed, 'Completed'),
      (_Filter.accepted,  'Accepted'),
      (_Filter.declined,  'Declined'),
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

    Query query = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50);

    if (_statusFilter != null) {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(
              color: AppColors.brandPurple));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _empty(isDark);

        // Group by month
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in docs) {
          final d  = doc.data() as Map<String, dynamic>;
          final ts = (d['createdAt'] as Timestamp?)?.toDate();
          final key = ts != null
              ? DateFormat('MMMM yyyy').format(ts)
              : 'Earlier';
          grouped.putIfAbsent(key, () => []).add(doc);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // Summary chips
            _SummaryBar(docs: docs, isDark: isDark),
            const SizedBox(height: 16),
            // Grouped list
            ...grouped.entries.expand((entry) => [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(entry.key,
                    style: TextStyle(
                        color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                        fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ),
              ...entry.value.map((doc) => _JobCard(doc: doc, isDark: isDark)),
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
              color:  AppColors.brandPurple.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.work_history_rounded,
              color: AppColors.brandPurple, size: 34)),
      const SizedBox(height: 16),
      Text('No jobs found',
          style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text('Your completed jobs will appear here',
          style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13)),
    ]));
  }
}

class _SummaryBar extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final bool isDark;
  const _SummaryBar({required this.docs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    int completed = 0; int declined = 0; double total = 0;
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final s = d['status'] as String? ?? '';
      if (s == 'completed') {
        completed++;
        total += ((d['amount'] ?? 0) as num).toDouble();
      }
      if (s == 'declined') declined++;
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
          label: 'Earned', value: '₹${total.toStringAsFixed(0)}',
          color: AppColors.warning, isDark: isDark)),
    ]);
  }
}

class _SummaryChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
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

class _JobCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isDark;
  const _JobCard({required this.doc, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final d       = doc.data() as Map<String, dynamic>;
    final status  = (d['status']      as String?) ?? 'pending';
    final svc     = (d['serviceName'] as String?) ?? 'Service';
    final user    = (d['userName']    as String?) ?? 'Customer';
    final amount  = ((d['amount']     ?? 0) as num).toDouble();
    final ts      = (d['createdAt']   as Timestamp?)?.toDate();

    final (color, icon, label) = _statusInfo(status);

    return Container(
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
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color:        color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(svc, style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(user, style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 12)),
            if (ts != null)
              Text(DateFormat('d MMM yyyy, h:mm a').format(ts),
                  style: TextStyle(
                      color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                      fontSize: 11)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(status == 'completed' ? '+₹${amount.toStringAsFixed(0)}' : '₹${amount.toStringAsFixed(0)}',
                style: TextStyle(
                    color:      status == 'completed' ? AppColors.success
                        : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                    fontSize:   14, fontWeight: FontWeight.w700)),
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

  (Color, IconData, String) _statusInfo(String s) {
    switch (s.toLowerCase()) {
      case 'completed':  return (AppColors.success,       Icons.check_circle_rounded,  'DONE');
      case 'accepted':   return (AppColors.brandPurple,   Icons.handshake_rounded,     'ACCEPTED');
      case 'in_progress':return (AppColors.onlineGreen,   Icons.play_circle_rounded,   'ACTIVE');
      case 'declined':   return (AppColors.danger,        Icons.cancel_rounded,        'DECLINED');
      case 'timeout':    return (AppColors.textSoftDark,  Icons.timer_off_rounded,     'TIMEOUT');
      default:           return (AppColors.warning,       Icons.pending_rounded,       'PENDING');
    }
  }
}