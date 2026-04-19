// lib/screens/schedule/schedule_screen.dart
//
// ENHANCED SCHEDULE SCREEN v2.0
//  • Beautiful timeline UI with gradient cards
//  • Today tab: accepted + ongoing + arrived jobs
//  • Calendar tab: interactive calendar with dots for booked days
//  • History tab: all completed jobs grouped by month
//  • Upcoming section: future accepted jobs
//  • Stats bar: daily/weekly job counts & earnings
//  • All Firestore queries use scheduledAt Timestamp correctly
//  • Only requires composite index: helperId ASC + scheduledAt ASC

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

// ─── Palette ──────────────────────────────────────────────────────────────────
class _P {
  static const bg       = Color(0xFFF0EEFF);
  static const white    = Colors.white;
  static const purple   = Color(0xFF6D28D9);
  static const violet   = Color(0xFF5B21B6);
  static const indigo   = Color(0xFF1E1B4B);
  static const lavender = Color(0xFFEDE9FE);
  static const green    = Color(0xFF059669);
  static const amber    = Color(0xFFD97706);
  static const red      = Color(0xFFDC2626);
  static const cyan     = Color(0xFF0891B2);
  static const t1       = Color(0xFF1E1B4B);
  static const t2       = Color(0xFF6B7280);
  static const t3       = Color(0xFF9CA3AF);
  static const border   = Color(0xFFDDD6FE);
  static const card     = Color(0xFFFAF9FF);
}

double _sd(dynamic v) =>
    v == null ? 0.0 : v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

// ─── Status helpers ───────────────────────────────────────────────────────────
Color _statusColor(String s) {
  switch (s) {
    case 'ongoing':   return const Color(0xFF059669);
    case 'arrived':   return const Color(0xFFD97706);
    case 'accepted':  return const Color(0xFF6D28D9);
    case 'completed': return const Color(0xFF0891B2);
    case 'cancelled': return const Color(0xFFDC2626);
    default:          return _P.t3;
  }
}

IconData _statusIcon(String s) {
  switch (s) {
    case 'ongoing':   return Icons.play_circle_filled_rounded;
    case 'arrived':   return Icons.location_on_rounded;
    case 'accepted':  return Icons.event_available_rounded;
    case 'completed': return Icons.check_circle_rounded;
    case 'cancelled': return Icons.cancel_rounded;
    default:          return Icons.schedule_rounded;
  }
}

String _statusLabel(String s) {
  switch (s) {
    case 'ongoing':   return 'IN PROGRESS';
    case 'arrived':   return 'ARRIVED';
    case 'accepted':  return 'CONFIRMED';
    case 'completed': return 'DONE';
    case 'cancelled': return 'CANCELLED';
    default:          return s.toUpperCase();
  }
}

(IconData, Color) _serviceIcon(String name) {
  final n = name.toLowerCase();
  if (n.contains('plumb'))  return (Icons.plumbing_rounded, const Color(0xFF0891B2));
  if (n.contains('electr')) return (Icons.electrical_services_rounded, const Color(0xFFD97706));
  if (n.contains('clean'))  return (Icons.cleaning_services_rounded, const Color(0xFF059669));
  if (n.contains('ac') || n.contains('air')) return (Icons.ac_unit_rounded, const Color(0xFF0891B2));
  if (n.contains('paint'))  return (Icons.format_paint_rounded, const Color(0xFFDC2626));
  if (n.contains('pest'))   return (Icons.pest_control_rounded, const Color(0xFF16A34A));
  if (n.contains('carpen')) return (Icons.carpenter_rounded, const Color(0xFF92400E));
  if (n.contains('car') || n.contains('vehicle')) return (Icons.directions_car_rounded, const Color(0xFF6366F1));
  return (Icons.home_repair_service_rounded, _P.purple);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SCHEDULE SCREEN ROOT
// ═══════════════════════════════════════════════════════════════════════════════
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  DateTime _selectedDay = _todayMidnight();

  static DateTime _todayMidnight() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().helper?.uid ?? '';

    return Scaffold(
      backgroundColor: _P.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _ScheduleAppBar(tabCtrl: _tabCtrl),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          physics: const ClampingScrollPhysics(),
          children: [
            _TodayTab(uid: uid),
            _CalendarTab(
              uid: uid,
              selectedDay: _selectedDay,
              onDaySelected: (d) => setState(() => _selectedDay = d),
            ),
            _HistoryTab(uid: uid),
          ],
        ),
      ),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────
class _ScheduleAppBar extends StatelessWidget {
  final TabController tabCtrl;
  const _ScheduleAppBar({required this.tabCtrl});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E0A3C), Color(0xFF3B1A7A), Color(0xFF6D28D9)],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(top: -20, right: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.04),
                    ),
                  )),
              Positioned(bottom: 20, right: 60,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.06),
                    ),
                  )),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(children: [
                        const Icon(Icons.calendar_month_rounded,
                            color: Colors.white70, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ]),
                      const SizedBox(height: 4),
                      const Text('My Schedule',
                          style: TextStyle(
                              color: Colors.white, fontSize: 26,
                              fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(46),
        child: Container(
          color: const Color(0xFF3B1A7A),
          child: TabBar(
            controller: tabCtrl,
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'TODAY'),
              Tab(text: 'CALENDAR'),
              Tab(text: 'HISTORY'),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TODAY TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _TodayTab extends StatefulWidget {
  final String uid;
  const _TodayTab({required this.uid});

  @override
  State<_TodayTab> createState() => _TodayTabState();
}

class _TodayTabState extends State<_TodayTab> {
  StreamSubscription<QuerySnapshot>? _sub;
  List<Map<String, dynamic>> _todayJobs = [];
  double _todayEarnings = 0;
  int _completedToday = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;
    final today = DateTime.now();
    final start = Timestamp.fromDate(_startOfDay(today));
    final end = Timestamp.fromDate(_endOfDay(today));

    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .where('scheduledAt', isGreaterThanOrEqualTo: start)
        .where('scheduledAt', isLessThanOrEqualTo: end)
        .snapshots()
        .listen((snap) {
      final all = snap.docs.map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>}).toList();
      all.sort((a, b) {
        final ta = (a['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return ta.compareTo(tb);
      });

      double earnings = 0;
      int completed = 0;
      for (final j in all) {
        if (j['status'] == 'completed') {
          earnings += _sd(j['baseAmount']);
          completed++;
        }
      }

      if (mounted) setState(() {
        _todayJobs = all;
        _todayEarnings = earnings;
        _completedToday = completed;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator(color: _P.purple));
    }

    final activeJobs = _todayJobs.where((j) {
      final s = j['status'] as String? ?? '';
      return s == 'accepted' || s == 'ongoing' || s == 'arrived';
    }).toList();

    final completedJobs = _todayJobs.where((j) => j['status'] == 'completed').toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _TodayStatsBar(
            totalJobs: _todayJobs.length,
            completedJobs: _completedToday,
            activeJobs: activeJobs.length,
            earnings: _todayEarnings,
          ),
        ),
        if (activeJobs.isEmpty && completedJobs.isEmpty)
          SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.today_rounded,
              title: 'No jobs today',
              subtitle: 'Accepted bookings for today will appear here',
            ),
          )
        else ...[
          if (activeJobs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Active Jobs',
                count: activeJobs.length,
                color: _P.green,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _TimelineJobCard(
                  job: activeJobs[i],
                  isFirst: i == 0,
                  isLast: i == activeJobs.length - 1,
                  showTimeline: true,
                ),
                childCount: activeJobs.length,
              ),
            ),
          ],
          if (completedJobs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _SectionHeader(
                title: 'Completed Today',
                count: completedJobs.length,
                color: _P.cyan,
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _TimelineJobCard(
                  job: completedJobs[i],
                  isFirst: i == 0,
                  isLast: i == completedJobs.length - 1,
                  showTimeline: false,
                ),
                childCount: completedJobs.length,
              ),
            ),
          ],
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── Today Stats Bar ──────────────────────────────────────────────────────────
class _TodayStatsBar extends StatelessWidget {
  final int totalJobs, completedJobs, activeJobs;
  final double earnings;
  const _TodayStatsBar({
    required this.totalJobs,
    required this.completedJobs,
    required this.activeJobs,
    required this.earnings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E0A3C), Color(0xFF3B1A7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _P.purple.withOpacity(0.3),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(children: [
        _StatItem(
          value: '$totalJobs',
          label: 'Total',
          icon: Icons.calendar_today_rounded,
          color: Colors.white,
        ),
        _vDivider(),
        _StatItem(
          value: '$activeJobs',
          label: 'Active',
          icon: Icons.play_circle_rounded,
          color: const Color(0xFF4ADE80),
        ),
        _vDivider(),
        _StatItem(
          value: '$completedJobs',
          label: 'Done',
          icon: Icons.check_circle_rounded,
          color: const Color(0xFF60A5FA),
        ),
        _vDivider(),
        _StatItem(
          value: '₹${earnings.toStringAsFixed(0)}',
          label: 'Earned',
          icon: Icons.currency_rupee_rounded,
          color: const Color(0xFFFBBF24),
        ),
      ]),
    );
  }

  Widget _vDivider() => Container(
    width: 1, height: 36,
    color: Colors.white.withOpacity(0.12),
    margin: const EdgeInsets.symmetric(horizontal: 4),
  );
}

class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem({required this.value, required this.label,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Icon(icon, color: color, size: 16),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          color: color, fontSize: 15, fontWeight: FontWeight.w800)),
      Text(label, style: const TextStyle(
          color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ─── Section Header ───────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _SectionHeader({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
    child: Row(children: [
      Container(width: 3, height: 16,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
          color: _P.t1, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12)),
        child: Text('$count', style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ─── Timeline Job Card ────────────────────────────────────────────────────────
class _TimelineJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isFirst, isLast, showTimeline;
  const _TimelineJobCard({
    required this.job,
    required this.isFirst,
    required this.isLast,
    required this.showTimeline,
  });

  @override
  Widget build(BuildContext context) {
    final status = job['status'] as String? ?? '';
    final svc = job['serviceName'] as String? ?? 'Service';
    final scheduledAt = (job['scheduledAt'] as Timestamp?)?.toDate();
    final timeStr = scheduledAt != null
        ? DateFormat('h:mm a').format(scheduledAt.toLocal()) : '';
    final dateStr = scheduledAt != null
        ? DateFormat('d MMM').format(scheduledAt.toLocal()) : '';
    final address = job['address'] as String? ?? '';
    final amount = _sd(job['baseAmount'] ?? job['totalAmount']);
    final bookingCode = job['bookingCode'] as String?
        ?? (job['id'] as String).substring(0, 8).toUpperCase();
    final sColor = _statusColor(status);
    final (svcIcon, svcColor) = _serviceIcon(svc);

    if (!showTimeline) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        decoration: BoxDecoration(
          color: _P.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _P.border),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: _CardContent(
          svc: svc, svcIcon: svcIcon, svcColor: svcColor,
          status: status, sColor: sColor, timeStr: timeStr,
          dateStr: dateStr, address: address, amount: amount,
          bookingCode: bookingCode, scheduledAt: scheduledAt,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline column
            SizedBox(
              width: 52,
              child: Column(children: [
                if (!isFirst) const SizedBox(height: 4),
                Text(timeStr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _P.purple, fontSize: 10,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  width: 14, height: 14,
                  decoration: BoxDecoration(
                    color: sColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: sColor.withOpacity(0.4),
                          blurRadius: 8, spreadRadius: 1),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [sColor.withOpacity(0.4), _P.border],
                      ),
                    ),
                  )),
              ]),
            ),
            const SizedBox(width: 8),
            // Card
            Expanded(
              child: Container(
                margin: EdgeInsets.only(bottom: isLast ? 4 : 10, top: isFirst ? 0 : 0),
                decoration: BoxDecoration(
                  color: _P.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _P.border),
                  boxShadow: [BoxShadow(
                      color: sColor.withOpacity(0.08),
                      blurRadius: 10, offset: const Offset(0, 3))],
                ),
                child: _CardContent(
                  svc: svc, svcIcon: svcIcon, svcColor: svcColor,
                  status: status, sColor: sColor, timeStr: timeStr,
                  dateStr: dateStr, address: address, amount: amount,
                  bookingCode: bookingCode, scheduledAt: scheduledAt,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final String svc, status, timeStr, dateStr, address, bookingCode;
  final IconData svcIcon;
  final Color svcColor, sColor;
  final double amount;
  final DateTime? scheduledAt;
  const _CardContent({
    required this.svc, required this.svcIcon, required this.svcColor,
    required this.status, required this.sColor, required this.timeStr,
    required this.dateStr, required this.address, required this.amount,
    required this.bookingCode, required this.scheduledAt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: svcColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(svcIcon, color: svcColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(svc, style: const TextStyle(
                color: _P.t1, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: sColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_statusIcon(status), color: sColor, size: 9),
                  const SizedBox(width: 3),
                  Text(_statusLabel(status), style: TextStyle(
                      color: sColor, fontSize: 9, fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 6),
              Text('#$bookingCode', style: const TextStyle(
                  color: _P.t3, fontSize: 9)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('₹${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                    color: _P.t1, fontSize: 16, fontWeight: FontWeight.w800)),
          ]),
        ]),
        if (address.isNotEmpty || scheduledAt != null) ...[
          const SizedBox(height: 10),
          Container(height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_P.border, _P.border.withOpacity(0)],
                ),
              )),
          const SizedBox(height: 8),
          if (scheduledAt != null)
            Row(children: [
              const Icon(Icons.schedule_rounded, color: _P.t3, size: 12),
              const SizedBox(width: 5),
              Text(DateFormat('d MMM yyyy, h:mm a').format(scheduledAt!.toLocal()),
                  style: const TextStyle(color: _P.t2, fontSize: 11)),
            ]),
          if (address.isNotEmpty) ...[
            if (scheduledAt != null) const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_rounded, color: _P.t3, size: 12),
              const SizedBox(width: 5),
              Expanded(child: Text(address,
                  style: const TextStyle(color: _P.t2, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CALENDAR TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _CalendarTab extends StatefulWidget {
  final String uid;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  const _CalendarTab({required this.uid, required this.selectedDay, required this.onDaySelected});

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  // Map of dateStr → {'count': int, 'hasCompleted': bool, 'hasActive': bool}
  Map<String, Map<String, dynamic>> _dateData = {};
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    _fetchMonth(_displayMonth);
  }

  Future<void> _fetchMonth(DateTime month) async {
    if (widget.uid.isEmpty || _fetching) return;
    setState(() => _fetching = true);

    final monthStart = Timestamp.fromDate(DateTime(month.year, month.month));
    final monthEnd = Timestamp.fromDate(DateTime(month.year, month.month + 1));

    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: widget.uid)
          .where('scheduledAt', isGreaterThanOrEqualTo: monthStart)
          .where('scheduledAt', isLessThan: monthEnd)
          .get();

      final data = <String, Map<String, dynamic>>{};
      for (final doc in snap.docs) {
        final d = doc.data();
        final status = d['status'] as String? ?? '';
        if (status == 'cancelled') continue;

        final ts = d['scheduledAt'] as Timestamp?;
        if (ts == null) continue;
        final key = DateFormat('yyyy-MM-dd').format(ts.toDate().toLocal());

        data.putIfAbsent(key, () => {'count': 0, 'hasCompleted': false, 'hasActive': false});
        data[key]!['count'] = (data[key]!['count'] as int) + 1;
        if (status == 'completed') data[key]!['hasCompleted'] = true;
        if (status == 'accepted' || status == 'ongoing' || status == 'arrived') {
          data[key]!['hasActive'] = true;
        }
      }

      if (mounted) setState(() { _dateData = data; _fetching = false; });
    } catch (e) {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _prevMonth() {
    final m = DateTime(_displayMonth.year, _displayMonth.month - 1);
    setState(() => _displayMonth = m);
    _fetchMonth(m);
  }

  void _nextMonth() {
    final m = DateTime(_displayMonth.year, _displayMonth.month + 1);
    setState(() => _displayMonth = m);
    _fetchMonth(m);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _WeeklyStatsBar(uid: widget.uid),
        ),
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            decoration: BoxDecoration(
              color: _P.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Column(children: [
              _CalendarHeader(
                month: _displayMonth,
                onPrev: _prevMonth,
                onNext: _nextMonth,
                loading: _fetching,
              ),
              _CalendarGrid(
                month: _displayMonth,
                selectedDay: widget.selectedDay,
                dateData: _dateData,
                onSelect: widget.onDaySelected,
              ),
              const SizedBox(height: 10),
              _CalendarLegend(),
              const SizedBox(height: 14),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: _SelectedDayHeader(day: widget.selectedDay),
        ),
        _DayBookingSliver(uid: widget.uid, day: widget.selectedDay),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── Weekly Stats Bar ─────────────────────────────────────────────────────────
class _WeeklyStatsBar extends StatefulWidget {
  final String uid;
  const _WeeklyStatsBar({required this.uid});

  @override
  State<_WeeklyStatsBar> createState() => _WeeklyStatsBarState();
}

class _WeeklyStatsBarState extends State<_WeeklyStatsBar> {
  StreamSubscription<QuerySnapshot>? _sub;
  int _weekJobs = 0;
  double _weekEarnings = 0;
  int _totalJobs = 0;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartMid = DateTime(weekStart.year, weekStart.month, weekStart.day);

    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snap) {
      int wJobs = 0;
      double wEarnings = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final ts = (data['completedAt'] as Timestamp?)?.toDate()?.toLocal();
        if (ts != null && !ts.isBefore(weekStartMid)) {
          wJobs++;
          wEarnings += _sd(data['baseAmount']);
        }
      }
      if (mounted) setState(() {
        _weekJobs = wJobs;
        _weekEarnings = wEarnings;
        _totalJobs = snap.docs.length;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      child: Row(children: [
        Expanded(child: _MiniStatCard(
          label: 'This Week',
          value: '$_weekJobs jobs',
          sub: '₹${_weekEarnings.toStringAsFixed(0)} earned',
          icon: Icons.bar_chart_rounded,
          gradient: const [Color(0xFF6D28D9), Color(0xFF9333EA)],
        )),
        const SizedBox(width: 10),
        Expanded(child: _MiniStatCard(
          label: 'All Time',
          value: '$_totalJobs jobs',
          sub: 'since joining',
          icon: Icons.workspace_premium_rounded,
          gradient: const [Color(0xFF0891B2), Color(0xFF0E7490)],
        )),
      ]),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final List<Color> gradient;
  const _MiniStatCard({required this.label, required this.value,
    required this.sub, required this.icon, required this.gradient});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: gradient.first.withOpacity(0.3),
          blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ])),
    ]),
  );
}

// ─── Calendar Header ──────────────────────────────────────────────────────────
class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;
  final bool loading;
  const _CalendarHeader({required this.month, required this.onPrev,
    required this.onNext, required this.loading});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(DateFormat('MMMM').format(month),
            style: const TextStyle(
                color: _P.t1, fontSize: 20, fontWeight: FontWeight.w800)),
        Text(DateFormat('yyyy').format(month),
            style: const TextStyle(color: _P.t2, fontSize: 13)),
      ]),
      const Spacer(),
      if (loading)
        const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: _P.purple)),
      const SizedBox(width: 8),
      _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
      const SizedBox(width: 6),
      _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
    ]),
  );
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.selectionClick(); onTap(); },
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
          color: _P.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _P.border)),
      child: Icon(icon, color: _P.purple, size: 20),
    ),
  );
}

// ─── Calendar Grid ────────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final Map<String, Map<String, dynamic>> dateData;
  final ValueChanged<DateTime> onSelect;
  const _CalendarGrid({required this.month, required this.selectedDay,
    required this.dateData, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(children: [
        Row(
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
              .map((d) => Expanded(child: Center(
            child: Text(d, style: const TextStyle(
                color: _P.t3, fontSize: 11, fontWeight: FontWeight.w700)),
          ))).toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1.0),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (ctx, i) {
            if (i < startOffset) return const SizedBox();
            final day = i - startOffset + 1;
            final date = DateTime(month.year, month.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final isToday = date == todayDate;
            final isSel = date == selectedDay;
            final data = dateData[dateStr];
            final count = data?['count'] as int? ?? 0;
            final hasActive = data?['hasActive'] as bool? ?? false;
            final hasCompleted = data?['hasCompleted'] as bool? ?? false;
            final isPast = date.isBefore(todayDate);

            return GestureDetector(
              onTap: () { HapticFeedback.selectionClick(); onSelect(date); },
              child: _DayCell(
                day: day, isToday: isToday, isSelected: isSel,
                count: count, hasActive: hasActive, hasCompleted: hasCompleted,
                isPast: isPast,
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int day, count;
  final bool isToday, isSelected, hasActive, hasCompleted, isPast;
  const _DayCell({
    required this.day, required this.isToday, required this.isSelected,
    required this.count, required this.hasActive, required this.hasCompleted, required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.transparent;
    Color fg = isPast ? _P.t3 : _P.t1;
    Border? border;
    Gradient? gradient;

    if (isSelected) {
      gradient = const LinearGradient(
          colors: [Color(0xFF6D28D9), Color(0xFF9333EA)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
      fg = Colors.white;
    } else if (isToday) {
      border = Border.all(color: _P.purple, width: 2);
      fg = _P.purple;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? bg : null,
            borderRadius: BorderRadius.circular(10),
            border: border),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day', style: TextStyle(
                color: fg, fontSize: 13,
                fontWeight: (isSelected || isToday) ? FontWeight.w800 : FontWeight.w500)),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (hasActive)
                  Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.8) : _P.green,
                          shape: BoxShape.circle)),
                if (hasCompleted)
                  Container(width: 4, height: 4, margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.8) : _P.cyan,
                          shape: BoxShape.circle)),
                if (!hasActive && !hasCompleted && count > 0)
                  Container(width: 4, height: 4,
                      decoration: BoxDecoration(
                          color: isSelected ? Colors.white.withOpacity(0.8) : _P.purple,
                          shape: BoxShape.circle)),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Calendar Legend ──────────────────────────────────────────────────────────
class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _LegItem(color: _P.green, label: 'Active'),
      const SizedBox(width: 14),
      _LegItem(color: _P.cyan, label: 'Completed'),
      const SizedBox(width: 14),
      _LegItem(color: _P.purple, label: 'Selected', isSolid: true),
    ]),
  );
}

class _LegItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSolid;
  const _LegItem({required this.color, required this.label, this.isSolid = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    isSolid
        ? Container(width: 12, height: 12,
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(4)))
        : Container(width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: _P.t2, fontSize: 11)),
  ]);
}

// ─── Selected Day Header ──────────────────────────────────────────────────────
class _SelectedDayHeader extends StatelessWidget {
  final DateTime day;
  const _SelectedDayHeader({required this.day});

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final isTomorrow = day == today.add(const Duration(days: 1));
    String label;
    if (day == today) label = "Today's Jobs";
    else if (isTomorrow) label = "Tomorrow's Jobs";
    else label = DateFormat('EEE, d MMMM').format(day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(children: [
        Container(
          width: 4, height: 20,
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_P.purple, Color(0xFF9333EA)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter),
              borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(
            color: _P.t1, fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ─── Day Booking Sliver ───────────────────────────────────────────────────────
class _DayBookingSliver extends StatelessWidget {
  final String uid;
  final DateTime day;
  const _DayBookingSliver({required this.uid, required this.day});

  @override
  Widget build(BuildContext context) {
    final dayStart = Timestamp.fromDate(_startOfDay(day));
    final dayEnd = Timestamp.fromDate(_endOfDay(day));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('scheduledAt', isGreaterThanOrEqualTo: dayStart)
          .where('scheduledAt', isLessThanOrEqualTo: dayEnd)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: _P.purple),
            )),
          );
        }

        final docs = snap.data!.docs
            .where((d) => (d.data() as Map)['status'] != 'cancelled')
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        docs.sort((a, b) {
          final ta = (a['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final tb = (b['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return ta.compareTo(tb);
        });

        if (docs.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No jobs on this day',
                subtitle: 'Accepted bookings will appear here',
              ),
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
                (ctx, i) => _TimelineJobCard(
              job: docs[i],
              isFirst: i == 0,
              isLast: i == docs.length - 1,
              showTimeline: true,
            ),
            childCount: docs.length,
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HISTORY TAB
// ═══════════════════════════════════════════════════════════════════════════════
class _HistoryTab extends StatefulWidget {
  final String uid;
  const _HistoryTab({required this.uid});

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  StreamSubscription<QuerySnapshot>? _sub;
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  double _totalEarnings = 0;
  int _totalDone = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    if (widget.uid.isEmpty) return;
    _sub = FirebaseFirestore.instance
        .collection('bookings')
        .where('helperId', isEqualTo: widget.uid)
        .snapshots()
        .listen((snap) {
      final all = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();

      all.sort((a, b) {
        final ta = (a['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch
            ?? (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b['scheduledAt'] as Timestamp?)?.millisecondsSinceEpoch
            ?? (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

      double earnings = 0;
      int done = 0;
      final grouped = <String, List<Map<String, dynamic>>>{};

      for (final j in all) {
        final ts = (j['scheduledAt'] as Timestamp?)?.toDate()
            ?? (j['createdAt'] as Timestamp?)?.toDate();
        final key = ts != null ? DateFormat('MMMM yyyy').format(ts.toLocal()) : 'Earlier';

        grouped.putIfAbsent(key, () => []).add(j);

        if (j['status'] == 'completed') {
          earnings += _sd(j['baseAmount']);
          done++;
        }
      }

      if (mounted) setState(() {
        _grouped = grouped;
        _totalEarnings = earnings;
        _totalDone = done;
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Center(child: CircularProgressIndicator(color: _P.purple));

    final totalBookings = _grouped.values.fold(0, (sum, list) => sum + list.length);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _HistoryStatsHeader(
            totalBookings: totalBookings,
            totalDone: _totalDone,
            totalEarnings: _totalEarnings,
          ),
        ),
        if (_grouped.isEmpty)
          SliverFillRemaining(
            child: _EmptyState(
              icon: Icons.history_rounded,
              title: 'No booking history',
              subtitle: 'All your bookings will appear here',
            ),
          )
        else
          for (final entry in _grouped.entries) ...[
            SliverToBoxAdapter(
              child: _MonthGroupHeader(month: entry.key, count: entry.value.length),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _HistoryJobCard(job: entry.value[i]),
                childCount: entry.value.length,
              ),
            ),
          ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─── History Stats Header ─────────────────────────────────────────────────────
class _HistoryStatsHeader extends StatelessWidget {
  final int totalBookings, totalDone;
  final double totalEarnings;
  const _HistoryStatsHeader({required this.totalBookings, required this.totalDone,
    required this.totalEarnings});

  @override
  Widget build(BuildContext context) {
    final completion = totalBookings > 0
        ? ((totalDone / totalBookings) * 100).round() : 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF0891B2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: const Color(0xFF0891B2).withOpacity(0.3),
            blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          const Text('Career Stats', style: TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$completion% success rate',
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _HistoryStat(value: '$totalBookings', label: 'Total'),
          const SizedBox(width: 1),
          _HistoryStat(value: '$totalDone', label: 'Completed'),
          const SizedBox(width: 1),
          _HistoryStat(
            value: '₹${_formatNum(totalEarnings)}',
            label: 'Total Earned',
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalBookings > 0 ? totalDone / totalBookings : 0,
            minHeight: 5,
            backgroundColor: Colors.white.withOpacity(0.15),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ]),
    );
  }

  String _formatNum(double n) {
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _HistoryStat extends StatelessWidget {
  final String value, label;
  const _HistoryStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]));
}

// ─── Month Group Header ───────────────────────────────────────────────────────
class _MonthGroupHeader extends StatelessWidget {
  final String month;
  final int count;
  const _MonthGroupHeader({required this.month, required this.count});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
    child: Row(children: [
      Text(month, style: const TextStyle(
          color: _P.t1, fontSize: 13, fontWeight: FontWeight.w700)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: _P.lavender, borderRadius: BorderRadius.circular(10)),
        child: Text('$count', style: const TextStyle(
            color: _P.purple, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

// ─── History Job Card ─────────────────────────────────────────────────────────
class _HistoryJobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  const _HistoryJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final status = job['status'] as String? ?? '';
    final svc = job['serviceName'] as String? ?? 'Service';
    final scheduledAt = (job['scheduledAt'] as Timestamp?)?.toDate()
        ?? (job['createdAt'] as Timestamp?)?.toDate();
    final amount = _sd(job['baseAmount'] ?? job['totalAmount']);
    final bookingCode = job['bookingCode'] as String?
        ?? (job['id'] as String).substring(0, 8).toUpperCase();
    final sColor = _statusColor(status);
    final (svcIcon, svcColor) = _serviceIcon(svc);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _P.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: svcColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(svcIcon, color: svcColor, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(svc, style: const TextStyle(
              color: _P.t1, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          if (scheduledAt != null)
            Text(DateFormat('d MMM yyyy, h:mm a').format(scheduledAt.toLocal()),
                style: const TextStyle(color: _P.t3, fontSize: 11)),
          const SizedBox(height: 3),
          Text('#$bookingCode', style: const TextStyle(color: _P.t3, fontSize: 10)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            status == 'completed' ? '+₹${amount.toStringAsFixed(0)}' : '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
                color: status == 'completed' ? _P.green : _P.t2,
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
                color: sColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_statusIcon(status), color: sColor, size: 9),
              const SizedBox(width: 3),
              Text(_statusLabel(status), style: TextStyle(
                  color: sColor, fontSize: 8, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ]),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [_P.purple.withOpacity(0.1), _P.purple.withOpacity(0.05)]),
            shape: BoxShape.circle,
            border: Border.all(color: _P.border)),
        child: Icon(icon, color: _P.purple, size: 32),
      ),
      const SizedBox(height: 16),
      Text(title, style: const TextStyle(
          color: _P.t1, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _P.t2, fontSize: 12, height: 1.5)),
    ]),
  );
}