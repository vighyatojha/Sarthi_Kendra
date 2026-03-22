// lib/screens/notifications/notifications_screen.dart
// Uses Firebase Realtime Database for real-time delivery
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {

  @override
  void initState() {
    super.initState();
    // Mark all as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _markAllRead());
  }

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  DatabaseReference get _ref =>
      FirebaseDatabase.instance.ref('notifications/$_uid');

  Future<void> _markAllRead() async {
    if (_uid.isEmpty) return;
    try {
      final snap = await _ref.get();
      if (!snap.exists) return;
      final data = Map<String, dynamic>.from(snap.value as Map);
      final updates = <String, dynamic>{};
      for (final key in data.keys) {
        final item = Map<String, dynamic>.from(data[key] as Map);
        if (item['read'] != true) {
          updates['$key/read'] = true;
        }
      }
      if (updates.isNotEmpty) await _ref.update(updates);
      // Also update unread count in provider
      if (mounted) context.read<AuthProvider>().markAllNotificationsRead();
    } catch (e) { debugPrint('markAllRead: $e'); }
  }

  Future<void> _deleteNotification(String key) async {
    try { await _ref.child(key).remove(); } catch (_) {}
  }

  Future<void> _clearAll() async {
    final hi = context.read<LanguageProvider>().isHindi;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(hi ? 'सभी साफ़ करें?' : 'Clear all?'),
        content: Text(hi
            ? 'सभी नोटिफिकेशन हटा दी जाएंगी।'
            : 'All notifications will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(hi ? 'रद्द' : 'Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: Text(hi ? 'हाँ, साफ़ करें' : 'Clear All')),
        ],
      ),
    );
    if (confirm == true) {
      try { await _ref.remove(); } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hi     = context.watch<LanguageProvider>().isHindi;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF2F3F8),
      body: Column(children: [
        _buildHeader(context, isDark, hi),
        Expanded(child: _uid.isEmpty
            ? _empty(isDark, hi)
            : StreamBuilder<DatabaseEvent>(
          stream: _ref.orderByChild('timestamp').onValue,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(
                  color: AppColors.brandPurple));
            }
            if (!snap.hasData || snap.data!.snapshot.value == null) {
              return _empty(isDark, hi);
            }

            final raw  = Map<String, dynamic>.from(
                snap.data!.snapshot.value as Map);
            // Sort by timestamp descending
            final entries = raw.entries.toList()
              ..sort((a, b) {
                final ta = (Map<String, dynamic>.from(a.value as Map)['timestamp'] ?? 0) as int;
                final tb = (Map<String, dynamic>.from(b.value as Map)['timestamp'] ?? 0) as int;
                return tb.compareTo(ta);
              });

            if (entries.isEmpty) return _empty(isDark, hi);

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final key  = entries[i].key;
                final data = Map<String, dynamic>.from(entries[i].value as Map);
                return _NotifCard(
                  notifKey: key, data: data,
                  isDark:   isDark, hi: hi,
                  onDelete: () => _deleteNotification(key),
                );
              },
            );
          },
        ),
        ),
      ]),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool hi) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 8, right: 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF2E0754), Color(0xFF5B21B6), AppColors.brandPurple],
        ),
      ),
      child: Row(children: [
        IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20)),
        Expanded(child: Text(hi ? 'नोटिफिकेशन' : 'Notifications',
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
        IconButton(
          onPressed: _clearAll,
          icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.delete_sweep_rounded,
                  color: Colors.white, size: 18)),
        ),
      ]),
    );
  }

  Widget _empty(bool isDark, bool hi) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color:  AppColors.brandPurple.withOpacity(0.1),
              shape:  BoxShape.circle),
          child: const Icon(Icons.notifications_none_rounded,
              color: AppColors.brandPurple, size: 38)),
      const SizedBox(height: 16),
      Text(hi ? 'कोई नोटिफिकेशन नहीं' : 'No notifications yet',
          style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(hi ? 'नई बुकिंग पर यहाँ सूचना आएगी' : 'New booking alerts will appear here',
          style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13)),
    ]));
  }
}

class _NotifCard extends StatelessWidget {
  final String notifKey; final Map<String, dynamic> data;
  final bool isDark, hi; final VoidCallback onDelete;
  const _NotifCard({
    required this.notifKey, required this.data,
    required this.isDark, required this.hi, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final type    = (data['type']    as String?) ?? 'general';
    final title   = (data['title']   as String?) ?? '';
    final body    = (data['body']    as String?) ?? '';
    final read    = (data['read']    as bool?)   ?? false;
    final ts      = (data['timestamp'] as int?);
    final dt      = ts != null
        ? DateTime.fromMillisecondsSinceEpoch(ts) : null;

    final (icon, color) = _typeInfo(type);

    return Dismissible(
      key: ValueKey(notifKey),
      direction:       DismissDirection.endToStart,
      onDismissed:     (_) => onDelete(),
      background: Container(
          alignment: Alignment.centerRight,
          padding:   const EdgeInsets.only(right: 20),
          margin:    const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
              color:        AppColors.danger,
              borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark
              ? (read ? AppColors.cardDark : AppColors.cardDark.withOpacity(0.9))
              : (read ? Colors.white : const Color(0xFFF5F0FF)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: read
                  ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                  : AppColors.brandPurple.withOpacity(0.25)),
          boxShadow: [BoxShadow(
              color: isDark ? Colors.transparent : Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                  color:        color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title.isNotEmpty ? title : _defaultTitle(type, hi),
                  style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontSize:   14, fontWeight: FontWeight.w700))),
              if (!read)
                Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.brandPurple, shape: BoxShape.circle)),
            ]),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(body, style: TextStyle(
                  color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                  fontSize: 13, height: 1.4)),
            ],
            if (dt != null) ...[
              const SizedBox(height: 6),
              Text(_timeAgo(dt, hi), style: TextStyle(
                  color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                  fontSize: 11)),
            ],
          ])),
        ]),
      ),
    );
  }

  String _defaultTitle(String type, bool hi) {
    switch (type) {
      case 'booking_new':      return hi ? 'नई बुकिंग' : 'New Booking';
      case 'booking_accepted': return hi ? 'बुकिंग स्वीकृत' : 'Booking Accepted';
      case 'payment':          return hi ? 'भुगतान प्राप्त' : 'Payment Received';
      case 'kyc':              return hi ? 'KYC अपडेट' : 'KYC Update';
      default:                 return hi ? 'सूचना' : 'Notification';
    }
  }

  (IconData, Color) _typeInfo(String type) {
    switch (type) {
      case 'booking_new':      return (Icons.work_rounded,            AppColors.brandPurple);
      case 'booking_accepted': return (Icons.check_circle_rounded,    AppColors.success);
      case 'payment':          return (Icons.wallet_rounded,          AppColors.warning);
      case 'kyc':              return (Icons.verified_user_rounded,   AppColors.cyanAccent);
      case 'alert':            return (Icons.warning_rounded,         AppColors.danger);
      default:                 return (Icons.notifications_rounded,   AppColors.brandPurple);
    }
  }

  String _timeAgo(DateTime dt, bool hi) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return hi ? 'अभी' : 'Just now';
    if (diff.inMinutes < 60)  return hi ? '${diff.inMinutes} मिनट पहले' : '${diff.inMinutes}m ago';
    if (diff.inHours   < 24)  return hi ? '${diff.inHours} घंटे पहले'   : '${diff.inHours}h ago';
    if (diff.inDays    < 7)   return hi ? '${diff.inDays} दिन पहले'     : '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt);
  }
}