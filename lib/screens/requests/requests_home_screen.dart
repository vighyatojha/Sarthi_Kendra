// lib/screens/requests/requests_home_screen.dart
// "Jobs" tab of Sarthi Kendra: availability switch, nearby requests to price,
// active jobs and history. Nearby requests are read straight from Firestore
// (open jobs in the 5×5 geohash block around the helper, then exact 5 km).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/geo.dart';
import '../../core/job_api.dart';
import '../../core/job_models.dart';
import '../../core/service_catalog.dart';
import '../../providers/auth_provider.dart';
import '../../services/helper_location_service.dart';
import '../kyc/kyc_screen.dart';
import 'helper_booking_screen.dart';
import 'request_detail_screen.dart';
import 'requests_strings.dart';

const _purple = Color(0xFF7C3AED);
const _ink = Color(0xFF1E1B4B);
const _muted = Color(0xFF64748B);
const _green = Color(0xFF16A34A);
const _bg = Color(0xFFF8F7FF);

class RequestsHomeScreen extends StatefulWidget {
  const RequestsHomeScreen({super.key});

  @override
  State<RequestsHomeScreen> createState() => _RequestsHomeScreenState();
}

class _RequestsHomeScreenState extends State<RequestsHomeScreen> {
  bool _toggling = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {}); // refresh countdowns / hide closed requests
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool currentlyOnline) async {
    if (_toggling) return;
    setState(() => _toggling = true);
    final problem = await context.read<AuthProvider>().toggleOnlineStatus();
    if (!mounted) return;
    setState(() => _toggling = false);
    if (problem != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(problem), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final helper = context.watch<AuthProvider>().helper;
    final online = helper?.isOnline ?? false;
    final kyc = helper?.kycStatus ?? 'not_submitted';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _bg,
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(child: _header(context, online)),
            if (kyc != 'approved') SliverToBoxAdapter(child: _kycBanner(context, kyc)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(TabBar(
                labelColor: _purple,
                unselectedLabelColor: _muted,
                indicatorColor: _purple,
                tabs: [
                  Tab(text: tr(context, 'tabNew')),
                  Tab(text: tr(context, 'tabJobs')),
                  Tab(text: tr(context, 'tabHistory')),
                ],
              )),
            ),
          ],
          body: TabBarView(children: [
            _InvitesTab(online: online),
            const _BookingsTab(active: true),
            const _BookingsTab(active: false),
          ]),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, bool online) => Container(
    padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 18),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [Color(0xFF2D1B69), Color(0xFF5B21B6), Color(0xFF7C3AED)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr(context, 'work'),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Icon(online ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
              color: online ? const Color(0xFF86EFAC) : Colors.white70),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, online ? 'available' : 'unavailable'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              Text(tr(context, online ? 'availableSub' : 'unavailableSub'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          _toggling
              ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          )
              : Switch(
            value: online,
            activeColor: Colors.white,
            activeTrackColor: _green,
            onChanged: (_) => _toggle(online),
          ),
        ]),
      ),
    ]),
  );

  Widget _kycBanner(BuildContext context, String kyc) {
    final text = kyc == 'pending'
        ? tr(context, 'kycPending')
        : kyc == 'rejected'
        ? tr(context, 'kycRejected')
        : tr(context, 'kycNeeded');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        const Icon(Icons.verified_user_outlined, color: Color(0xFFD97706)),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: Color(0xFF92400E), height: 1.3))),
        if (kyc != 'pending')
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const KycScreen())),
            child: Text(tr(context, 'doKyc')),
          ),
      ]),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar bar;
  _TabBarDelegate(this.bar);
  @override
  double get minExtent => bar.preferredSize.height;
  @override
  double get maxExtent => bar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: _bg, child: bar);
  @override
  bool shouldRebuild(covariant _TabBarDelegate old) => old.bar != bar;
}

// ─── New requests ──────────────────────────────────────────────────────────

/// Number of open nearby requests the helper has not priced or dismissed yet.
/// The dashboard shows it as a badge on the Jobs tab.
final ValueNotifier<int> nearbyRequestCount = ValueNotifier<int>(0);

class _InvitesTab extends StatefulWidget {
  final bool online;
  const _InvitesTab({required this.online});

  @override
  State<_InvitesTab> createState() => _InvitesTabState();
}

class _InvitesTabState extends State<_InvitesTab> {
  static const _dismissKey = 'dismissed_job_ids';

  ({double lat, double lng})? _pos;
  bool _locating = true;
  Set<String> _dismissed = {};
  Stream<List<NearbyJob>>? _jobs;
  String _jobsKey = '';
  late final Stream<Map<String, Pitch>> _pitches = JobApi.instance.myPitches();

  @override
  void initState() {
    super.initState();
    _loadDismissed();
    _locate();
  }

  Future<void> _loadDismissed() async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_dismissKey) ?? const <String>[];
      if (mounted) setState(() => _dismissed = list.toSet());
    } catch (_) {}
  }

  Future<void> _dismiss(String jobId) async {
    setState(() => _dismissed = {..._dismissed, jobId});
    try {
      final p = await SharedPreferences.getInstance();
      var list = _dismissed.toList();
      if (list.length > 200) list = list.sublist(list.length - 200);
      await p.setStringList(_dismissKey, list);
    } catch (_) {}
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    final pos = await HelperLocationService.instance.currentPosition();
    if (!mounted) return;
    setState(() {
      _pos = pos;
      _locating = false;
    });
  }

  /// Re-creates the query only when the position cell or services change,
  /// so the stream is not restarted on every rebuild.
  Stream<List<NearbyJob>> _streamFor(({double lat, double lng}) pos, Set<String> services) {
    final key = '${geohash(pos.lat, pos.lng, 6)}|${(services.toList()..sort()).join(',')}';
    if (_jobs == null || key != _jobsKey) {
      _jobsKey = key;
      _jobs = JobApi.instance.nearbyOpenJobs(lat: pos.lat, lng: pos.lng, serviceIds: services);
    }
    return _jobs!;
  }

  // Never change the notifier during build (the dashboard badge listens to it).
  void _setCount(int n) {
    if (nearbyRequestCount.value == n) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => nearbyRequestCount.value = n);
  }

  Future<void> _refresh() async {
    _jobs = null;
    await _locate();
  }

  @override
  Widget build(BuildContext context) {
    final helper = context.watch<AuthProvider>().helper;
    final approved = helper?.isApproved ?? false;
    final services = <String>{
      for (final n in helper?.services ?? const <String>[])
        if (ServiceCatalog.lookup(n) != null) ServiceCatalog.lookup(n)!.id,
    };

    Widget message(String key, {bool retry = false}) => RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(children: [
        _Empty(text: tr(context, key)),
        if (retry)
          Center(child: TextButton(onPressed: _refresh, child: Text(tr(context, 'tryAgain')))),
      ]),
    );

    if (!approved) {
      _setCount(0);
      return message('kycForRequests');
    }
    if (services.isEmpty) {
      _setCount(0);
      return message('noServices');
    }
    if (_locating) return const Center(child: CircularProgressIndicator());
    final pos = _pos;
    if (pos == null) {
      _setCount(0);
      return message('noLocation', retry: true);
    }

    return StreamBuilder<Map<String, Pitch>>(
      stream: _pitches,
      builder: (context, pitchSnap) {
        final mine = pitchSnap.data ?? const <String, Pitch>{};
        return StreamBuilder<List<NearbyJob>>(
          stream: _streamFor(pos, services),
          builder: (context, snap) {
            if (snap.hasError) return message('kycForRequests', retry: true);
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final now = DateTime.now();
            final open = snap.data!
                .where((n) => n.job.pitchDeadline != null && n.job.pitchDeadline!.isAfter(now))
                .where((n) => !_dismissed.contains(n.job.id) || mine.containsKey(n.job.id))
                .toList()
              ..sort((a, b) {
                // Priced-by-me last; then soonest deadline first.
                final pa = mine[a.job.id]?.status == PitchStatus.active;
                final pb = mine[b.job.id]?.status == PitchStatus.active;
                if (pa != pb) return pa ? 1 : -1;
                return a.job.pitchDeadline!.compareTo(b.job.pitchDeadline!);
              });
            final fresh = open.where((n) => !mine.containsKey(n.job.id)).length;
            _setCount(fresh);
            return RefreshIndicator(
              onRefresh: _refresh,
              child: open.isEmpty
                  ? ListView(children: [_Empty(text: tr(context, widget.online ? 'noRequests' : 'offlineHint'))])
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                itemCount: open.length,
                itemBuilder: (_, i) => _InviteCard(
                  nearby: open[i],
                  myPitch: mine[open[i].job.id],
                  onDismiss: () => _dismiss(open[i].job.id),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InviteCard extends StatelessWidget {
  final NearbyJob nearby;
  final Pitch? myPitch;
  final VoidCallback onDismiss;
  const _InviteCard({required this.nearby, required this.myPitch, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final j = nearby.job;
    final sub = ServiceCatalog.byId(j.subcategoryId);
    final lang = langCode(context);
    final left = j.pitchDeadline?.difference(DateTime.now());
    final pitched = myPitch?.status == PitchStatus.active;

    return Dismissible(
      key: ValueKey(j.id),
      direction: myPitch != null ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(18)),
        child: Text(tr(context, 'notInterested'),
            style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w700)),
      ),
      onDismissed: (_) => onDismiss(),
      child: GestureDetector(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => RequestDetailScreen(nearby: nearby))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: pitched ? const Color(0xFFBBF7D0) : const Color(0xFFEDE9FE)),
            boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFF3E8FF), borderRadius: BorderRadius.circular(12)),
                child: Icon(sub?.icon ?? Icons.handyman_outlined, color: _purple, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sub?.name(lang) ?? j.serviceName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                  Text(
                    '${nearby.distanceKm.toStringAsFixed(1)} ${tr(context, 'away')}'
                        '${j.areaName.isNotEmpty ? ' · ${j.areaName}' : ''}',
                    style: const TextStyle(color: _muted, fontSize: 12.5),
                  ),
                ]),
              ),
              if (pitched)
                _chip('${tr(context, 'priceSent')} ₹${myPitch!.amount}', _green)
              else if (left != null && !left.isNegative)
                _chip('${tr(context, 'closesIn')} ${_fmtLeft(left)}', const Color(0xFFD97706)),
            ]),
            const SizedBox(height: 10),
            Text(j.description,
                maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF374151), height: 1.35)),
            const SizedBox(height: 10),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 16, color: j.slot.isNow ? const Color(0xFFDC2626) : _muted),
              const SizedBox(width: 4),
              Text(j.slot.isNow ? tr(context, 'now') : _slot(j.slot),
                  style: TextStyle(
                      fontSize: 12.5,
                      color: j.slot.isNow ? const Color(0xFFDC2626) : _muted,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              if (j.photoUrls.isNotEmpty) ...[
                const Icon(Icons.photo_outlined, size: 16, color: _muted),
                Text(' ${j.photoUrls.length}', style: const TextStyle(fontSize: 12.5, color: _muted)),
                const SizedBox(width: 10),
              ],
              if (j.audioUrl != null) const Icon(Icons.mic_none_rounded, size: 16, color: _muted),
            ]),
          ]),
        ),
      ),
    );
  }

  static String _fmtLeft(Duration d) =>
      d.inHours > 0 ? '${d.inHours}h ${d.inMinutes.remainder(60)}m' : '${d.inMinutes}m';

  static Widget _chip(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
    child: Text(t, style: TextStyle(fontSize: 11.5, color: c, fontWeight: FontWeight.w700)),
  );
}

String _slot(JobSlot s) =>
    '${DateFormat('EEE d MMM').format(s.start)}, ${DateFormat('h a').format(s.start)}–${DateFormat('h a').format(s.end)}';

// ─── My jobs / history ─────────────────────────────────────────────────────

class _BookingsTab extends StatelessWidget {
  final bool active;
  const _BookingsTab({required this.active});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Booking>>(
      stream: JobApi.instance.myBookings(asHelper: true),
      builder: (context, snap) {
        if (snap.hasError) return const _Empty(text: 'Could not load jobs.');
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final list = snap.data!.where((b) => b.isActive == active).toList();
        if (active) list.sort((a, b) => a.slot.start.compareTo(b.slot.start));
        if (list.isEmpty) return _Empty(text: tr(context, active ? 'noJobs' : 'noHistory'));
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          itemCount: list.length,
          itemBuilder: (_, i) => _BookingTile(booking: list[i]),
        );
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  final Booking booking;
  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final b = booking;
    final color = switch (b.status) {
      BookingStatus.completed => _green,
      BookingStatus.cancelled => const Color(0xFFDC2626),
      _ => _purple,
    };
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => HelperBookingScreen(bookingId: b.id))),
        title: Text(b.serviceName, style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        subtitle: Text(
          '${b.customerName.split(' ').first} · ${b.slot.isNow ? tr(context, 'now') : _slot(b.slot)}',
          style: const TextStyle(color: _muted),
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('₹${b.agreedAmount}', style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          Text(bookingStatusLabel(b.status), style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 60, 32, 32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.inbox_outlined, size: 44, color: Color(0xFF94A3B8)),
      const SizedBox(height: 10),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
    ]),
  );
}