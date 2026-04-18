// ================================================================
// lib/screens/notifications/notifications_screen.dart
// Enhanced — categorised, grouped, action-first, light theme
// ================================================================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../chat/helper_chat_screen.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

// ─── Design tokens (light-theme focused) ────────────────────────
const _kPurple   = Color(0xFF6B21E8);
const _kPurpleL  = Color(0xFFF5F0FF);
const _kRed      = Color(0xFFEF4444);
const _kGreen    = Color(0xFF10B981);
const _kAmber    = Color(0xFFF59E0B);
const _kCyan     = Color(0xFF06B6D4);
const _kBg       = Color(0xFFF6F5FA);
const _kCard     = Colors.white;
const _kBorder   = Color(0xFFEAE6F5);
const _kTxtDark  = Color(0xFF1A1A2E);
const _kTxtMid   = Color(0xFF64748B);
const _kTxtSoft  = Color(0xFF94A3B8);

// ─── Filter tabs ─────────────────────────────────────────────────
enum _Filter { all, urgent, messages, earnings, alerts }

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  _Filter _filter = _Filter.all;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Firebase helpers ─────────────────────────────────────────
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';
  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('notifications/$_uid');

  Future<void> _markAllRead() async {
    if (_uid.isEmpty) return;
    try {
      final snap = await _ref.get();
      if (!snap.exists) return;
      final raw = Map<String, dynamic>.from(snap.value as Map);
      final updates = <String, dynamic>{};
      for (final k in raw.keys) {
        final item = Map<String, dynamic>.from(raw[k] as Map);
        if (item['read'] != true) updates['$k/read'] = true;
      }
      if (updates.isNotEmpty) await _ref.update(updates);
      if (mounted) context.read<AuthProvider>().markAllNotificationsRead();
    } catch (e) {
      debugPrint('markAllRead: $e');
    }
  }

  Future<void> _delete(String key) async {
    try {
      await _ref.child(key).remove();
    } catch (_) {}
  }

  Future<void> _clearAll(bool hi) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hi ? 'सभी साफ़ करें?' : 'Clear All?',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTxtDark)),
        content: Text(
            hi ? 'सभी नोटिफिकेशन हटा दी जाएंगी।' : 'All notifications will be removed.',
            style: const TextStyle(fontSize: 13, color: _kTxtMid)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(hi ? 'रद्द' : 'Cancel',
                  style: const TextStyle(color: _kTxtMid, fontSize: 13))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9)),
            child: Text(hi ? 'हाँ, साफ़ करें' : 'Clear All',
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _ref.remove();
      } catch (_) {}
    }
  }

  // ── Rating flow (3-second delay) ─────────────────────────────
  void _openRatingFlow(_NotifEntry entry, bool hi) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(hi ? '3 सेकंड में रेटिंग खुलेगी…' : 'Opening rating in 3 sec…',
          style: const TextStyle(fontSize: 13)),
      duration: const Duration(seconds: 3),
      backgroundColor: _kPurple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: _kCard,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _RatingSheet(entry: entry, hi: hi, uid: _uid),
      );
    });
  }

  // ── Navigation handler ───────────────────────────────────────
  void _handleAction(_NotifEntry e, String action, bool hi) {
    // ── Check isMessage FIRST (covers all type string variants) ──
    if (e.isMessage) {
      final customerId = e.data['customer_id'] as String?;
      final jobId = e.data['job_id'] as String?;
      final resolvedId = customerId ?? e.senderKey;

      debugPrint(
          '[Nav] → HelperChatScreen | customer_id=$resolvedId | job_id=$jobId | senderName=${e
              .senderName}');

      // Direct push — bypasses named route system completely
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) {
            // Pass args via settings so the screen can read ModalRoute.of(ctx)!.settings.arguments
            return const HelperChatScreen();
          },
          settings: RouteSettings(
            name: '/helper_chat',
            arguments: {
              'customer_id': resolvedId,
              'job_id': jobId ?? '',
              'sender_name': e.senderName,
            },
          ),
        ),
      );

      switch (e.type) {
        case 'rating':
          _openRatingFlow(e, hi);
          return;
        case 'job_new':
        case 'job_urgent':
        case 'booking_new':
          Navigator.pushNamed(context, '/job_detail',
              arguments: {'job_id': e.data['job_id'], 'action': action});
          return;
        case 'payment':
        case 'earnings':
          Navigator.pushNamed(context, '/earnings');
          return;
        case 'location':
          Navigator.pushNamed(context, '/map');
          return;
        case 'kyc':
        case 'document':
        case 'alert':
          Navigator.pushNamed(context, '/action_required',
              arguments: {'type': e.type});
          return;
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hi = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: _kBg,
      body: FadeTransition(
        opacity: _fade,
        child: Column(children: [
          _buildHeader(context, hi),
          Expanded(child: _buildList(hi)),
        ]),
      ),
    );
  }

  // ── Curved header card ───────────────────────────────────────
  Widget _buildHeader(BuildContext context, bool hi) {
    const tabs = [
      (_Filter.all,      'All',      'सभी',   Icons.apps_rounded),
      (_Filter.messages, 'Messages', 'संदेश', Icons.chat_bubble_rounded),
      (_Filter.earnings, 'Earnings', 'कमाई',  Icons.wallet_rounded),
      (_Filter.alerts,   'Alerts',   'अलर्ट', Icons.warning_rounded),
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32)),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E0545), Color(0xFF4C1D95), _kPurple],
          ),
        ),
        child: Column(children: [
          // ── Top row ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 4,
                left: 6,
                right: 10),
            child: Row(children: [
              IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 17)),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hi ? 'नोटिफिकेशन' : 'Notifications',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4)),
                      const SizedBox(height: 2),
                      StreamBuilder<DatabaseEvent>(
                        stream: FirebaseDatabase.instance
                            .ref('notifications/$_uid')
                            .orderByChild('read')
                            .equalTo(false)
                            .onValue,
                        builder: (_, snap) {
                          final count = snap.hasData &&
                              snap.data!.snapshot.value != null
                              ? (snap.data!.snapshot.value as Map).length
                              : 0;
                          return Row(children: [
                            if (count > 0) ...[
                              Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 5),
                                  decoration: const BoxDecoration(
                                      color: _kAmber,
                                      shape: BoxShape.circle)),
                            ],
                            Text(
                              count > 0
                                  ? (hi
                                  ? '$count अपठित'
                                  : '$count unread')
                                  : (hi
                                  ? 'सब पढ़ लिए गए ✓'
                                  : 'All caught up ✓'),
                              style: TextStyle(
                                  color: count > 0
                                      ? _kAmber
                                      : Colors.white.withOpacity(0.55),
                                  fontSize: 11,
                                  fontWeight: count > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400),
                            ),
                          ]);
                        },
                      ),
                    ]),
              ),
              // Settings
              _HdrBtn(
                  icon: Icons.tune_rounded,
                  onTap: () => _showSettings(hi)),
              const SizedBox(width: 4),
              // Clear all
              _HdrBtn(
                  icon: Icons.delete_sweep_rounded,
                  onTap: () => _clearAll(hi)),
            ]),
          ),

          // ── Filter chips (inside gradient) ──────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tabs.map((t) {
                  final active = _filter == t.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = t.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: active
                                ? Colors.transparent
                                : Colors.white.withOpacity(0.2),
                            width: 1),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(t.$4,
                                size: 13,
                                color: active
                                    ? _kPurple
                                    : Colors.white.withOpacity(0.8)),
                            const SizedBox(width: 6),
                            Text(hi ? t.$3 : t.$2,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: active
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: active
                                        ? _kPurple
                                        : Colors.white
                                        .withOpacity(0.9))),
                          ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ]),
      ),
    );
  }


  // ── Main list ────────────────────────────────────────────────
  Widget _buildList(bool hi) {
    if (_uid.isEmpty) return _EmptyState(hi: hi);
    return StreamBuilder<DatabaseEvent>(
      stream: _ref.orderByChild('timestamp').onValue,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  color: _kPurple, strokeWidth: 2.5));
        }
        if (!snap.hasData || snap.data!.snapshot.value == null) {
          return _EmptyState(hi: hi);
        }

        final raw = Map<String, dynamic>.from(snap.data!.snapshot.value as Map);
        final all = raw.entries.map((e) {
          return _NotifEntry(
              key: e.key,
              data: Map<String, dynamic>.from(e.value as Map));
        }).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

        if (all.isEmpty) return _EmptyState(hi: hi);
        final widgets = _buildGrouped(all, hi);
        if (widgets.isEmpty) return _EmptyState(hi: hi);

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
          itemCount: widgets.length,
          itemBuilder: (_, i) => widgets[i],
        );
      },
    );
  }

  // ── Grouped sections builder ─────────────────────────────────
  List<Widget> _buildGrouped(List<_NotifEntry> all, bool hi) {
    // Apply filter
    List<_NotifEntry> filtered;
    switch (_filter) {
      case _Filter.urgent:
        filtered = all.where((e) => e.isUrgent).toList();
        break;
      case _Filter.messages:
        filtered = all.where((e) => e.isMessage).toList();
        break;
      case _Filter.earnings:
        filtered = all.where((e) => e.isEarning).toList();
        break;
      case _Filter.alerts:
        filtered = all.where((e) => e.isAlert).toList();
        break;
      default:
        filtered = all;
    }

    final out = <Widget>[];
    final show = _filter == _Filter.all;




    // ── 2. MESSAGES (grouped by sender, works with any message type string) ──
    if (show || _filter == _Filter.messages) {
      final msgs = filtered.where((e) => e.isMessage).toList();
      if (msgs.isNotEmpty) {
        final grouped = <String, List<_NotifEntry>>{};
        for (final m in msgs) {
          grouped.putIfAbsent(m.senderKey, () => []).add(m);
        }
        // Sort groups by latest timestamp
        final sortedGroups = grouped.entries.toList()
          ..sort((a, b) {
            final ta = a.value.map((e) => e.timestamp).reduce((x, y) => x > y ? x : y);
            final tb = b.value.map((e) => e.timestamp).reduce((x, y) => x > y ? x : y);
            return tb.compareTo(ta);
          });

        out.add(_SectionLabel(
            icon: Icons.chat_bubble_rounded,
            label: hi ? 'संदेश' : 'Messages',
            color: _kPurple));
        for (final g in sortedGroups) {
          final sorted = g.value..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          out.add(_MessageGroupCard(
              entries: sorted,
              hi: hi,
              onTap: () => _handleAction(sorted.first, 'tap', hi),
              onDismiss: () {
                for (final e in sorted) _delete(e.key);
              }));
        }
      }
    }

    // ── 3. EARNINGS ────────────────────────────────────────────
    if (show || _filter == _Filter.earnings) {
      final list = filtered.where((e) => e.isEarning).toList();
      if (list.isNotEmpty) {
        out.add(_SectionLabel(
            icon: Icons.account_balance_wallet_rounded,
            label: hi ? 'कमाई' : 'Earnings',
            color: _kAmber));
        for (final e in list) {
          out.add(_StandardCard(
              entry: e,
              hi: hi,
              onDelete: () => _delete(e.key),
              onTap: () => _handleAction(e, 'tap', hi)));
        }
      }
    }

    // ── 4. LOCATION OPPORTUNITIES (all only) ──────────────────
    if (show) {
      final list = filtered.where((e) => e.type == 'location').toList();
      if (list.isNotEmpty) {
        out.add(_SectionLabel(
            icon: Icons.location_on_rounded,
            label: hi ? 'पास की मांग' : 'Nearby Demand',
            color: _kCyan));
        for (final e in list) {
          out.add(_StandardCard(
              entry: e,
              hi: hi,
              onDelete: () => _delete(e.key),
              onTap: () => _handleAction(e, 'tap', hi)));
        }
      }
    }

    // ── 5. JOB HISTORY (all only) ─────────────────────────────
    if (show) {
      final list = filtered.where((e) => e.isHistory).toList();
      if (list.isNotEmpty) {
        out.add(_SectionLabel(
            icon: Icons.history_rounded,
            label: hi ? 'जॉब इतिहास' : 'Job History',
            color: _kTxtMid));
        for (final e in list) {
          out.add(_StandardCard(
              entry: e,
              hi: hi,
              onDelete: () => _delete(e.key),
              onTap: () => _handleAction(e, 'tap', hi)));
        }
      }
    }

    // ── 6. SYSTEM ALERTS ───────────────────────────────────────
    if (show || _filter == _Filter.alerts) {
      final list = filtered.where((e) => e.isAlert).toList();
      if (list.isNotEmpty) {
        out.add(_SectionLabel(
            icon: Icons.warning_amber_rounded,
            label: hi ? 'सिस्टम अलर्ट' : 'System Alerts',
            color: _kRed));
        for (final e in list) {
          out.add(_AlertCard(
              entry: e,
              hi: hi,
              onTap: () => _handleAction(e, 'tap', hi)));
        }
      }
    }

    // ── 7. GENERAL FALLBACK (unknown / future types) ───────────
    if (show) {
      final list = filtered.where((e) => e.isGeneral).toList();
      if (list.isNotEmpty) {
        out.add(_SectionLabel(
            icon: Icons.notifications_rounded,
            label: hi ? 'अन्य' : 'General',
            color: _kTxtMid));
        for (final e in list) {
          out.add(_StandardCard(
              entry: e,
              hi: hi,
              onDelete: () => _delete(e.key),
              onTap: () => _handleAction(e, 'tap', hi)));
        }
      }
    }

    return out;
  }

  // ── Settings sheet ───────────────────────────────────────────
  void _showSettings(bool hi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SettingsSheet(hi: hi),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// DATA MODEL
// ════════════════════════════════════════════════════════════════
class _NotifEntry {
  final String key;
  final Map<String, dynamic> data;
  const _NotifEntry({required this.key, required this.data});

  String get type       => (data['type'] as String?) ?? 'general';
  int    get timestamp  => (data['timestamp'] as int?) ?? 0;
  bool   get isRead     => (data['read'] as bool?) ?? false;

  // ── Detects message notifications regardless of type string used ──
  bool get isMessage => type == 'message'      ||
      type == 'chat'          ||
      type == 'chat_message'  ||
      type == 'new_message'   ||
      ((data['title'] as String?) ?? '')
          .toLowerCase()
          .startsWith('message from');

  // ── Grouping key: customer_id → customer_name → parsed from title ──
  String get senderKey {
    final cid = data['customer_id'] as String?;
    if (cid != null && cid.isNotEmpty) return cid;
    final name = data['customer_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final title = (data['title'] as String?) ?? '';
    if (title.toLowerCase().startsWith('message from ')) {
      return title.substring('message from '.length).trim();
    }
    return key;
  }

  // ── Display name: customer_name → parsed from title → fallback ──
  String get senderName {
    final name = data['customer_name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final title = (data['title'] as String?) ?? '';
    if (title.toLowerCase().startsWith('message from ')) {
      return title.substring('message from '.length).trim();
    }
    return 'Customer';
  }

  bool get isUrgent  => type == 'job_new'       ||
      type == 'job_urgent'     ||
      type == 'booking_new';          // ← old alias

  bool get isEarning => type == 'payment'        ||
      type == 'earnings';

  bool get isHistory => type == 'job_completed'  ||
      type == 'job_cancelled'  ||
      type == 'rating'         ||
      type == 'booking_accepted' ||   // ← old alias
      type == 'booking_cancelled';    // ← old alias

  bool get isAlert   => type == 'alert'          ||
      type == 'kyc'            ||
      type == 'document';

  // Catches anything that doesn't belong to a specific section
  bool get isGeneral => !isUrgent && !isEarning && !isHistory &&
      !isAlert   && !isMessage  && type != 'location';
}

// ════════════════════════════════════════════════════════════════
// SECTION LABEL
// ════════════════════════════════════════════════════════════════
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionLabel(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: 0.9)),
        const SizedBox(width: 8),
        Expanded(
            child: Divider(color: color.withOpacity(0.2), thickness: 1)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// HEADER ICON BUTTON
// ════════════════════════════════════════════════════════════════
class _HdrBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HdrBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(7),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 16)),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// URGENT CARD  (job_new / job_urgent)
// ════════════════════════════════════════════════════════════════
class _UrgentCard extends StatelessWidget {
  final _NotifEntry entry;
  final bool hi;
  final VoidCallback onDelete;
  final void Function(String) onAction;

  const _UrgentCard({
    required this.entry,
    required this.hi,
    required this.onDelete,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final d      = entry.data;
    final title  = (d['title']    as String?) ?? _defTitle(entry.type, hi);
    final body   = (d['body']     as String?) ?? '';
    final amount = (d['amount']   as num?);
    final dist   = (d['distance'] as String?) ?? '';

    return Dismissible(
      key: ValueKey(entry.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: _SwipeBg(),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kRed.withOpacity(0.28), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: _kRed.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top banner ──────────────────────────────────────
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16)),
            ),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: _kRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.flash_on_rounded,
                    color: _kRed, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kTxtDark)),
                      if (body.isNotEmpty)
                        Text(body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: _kTxtMid)),
                    ]),
              ),
              if (!entry.isRead)
                Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: _kRed, shape: BoxShape.circle)),
            ]),
          ),

          // ── Meta badges ─────────────────────────────────────
          if (amount != null || dist.isNotEmpty)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                if (amount != null)
                  _Badge(
                      icon: Icons.currency_rupee,
                      label: amount.toStringAsFixed(0),
                      color: _kGreen),
                if (dist.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  _Badge(
                      icon: Icons.near_me_rounded,
                      label: dist,
                      color: _kCyan),
                ],
                const Spacer(),
                Text(_ago(entry.timestamp, hi),
                    style: const TextStyle(
                        fontSize: 10, color: _kTxtSoft)),
              ]),
            ),

          // ── Action row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              Expanded(
                  child: _ActBtn(
                      label: hi ? 'स्वीकार' : 'Accept',
                      color: _kGreen,
                      icon: Icons.check_rounded,
                      onTap: () => onAction('accept'))),
              const SizedBox(width: 8),
              Expanded(
                  child: _ActBtn(
                      label: hi ? 'अस्वीकार' : 'Decline',
                      color: _kRed,
                      icon: Icons.close_rounded,
                      filled: false,
                      onTap: () => onAction('decline'))),
              const SizedBox(width: 8),
              _ActBtn(
                  label: hi ? 'देखें' : 'Details',
                  color: _kPurple,
                  icon: Icons.open_in_new_rounded,
                  filled: false,
                  onTap: () => onAction('view')),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// MESSAGE GROUP CARD  (WhatsApp-style)
// ════════════════════════════════════════════════════════════════
class _MessageGroupCard extends StatelessWidget {
  final List<_NotifEntry> entries;
  final bool hi;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _MessageGroupCard({
    required this.entries,
    required this.hi,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final first      = entries.first;
    final name       = first.senderName;                          // uses new helper
    final lastMsg    = (first.data['body'] as String?) ?? '';
    final avatarUrl  = first.data['customer_avatar'] as String?;
    final unread     = entries.where((e) => !e.isRead).length;
    final total      = entries.length;                            // for count badge

    return Dismissible(
      key: ValueKey('grp_${first.data['customer_id'] ?? first.key}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: _SwipeBg(
          label: hi ? 'पढ़ा' : 'Read',
          icon: Icons.mark_chat_read_rounded),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: unread > 0
                    ? _kPurple.withOpacity(0.22)
                    : _kBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            // Avatar + unread badge
            Stack(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _kPurpleL,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: _kPurple,
                        fontWeight: FontWeight.w700,
                        fontSize: 15))
                    : null,
              ),
              if (total > 1)
                Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: unread > 0 ? _kPurple : _kTxtMid,
                      shape: BoxShape.circle),
                  child: Text(total > 2 ? '3+' : '$total',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _kTxtDark))),
                      Text(_ago(first.timestamp, hi),
                          style: const TextStyle(
                              fontSize: 10, color: _kTxtSoft)),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.chat_bubble_outline_rounded,
                          size: 11, color: _kTxtSoft),
                      const SizedBox(width: 4),
                      Expanded(
                          child: Text(lastMsg,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: unread > 0
                                      ? _kTxtDark
                                      : _kTxtMid,
                                  fontWeight: unread > 0
                                      ? FontWeight.w500
                                      : FontWeight.w400))),
                    ]),
                  ]),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: _kTxtSoft, size: 18),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STANDARD CARD  (earnings / location / job history)
// ════════════════════════════════════════════════════════════════
class _StandardCard extends StatelessWidget {
  final _NotifEntry entry;
  final bool hi;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _StandardCard({
    required this.entry,
    required this.hi,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final type   = entry.type;
    final title  = (entry.data['title'] as String?) ?? _defTitle(type, hi);
    final body   = (entry.data['body']  as String?) ?? '';
    final amount = entry.data['amount'] as num?;
    final stars  = entry.data['rating'] as int?;
    final (ico, col) = _typeInfo(type);

    return Dismissible(
      key: ValueKey(entry.key),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: _SwipeBg(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: entry.isRead
                ? _kCard
                : col.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: entry.isRead
                    ? _kBorder
                    : col.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                    color: col.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(ico, color: col, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kTxtDark))),
                      if (!entry.isRead)
                        Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                                color: col,
                                shape: BoxShape.circle)),
                    ]),
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: _kTxtMid,
                              height: 1.4)),
                    ],
                    // Amount row
                    if (amount != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.currency_rupee,
                            size: 12, color: _kGreen),
                        Text(amount.toStringAsFixed(0),
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _kGreen)),
                      ]),
                    ],
                    // Star rating display
                    if (stars != null) ...[
                      const SizedBox(height: 4),
                      Row(children: List.generate(
                          5,
                              (i) => Icon(
                            i < stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 14,
                            color: _kAmber,
                          ))),
                    ],
                    const SizedBox(height: 4),
                    Text(_ago(entry.timestamp, hi),
                        style: const TextStyle(
                            fontSize: 10, color: _kTxtSoft)),
                  ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: _kTxtSoft, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ALERT CARD  (persistent – no dismiss)
// ════════════════════════════════════════════════════════════════
class _AlertCard extends StatelessWidget {
  final _NotifEntry entry;
  final bool hi;
  final VoidCallback onTap;

  const _AlertCard(
      {required this.entry, required this.hi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (entry.data['title'] as String?) ??
        (hi ? 'कार्रवाई जरूरी' : 'Action Required');
    final body = (entry.data['body'] as String?) ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8F8),
          borderRadius: BorderRadius.circular(16),
          border:
          Border.all(color: _kRed.withOpacity(0.28), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: _kRed.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(children: [
          Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.warning_amber_rounded,
                  color: _kRed, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kTxtDark)),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(body,
                        style: const TextStyle(
                            fontSize: 12, color: _kTxtMid, height: 1.4)),
                  ],
                  const SizedBox(height: 4),
                  Text(_ago(entry.timestamp, hi),
                      style: const TextStyle(fontSize: 10, color: _kTxtSoft)),
                ]),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(9)),
            child: Text(hi ? 'ठीक करें' : 'Fix Now',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// RATING BOTTOM SHEET
// ════════════════════════════════════════════════════════════════
class _RatingSheet extends StatefulWidget {
  final _NotifEntry entry;
  final bool hi;
  final String uid;
  const _RatingSheet(
      {required this.entry, required this.hi, required this.uid});
  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int  _stars = 0;
  bool _submitting = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _submitting = true);
    try {
      final cid = (widget.entry.data['customer_id'] as String?) ?? '';
      final jid = (widget.entry.data['job_id']      as String?) ?? '';
      // Save to ratings/{helper_uid}/{customer_id}
      await FirebaseDatabase.instance
          .ref('ratings/${widget.uid}/$cid')
          .set({
        'rating':      _stars,
        'comment':     _ctrl.text.trim(),
        'job_id':      jid,
        'customer_id': cid,
        'timestamp':   DateTime.now().millisecondsSinceEpoch,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.hi
              ? 'रेटिंग सबमिट हो गई!'
              : 'Rating submitted successfully!',
              style: const TextStyle(fontSize: 13)),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (_) {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi   = widget.hi;
    final name = (widget.entry.data['customer_name'] as String?)
        ?? 'Customer';

    return Padding(
      padding:
      EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _kBorder,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          // Title
          Text(hi ? 'ग्राहक को रेट करें' : 'Rate this Customer',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _kTxtDark)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(fontSize: 12, color: _kTxtMid)),
          const SizedBox(height: 22),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
                  (i) => GestureDetector(
                onTap: () => setState(() => _stars = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    i < _stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 36,
                    color:
                    i < _stars ? _kAmber : _kBorder,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // Comment
          TextField(
            controller: _ctrl,
            maxLines: 2,
            style: const TextStyle(fontSize: 13),
            decoration: InputDecoration(
              hintText: hi
                  ? 'टिप्पणी (वैकल्पिक)'
                  : 'Add a comment (optional)',
              hintStyle: const TextStyle(
                  fontSize: 12, color: _kTxtSoft),
              filled: true,
              fillColor: _kBg,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),
          // Submit
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
              (_stars > 0 && !_submitting) ? _submit : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: _kPurple,
                  disabledBackgroundColor: _kBorder,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: _submitting
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(hi ? 'रेटिंग दें' : 'Submit Rating',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SETTINGS SHEET
// ════════════════════════════════════════════════════════════════
class _SettingsSheet extends StatefulWidget {
  final bool hi;
  const _SettingsSheet({required this.hi});
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _jobAlerts = true;
  bool _msgAlerts = true;

  @override
  Widget build(BuildContext context) {
    final hi = widget.hi;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text(hi ? 'नोटिफिकेशन सेटिंग' : 'Notification Settings',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTxtDark)),
        const SizedBox(height: 18),
        _ToggleRow(
            icon: Icons.work_rounded,
            color: _kPurple,
            title: hi ? 'जॉब अलर्ट' : 'Job Alerts',
            sub: hi ? 'नई जॉब की सूचना' : 'New job notifications',
            value: _jobAlerts,
            onChanged: (v) => setState(() => _jobAlerts = v)),
        const SizedBox(height: 10),
        _ToggleRow(
            icon: Icons.chat_bubble_rounded,
            color: _kCyan,
            title: hi ? 'संदेश अलर्ट' : 'Message Alerts',
            sub: hi ? 'ग्राहक संदेश' : 'Customer messages',
            value: _msgAlerts,
            onChanged: (v) => setState(() => _msgAlerts = v)),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: Text(hi ? 'सहेजें' : 'Save',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _kBg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _kTxtDark)),
                Text(sub,
                    style: const TextStyle(
                        fontSize: 11, color: _kTxtMid)),
              ]),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ════════════════════════════════════════════════════════════════

/// Swipe-to-dismiss background
class _SwipeBg extends StatelessWidget {
  final String? label;
  final IconData icon;
  const _SwipeBg(
      {this.label, this.icon = Icons.delete_rounded});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
          color: _kRed, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 20),
        if (label != null)
          Text(label!,
              style: const TextStyle(
                  color: Colors.white, fontSize: 10)),
      ]),
    );
  }
}

/// Coloured meta badge (amount / distance)
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Badge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

/// Action button (filled / outlined)
class _ActBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;
  const _ActBtn({
    required this.label,
    required this.color,
    required this.icon,
    this.filled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(10),
          border:
          filled ? null : Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 12,
                  color: filled ? Colors.white : color),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: filled ? Colors.white : color))),
            ]),
      ),
    );
  }
}

/// Empty state
class _EmptyState extends StatelessWidget {
  final bool hi;
  const _EmptyState({required this.hi});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
                color: _kPurple.withOpacity(0.08),
                shape: BoxShape.circle),
            child: const Icon(Icons.notifications_none_rounded,
                color: _kPurple, size: 34)),
        const SizedBox(height: 14),
        Text(
            hi ? 'कोई नोटिफिकेशन नहीं' : 'No notifications yet',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTxtDark)),
        const SizedBox(height: 5),
        Text(
            hi
                ? 'नई बुकिंग पर यहाँ सूचना आएगी'
                : 'New activity will appear here',
            style: const TextStyle(fontSize: 12, color: _kTxtMid)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// UTILITY FUNCTIONS
// ════════════════════════════════════════════════════════════════
String _ago(int ts, bool hi) {
  if (ts == 0) return '';
  final dt   = DateTime.fromMillisecondsSinceEpoch(ts);
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return hi ? 'अभी'                   : 'Just now';
  if (diff.inMinutes < 60) return hi ? '${diff.inMinutes} मिनट' : '${diff.inMinutes}m ago';
  if (diff.inHours   < 24) return hi ? '${diff.inHours} घंटे'   : '${diff.inHours}h ago';
  if (diff.inDays    < 7)  return hi ? '${diff.inDays} दिन'     : '${diff.inDays}d ago';
  return DateFormat('d MMM').format(dt);
}

String _defTitle(String type, bool hi) {
  switch (type) {
    case 'job_new':
    case 'booking_new':       return hi ? 'नई जॉब रिक्वेस्ट'  : 'New Job Request';
    case 'job_urgent':        return hi ? 'अर्जेंट जॉब'        : 'Urgent Job';
    case 'job_completed':
    case 'booking_accepted':  return hi ? 'जॉब पूरी हुई'        : 'Job Completed';
    case 'job_cancelled':
    case 'booking_cancelled': return hi ? 'जॉब रद्द हुई'        : 'Job Cancelled';
    case 'rating':            return hi ? 'रेटिंग मिली'         : 'Rating Received';
    case 'payment':           return hi ? 'भुगतान मिला'         : 'Payment Credited';
    case 'earnings':          return hi ? 'साप्ताहिक कमाई'      : 'Weekly Earnings';
    case 'location':          return hi ? 'पास में मांग'         : 'High Demand Nearby';
    case 'kyc':               return hi ? 'KYC अपडेट'           : 'KYC Update';
    case 'document':          return hi ? 'दस्तावेज़ जरूरी'      : 'Document Required';
    case 'alert':             return hi ? 'सिस्टम अलर्ट'        : 'System Alert';
    default:                  return hi ? 'सूचना'               : 'Notification';
  }
}

(IconData, Color) _typeInfo(String type) {
  switch (type) {
    case 'job_new':
    case 'booking_new':       return (Icons.work_rounded,                   _kPurple);
    case 'job_urgent':        return (Icons.flash_on_rounded,               _kRed);
    case 'job_completed':
    case 'booking_accepted':  return (Icons.check_circle_rounded,           _kGreen);
    case 'job_cancelled':
    case 'booking_cancelled': return (Icons.cancel_rounded,                 _kRed);
    case 'rating':            return (Icons.star_rounded,                   _kAmber);
    case 'payment':           return (Icons.account_balance_wallet_rounded, _kGreen);
    case 'earnings':          return (Icons.trending_up_rounded,            _kAmber);
    case 'location':          return (Icons.location_on_rounded,            _kCyan);
    case 'kyc':               return (Icons.verified_user_rounded,          _kCyan);
    case 'document':          return (Icons.description_rounded,            _kAmber);
    case 'alert':             return (Icons.warning_amber_rounded,          _kRed);
    default:                  return (Icons.notifications_rounded,          _kPurple);
  }
}