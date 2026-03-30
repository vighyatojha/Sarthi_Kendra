// lib/screens/schedule/schedule_screen.dart
//
// FIX 8 APPLIED:
//  • _statusColor/_statusIcon: 'active' replaced with 'ongoing' + added 'accepted'
//  • _TodayTab filter: show ONLY accepted + ongoing (not all non-cancelled)
//  • _DayBookingList filter: same — accepted + ongoing only
//  • _CalendarTabState._fetchMonth: calendar dots only for accepted + ongoing
//  Everything else (Timestamp range queries, time extraction via DateFormat,
//  scheduledAt Timestamp for day/month ranges) was already correct — preserved as-is.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../providers/auth_provider.dart';
import '../../../theme/app_theme.dart';

// ─── Shared palette ───────────────────────────────────────────────────────────
class _P {
  static const bg     = Color(0xFFF8F7FF);
  static const white  = Colors.white;
  static const purple = Color(0xFF7C3AED);
  static const indigo = Color(0xFF2D1B69);
  static const violet = Color(0xFF5B21B6);
  static const green  = Color(0xFF16A34A);
  static const amber  = Color(0xFFF59E0B);
  static const red    = Color(0xFFEF4444);
  static const t1     = Color(0xFF1E1B4B);
  static const t2     = Color(0xFF64748B);
  static const t3     = Color(0xFF94A3B8);
  static const border = Color(0xFFEDE9FE);
  static const div    = Color(0xFFF1F0FF);
}

double _safeDouble(dynamic v) =>
    v == null ? 0.0 : v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0.0;

// ─── Date helpers ─────────────────────────────────────────────────────────────
DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _endOfDay(DateTime d)   => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

/// Checks if a booking's scheduledAt Timestamp falls on [day].
bool _isOnDay(Map<String, dynamic> data, DateTime day) {
  final ts = data['scheduledAt'] as Timestamp?;
  if (ts == null) return false;
  final dt = ts.toDate().toLocal();
  return dt.year == day.year && dt.month == day.month && dt.day == day.day;
}

// ═══════════════════════════════════════════════════════════════════════════
// SCHEDULE SCREEN
// ═══════════════════════════════════════════════════════════════════════════
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  DateTime _selectedDay = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
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
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_P.indigo, _P.violet, _P.purple],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text('My Schedule',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('EEEE, d MMMM yyyy').format(DateTime.now()),
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(text: '  TODAY  '),
                Tab(text: '  CALENDAR  '),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _TodayTab(uid: uid),
            _CalendarTab(
              uid: uid,
              selectedDay: _selectedDay,
              onDaySelected: (d) => setState(() => _selectedDay = d),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TODAY TAB
// ═══════════════════════════════════════════════════════════════════════════
class _TodayTab extends StatelessWidget {
  final String uid;
  const _TodayTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    final today    = DateTime.now();
    final dayStart = Timestamp.fromDate(_startOfDay(today));
    final dayEnd   = Timestamp.fromDate(_endOfDay(today));

    // REQUIRES COMPOSITE INDEX: helperId ASC + scheduledAt ASC
    // (Firestore console will show a link to create it on first run.)
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('scheduledAt', isGreaterThanOrEqualTo: dayStart)
          .where('scheduledAt', isLessThanOrEqualTo: dayEnd)
          .orderBy('scheduledAt')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _P.purple));
        }

        // FIX 8 — schedule shows ONLY accepted + ongoing bookings.
        // pending = not confirmed by helper; completed/cancelled = not relevant.
        final docs = snap.data!.docs.where((doc) {
          final status =
              (doc.data() as Map<String, dynamic>)['status'] as String? ?? '';
          return status == 'accepted' || status == 'ongoing';
        }).toList();

        if (docs.isEmpty) {
          return _EmptySchedule(
            message: 'No jobs scheduled for today',
            subtitle: 'Accepted bookings will appear here',
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 0),
          itemBuilder: (ctx, i) {
            final doc = docs[i];
            return _TimelineJobTile(
              key:       ValueKey(doc.id),
              bookingId: doc.id,
              data:      doc.data() as Map<String, dynamic>,
              isFirst:   i == 0,
              isLast:    i == docs.length - 1,
            );
          },
        );
      },
    );
  }
}

// ── Timeline job tile ─────────────────────────────────────────────────────
class _TimelineJobTile extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> data;
  final bool isFirst;
  final bool isLast;

  const _TimelineJobTile({
    super.key,
    required this.bookingId,
    required this.data,
    required this.isFirst,
    required this.isLast,
  });

  // FIX 8 — unified status colours: 'active' removed, 'ongoing' + 'accepted' added
  static Color _statusColor(String s) {
    switch (s) {
      case 'completed': return _P.green;
      case 'ongoing':   return AppColors.onlineGreen;   // work started
      case 'accepted':  return _P.purple;               // confirmed, not started
      case 'pending':   return _P.amber;
      case 'cancelled': return _P.red;
      default:          return _P.purple;
    }
  }

  // FIX 8 — unified status icons
  static IconData _statusIcon(String s) {
    switch (s) {
      case 'completed': return Icons.check_circle_rounded;
      case 'ongoing':   return Icons.play_circle_rounded;
      case 'accepted':  return Icons.event_available_rounded;
      case 'pending':   return Icons.pending_rounded;
      default:          return Icons.schedule_rounded;
    }
  }

  static (IconData, Color) _svcIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('plumb'))                    return (Icons.plumbing_rounded,            const Color(0xFF0EA5E9));
    if (n.contains('electr'))                   return (Icons.electrical_services_rounded, const Color(0xFFF59E0B));
    if (n.contains('clean'))                    return (Icons.cleaning_services_rounded,   const Color(0xFF10B981));
    if (n.contains('ac') || n.contains('air'))  return (Icons.ac_unit_rounded,             const Color(0xFF06B6D4));
    if (n.contains('paint'))                    return (Icons.format_paint_rounded,        const Color(0xFFEF4444));
    if (n.contains('pest'))                     return (Icons.pest_control_rounded,        const Color(0xFF84CC16));
    if (n.contains('carpenter'))                return (Icons.carpenter_rounded,           const Color(0xFF92400E));
    if (n.contains('car') || n.contains('vehicle')) return (Icons.directions_car_rounded, const Color(0xFF6366F1));
    return (Icons.home_repair_service_rounded, _P.purple);
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final svc    = data['serviceName'] as String? ?? 'Service';

    // FIX 8 — scheduledAt is a Firestore Timestamp; extract time string from it
    final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
    final timeStr = scheduledAt != null
        ? DateFormat('h:mm a').format(scheduledAt.toLocal())
        : '';

    final address     = data['address']       as String? ?? '';
    // baseAmount = helper's payment; platform fee is never shown
    final amount      = _safeDouble(data['baseAmount'] ?? data['totalAmount']);

    final sColor           = _statusColor(status);
    final (svcIcon, svcColor) = _svcIcon(svc);

    final helperName  = data['helperName']  as String? ?? '';
    final category    = data['categoryName'] as String? ?? '';
    final bookingCode = data['bookingCode']  as String?
        ?? bookingId.substring(0, 8).toUpperCase();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column
          SizedBox(
            width: 64,
            child: Column(children: [
              Text(timeStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _P.t2, fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                    color: sColor, shape: BoxShape.circle,
                    border: Border.all(color: _P.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: sColor.withOpacity(0.4),
                          blurRadius: 6, spreadRadius: 1)
                    ]),
              ),
              if (!isLast)
                Expanded(child: Container(
                  width: 2,
                  color: _P.border,
                  margin: const EdgeInsets.symmetric(vertical: 2),
                )),
            ]),
          ),
          const SizedBox(width: 8),
          // Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _P.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _P.border),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                          color: svcColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(svcIcon, color: svcColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(svc,
                              style: const TextStyle(
                                  color: _P.t1, fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          if (category.isNotEmpty || helperName.isNotEmpty)
                            Text(
                              category.isNotEmpty ? category : helperName,
                              style: const TextStyle(color: _P.t2, fontSize: 11),
                            ),
                          Row(children: [
                            Icon(_statusIcon(status), color: sColor, size: 11),
                            const SizedBox(width: 4),
                            Text(status.replaceAll('_', ' ').toUpperCase(),
                                style: TextStyle(
                                    color: sColor, fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            Text('#$bookingCode',
                                style: const TextStyle(
                                    color: _P.t3, fontSize: 9)),
                          ]),
                        ])),
                    Text('₹${amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: _P.t1, fontSize: 16,
                            fontWeight: FontWeight.w800)),
                  ]),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(height: 1, color: _P.div),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.location_on_rounded,
                          color: _P.t3, size: 13),
                      const SizedBox(width: 6),
                      Expanded(child: Text(address,
                          style: const TextStyle(
                              color: _P.t2, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                  // Show full scheduled date+time for clarity
                  if (scheduledAt != null) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.schedule_rounded, color: _P.t3, size: 13),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('d MMM yyyy, h:mm a')
                            .format(scheduledAt.toLocal()),
                        style: const TextStyle(color: _P.t3, fontSize: 11),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CALENDAR TAB
// ═══════════════════════════════════════════════════════════════════════════
class _CalendarTab extends StatefulWidget {
  final String uid;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const _CalendarTab({
    required this.uid,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  State<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  Map<String, int> _bookedDates = {};

  @override
  void initState() {
    super.initState();
    _fetchMonth(_displayMonth);
  }

  /// FIX 8 — Only accepted + ongoing bookings get calendar dots.
  /// Cancelled, pending, completed bookings are NOT shown on the calendar.
  Future<void> _fetchMonth(DateTime month) async {
    if (widget.uid.isEmpty) return;

    final monthStart = Timestamp.fromDate(DateTime(month.year, month.month));
    final monthEnd   = Timestamp.fromDate(DateTime(month.year, month.month + 1));

    // REQUIRES COMPOSITE INDEX: helperId ASC + scheduledAt ASC
    try {
      final snap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: widget.uid)
          .where('scheduledAt', isGreaterThanOrEqualTo: monthStart)
          .where('scheduledAt', isLessThan: monthEnd)
          .get();

      final counts = <String, int>{};
      for (final doc in snap.docs) {
        final d      = doc.data();
        final status = d['status'] as String? ?? '';

        // FIX 8 — calendar dots only for accepted + ongoing
        if (status != 'accepted' && status != 'ongoing') continue;

        final ts = d['scheduledAt'] as Timestamp?;
        if (ts == null) continue;
        final dateStr =
        DateFormat('yyyy-MM-dd').format(ts.toDate().toLocal());
        counts[dateStr] = (counts[dateStr] ?? 0) + 1;
      }
      if (mounted) setState(() => _bookedDates = counts);
    } catch (e) {
      debugPrint('[ScheduleScreen] _fetchMonth error: $e');
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        Container(
          decoration: BoxDecoration(
              color: _P.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _P.border),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12, offset: const Offset(0, 4))]),
          child: Column(children: [
            _CalendarHeader(
              month: _displayMonth,
              onPrev: _prevMonth,
              onNext: _nextMonth,
            ),
            _CalendarGrid(
              month:       _displayMonth,
              selectedDay: widget.selectedDay,
              bookedDates: _bookedDates,
              onSelect:    widget.onDaySelected,
            ),
            const SizedBox(height: 8),
            _CalendarLegend(),
            const SizedBox(height: 14),
          ]),
        ),
        const SizedBox(height: 20),
        _SelectedDayHeader(day: widget.selectedDay),
        const SizedBox(height: 12),
        _DayBookingList(uid: widget.uid, day: widget.selectedDay),
      ],
    );
  }
}

// ── Calendar header ───────────────────────────────────────────────────────
class _CalendarHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev, onNext;

  const _CalendarHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 4),
    child: Row(children: [
      Text(DateFormat('MMMM yyyy').format(month),
          style: const TextStyle(
              color: _P.t1, fontSize: 17, fontWeight: FontWeight.w800)),
      const Spacer(),
      _NavBtn(icon: Icons.chevron_left_rounded,  onTap: onPrev),
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
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
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

// ── Calendar grid ─────────────────────────────────────────────────────────
class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final Map<String, int> bookedDates;
  final ValueChanged<DateTime> onSelect;

  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.bookedDates,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay    = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today       = DateTime.now();
    final todayDate   = DateTime(today.year, today.month, today.day);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(children: [
        Row(
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa']
              .map((d) => Expanded(
            child: Center(
              child: Text(d,
                  style: const TextStyle(
                      color: _P.t3, fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ))
              .toList(),
        ),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount:  7,
            childAspectRatio: 1.0,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (ctx, i) {
            if (i < startOffset) return const SizedBox();
            final day     = i - startOffset + 1;
            final date    = DateTime(month.year, month.month, day);
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final isToday = date == todayDate;
            final isSel   = date == selectedDay;
            final count   = bookedDates[dateStr] ?? 0;
            final hasJobs = count > 0;
            final isPast  = date.isBefore(todayDate);

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(date);
              },
              child: _DayCell(
                day:        day,
                isToday:    isToday,
                isSelected: isSel,
                hasJobs:    hasJobs,
                jobCount:   count,
                isPast:     isPast,
              ),
            );
          },
        ),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  final int  day, jobCount;
  final bool isToday, isSelected, hasJobs, isPast;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.isSelected,
    required this.hasJobs,
    required this.jobCount,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    Color   bg     = Colors.transparent;
    Color   fg     = isPast ? _P.t3 : _P.t1;
    Border? border;

    if (isSelected) {
      bg = _P.purple;
      fg = Colors.white;
    } else if (isToday) {
      border = Border.all(color: _P.purple, width: 1.5);
      fg = _P.purple;
    }

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: border),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$day',
                style: TextStyle(
                    color: fg, fontSize: 13,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800 : FontWeight.w500)),
            if (hasJobs) ...[
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  jobCount.clamp(1, 3),
                      (_) => Container(
                    width: 4, height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.8)
                            : _P.purple,
                        shape: BoxShape.circle),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Calendar legend ───────────────────────────────────────────────────────
class _CalendarLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      _LegendItem(color: _P.purple, label: 'Selected'),
      const SizedBox(width: 18),
      _LegendItem(
        child: Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: _P.purple, width: 1.5)),
          child: const Center(
              child: Text('·',
                  style: TextStyle(color: _P.purple, fontSize: 10))),
        ),
        label: 'Today',
      ),
      const SizedBox(width: 18),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: _P.purple, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        const Text('Has Jobs',
            style: TextStyle(color: _P.t2, fontSize: 11)),
      ]),
    ]),
  );
}

class _LegendItem extends StatelessWidget {
  final Color?  color;
  final Widget? child;
  final String  label;

  const _LegendItem({this.color, this.child, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      child ?? Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(5))),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: _P.t2, fontSize: 11)),
    ],
  );
}

// ── Selected day header ───────────────────────────────────────────────────
class _SelectedDayHeader extends StatelessWidget {
  final DateTime day;
  const _SelectedDayHeader({required this.day});

  @override
  Widget build(BuildContext context) {
    final today     = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final isTomorrow =
        day == DateTime(today.year, today.month, today.day + 1);

    String label;
    if (day == todayDate)  label = "Today's Jobs";
    else if (isTomorrow)   label = "Tomorrow's Jobs";
    else                   label = DateFormat('EEE, d MMM').format(day);

    return Row(children: [
      Container(width: 4, height: 18,
          decoration: BoxDecoration(
              color: _P.purple, borderRadius: BorderRadius.circular(4))),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              color: _P.t1, fontSize: 17, fontWeight: FontWeight.w800)),
    ]);
  }
}

// ── Day booking list ──────────────────────────────────────────────────────
class _DayBookingList extends StatelessWidget {
  final String uid;
  final DateTime day;
  const _DayBookingList({required this.uid, required this.day});

  @override
  Widget build(BuildContext context) {
    final dayStart = Timestamp.fromDate(_startOfDay(day));
    final dayEnd   = Timestamp.fromDate(_endOfDay(day));

    // REQUIRES COMPOSITE INDEX: helperId ASC + scheduledAt ASC
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('helperId', isEqualTo: uid)
          .where('scheduledAt', isGreaterThanOrEqualTo: dayStart)
          .where('scheduledAt', isLessThanOrEqualTo: dayEnd)
          .orderBy('scheduledAt')
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: _P.purple),
              ));
        }

        // FIX 8 — day view shows ONLY accepted + ongoing bookings
        final docs = snap.data!.docs.where((doc) {
          final status =
              (doc.data() as Map<String, dynamic>)['status'] as String? ?? '';
          return status == 'accepted' || status == 'ongoing';
        }).toList();

        if (docs.isEmpty) {
          return _EmptySchedule(
            message: 'No jobs on this day',
            subtitle: 'Accept bookings to fill your schedule',
          );
        }

        return Column(
          children: docs.asMap().entries.map((e) => _TimelineJobTile(
            key:       ValueKey(e.value.id),
            bookingId: e.value.id,
            data:      e.value.data() as Map<String, dynamic>,
            isFirst:   e.key == 0,
            isLast:    e.key == docs.length - 1,
          )).toList(),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────
class _EmptySchedule extends StatelessWidget {
  final String message, subtitle;
  const _EmptySchedule({required this.message, required this.subtitle});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    decoration: BoxDecoration(
        color: const Color(0xFFF0EEFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDD6FE))),
    child: Column(children: [
      Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
            color: _P.purple.withOpacity(0.10), shape: BoxShape.circle),
        child: const Icon(Icons.calendar_today_rounded,
            color: _P.purple, size: 26),
      ),
      const SizedBox(height: 14),
      Text(message,
          style: const TextStyle(
              color: _P.t1, fontSize: 15, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _P.t2, fontSize: 12, height: 1.5)),
    ]),
  );
}