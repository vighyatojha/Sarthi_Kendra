// lib/screens/notifications/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/smooth_route.dart';
import '../bookings/incoming_booking_detail.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().markAllNotificationsRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid    = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context, isDark)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverToBoxAdapter(
              child: _NotificationList(uid: uid, isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 8, right: 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? Colors.white : AppColors.textDarkLight, size: 20),
        ),
        Expanded(child: Text('Notifications', style: TextStyle(
          color:      isDark ? Colors.white : AppColors.textDarkLight,
          fontSize:   18, fontWeight: FontWeight.w700,
        ))),
        TextButton(
          onPressed: () => context.read<AuthProvider>().markAllNotificationsRead(),
          child: const Text('Mark all read',
              style: TextStyle(color: AppColors.brandPurple, fontSize: 13)),
        ),
      ]),
    );
  }
}

class _NotificationList extends StatelessWidget {
  final String uid;
  final bool   isDark;
  const _NotificationList({required this.uid, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return _emptyState();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .doc(uid)
          .collection('items')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(
                color: AppColors.brandPurple)),
          );
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return _emptyState();

        // Group by day
        final Map<String, List<QueryDocumentSnapshot>> grouped = {};
        for (final doc in docs) {
          final d  = doc.data() as Map<String, dynamic>;
          final ts = (d['createdAt'] as Timestamp?)?.toDate();
          final key = ts != null ? _dayKey(ts) : 'Earlier';
          grouped.putIfAbsent(key, () => []).add(doc);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: grouped.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
                child: Text(entry.key, style: TextStyle(
                  color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                  fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                )),
              ),
              ...entry.value.map((doc) => _NotifCard(
                doc: doc, isDark: isDark, uid: uid,
              )),
            ],
          )).toList(),
        );
      },
    );
  }

  String _dayKey(DateTime dt) {
    final now = DateTime.now();
    if (_sameDay(dt, now)) return 'TODAY';
    if (_sameDay(dt, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
    return DateFormat('EEEE, d MMM').format(dt).toUpperCase();
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _emptyState() => Padding(
    padding: const EdgeInsets.only(top: 100),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
          color:  AppColors.brandPurple.withOpacity(0.1),
          shape:  BoxShape.circle,
        ),
        child: const Icon(Icons.notifications_none_rounded,
            size: 34, color: AppColors.brandPurple),
      ),
      const SizedBox(height: 16),
      const Text('No notifications yet',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
              color: AppColors.textMidDark)),
      const SizedBox(height: 6),
      const Text('New bookings & updates will appear here',
          style: TextStyle(fontSize: 13, color: AppColors.textSoftDark)),
    ])),
  );
}

class _NotifCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool   isDark;
  final String uid;
  const _NotifCard({required this.doc, required this.isDark, required this.uid});

  @override
  Widget build(BuildContext context) {
    final d       = doc.data() as Map<String, dynamic>;
    final type    = (d['type'] as String?) ?? 'system';
    final title   = (d['title'] as String?) ?? '';
    final body    = (d['body']  as String?) ?? '';
    final isRead  = (d['read']  as bool?)   ?? false;
    final ts      = (d['createdAt'] as Timestamp?)?.toDate();
    final booking = d['bookingId'] as String?;

    final cfg = _cfgFor(type);

    return GestureDetector(
      onTap: () => _handleTap(context, type, booking, d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        isRead
              ? (isDark ? AppColors.cardDark : Colors.white)
              : cfg.bgColor.withOpacity(isDark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isRead
                ? (isDark ? AppColors.borderDark : AppColors.borderLight)
                : cfg.color.withOpacity(0.25),
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color:        cfg.color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 22),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   14, fontWeight: FontWeight.w700,
              ))),
              if (!isRead) Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: cfg.color, shape: BoxShape.circle),
              ),
            ]),
            const SizedBox(height: 4),
            Text(body, style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13, height: 1.4,
            )),
            const SizedBox(height: 6),
            Text(ts != null ? _timeAgo(ts) : '',
                style: TextStyle(
                  color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                  fontSize: 11,
                )),
          ])),
        ]),
      ),
    );
  }

  void _handleTap(BuildContext context, String type, String? bookingId,
      Map<String, dynamic> d) {
    // Mark read
    doc.reference.update({'read': true});

    // Show popup with notification detail
    showDialog(
      context: context,
      builder: (_) => _NotifDetailDialog(
        type:      type,
        title:     d['title'] ?? '',
        body:      d['body']  ?? '',
        bookingId: bookingId,
        isDark:    isDark,
        onAction: bookingId != null && type == 'new_booking'
            ? () {
          Navigator.pop(context);
          Navigator.push(context,
              SmoothRoute(page: IncomingBookingDetail(bookingId: bookingId)));
        }
            : null,
      ),
    );
  }

  _NotifCfg _cfgFor(String type) {
    switch (type) {
      case 'new_booking':
        return _NotifCfg(Icons.work_rounded,         AppColors.brandPurple,
            AppColors.brandPurple);
      case 'booking_cancelled':
        return _NotifCfg(Icons.cancel_rounded,       AppColors.danger,
            AppColors.danger);
      case 'payment_received':
        return _NotifCfg(Icons.account_balance_wallet_rounded, AppColors.success,
            AppColors.success);
      case 'booking_completed':
        return _NotifCfg(Icons.check_circle_rounded, AppColors.success,
            AppColors.success);
      case 'kyc_approved':
        return _NotifCfg(Icons.verified_rounded,     AppColors.success,
            AppColors.success);
      case 'kyc_rejected':
        return _NotifCfg(Icons.cancel_rounded,       AppColors.danger,
            AppColors.danger);
      default:
        return _NotifCfg(Icons.notifications_rounded, AppColors.cyanAccent,
            AppColors.cyanAccent);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return DateFormat('d MMM, h:mm a').format(dt);
  }
}

class _NotifCfg {
  final IconData icon;
  final Color    color, bgColor;
  const _NotifCfg(this.icon, this.color, this.bgColor);
}

// ── Popup dialog (size adapts to content length) ──────────────────────────────
class _NotifDetailDialog extends StatelessWidget {
  final String    type, title, body;
  final String?   bookingId;
  final bool      isDark;
  final VoidCallback? onAction;

  const _NotifDetailDialog({
    required this.type, required this.title, required this.body,
    required this.isDark, this.bookingId, this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(type);
    return Dialog(
      backgroundColor: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color:  color.withOpacity(0.12),
              shape:  BoxShape.circle,
            ),
            child: Icon(_iconFor(type), color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center,
              style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   17, fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 10),
          Text(body, textAlign: TextAlign.center,
              style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 14, height: 1.55,
              )),
          const SizedBox(height: 24),
          if (onAction != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('View Booking',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Close',
                  style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          ),
        ]),
      ),
    );
  }

  Color _colorFor(String t) {
    switch (t) {
      case 'new_booking':       return AppColors.brandPurple;
      case 'booking_cancelled': return AppColors.danger;
      case 'payment_received':  return AppColors.success;
      case 'kyc_approved':      return AppColors.success;
      case 'kyc_rejected':      return AppColors.danger;
      default:                  return AppColors.cyanAccent;
    }
  }

  IconData _iconFor(String t) {
    switch (t) {
      case 'new_booking':       return Icons.work_rounded;
      case 'booking_cancelled': return Icons.cancel_rounded;
      case 'payment_received':  return Icons.account_balance_wallet_rounded;
      case 'kyc_approved':      return Icons.verified_rounded;
      case 'kyc_rejected':      return Icons.cancel_rounded;
      default:                  return Icons.notifications_rounded;
    }
  }
}

// ── Bell icon widget with dot (use this in dashboard header) ──────────────────
class NotificationBell extends StatelessWidget {
  final bool isDark;
  const NotificationBell({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final count = context.watch<AuthProvider>().unreadCount;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        SmoothRoute(page: const NotificationsScreen()),
      ),
      child: Stack(children: [
        Icon(
          count > 0 ? Icons.notifications_rounded : Icons.notifications_outlined,
          color: Colors.white, size: 26,
        ),
        if (count > 0) Positioned(
          right: 0, top: 0,
          child: Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              color: AppColors.danger,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.gradientStart, width: 1.5,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}