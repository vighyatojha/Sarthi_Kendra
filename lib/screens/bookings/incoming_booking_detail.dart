

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/booking_chat_service.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class IncomingBookingDetail extends StatefulWidget {
  final String bookingId;
  const IncomingBookingDetail({super.key, required this.bookingId});

  @override
  State<IncomingBookingDetail> createState() => _IncomingBookingDetailState();
}

class _IncomingBookingDetailState extends State<IncomingBookingDetail>
    with TickerProviderStateMixin {

  // ── Timer state ───────────────────────────────────────────────
  // FIX 5: _timerActive is false until we confirm booking is within 2 hrs
  int    _secondsLeft = 60;
  Timer? _timer;
  bool   _timerActive = false;

  late final AnimationController _timerCtrl;
  late final Animation<double>   _timerAnim;

  // ── Action state ──────────────────────────────────────────────
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 60),
    );
    _timerAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _timerCtrl, curve: Curves.linear),
    );
    // FIX 5: Fetch booking once to decide if timer is needed
    _initTimerIfInstant();
  }

  /// FIX 5 — Only start the auto-decline countdown when scheduledAt is
  /// within 2 hours of now (instant booking).
  /// Future-scheduled bookings (e.g. booked for next week) get NO timer.
  /// FIX: Check booking status FIRST before starting timer.
  /// Prevents two timers running simultaneously (race condition).
  Future<void> _initTimerIfInstant() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();
      if (!mounted) return;

      final data   = doc.data() ?? {};
      final status = (data['status'] as String?) ?? '';

      // If already accepted or cancelled, no timer needed
      if (status == 'accepted' || status == 'cancelled') return;

      final scheduledAt = (data['scheduledAt'] as Timestamp?)?.toDate();
      final isInstant   = scheduledAt == null ||
          scheduledAt.difference(DateTime.now()).inMinutes <= 120;

      // Only start timer for genuine instant pending bookings
      if (!isInstant) return;

      if (mounted) {
        setState(() => _timerActive = true);
        _timerCtrl.forward();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          setState(() => _secondsLeft--);
          if (_secondsLeft <= 0) {
            _timer?.cancel();
            _autoDecline();
          }
        });
      }
    } catch (_) {
      // If fetch fails, no timer started — helper can still manually decide
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerCtrl.dispose();
    super.dispose();
  }

  // ── FIX 1: Auto-decline writes 'cancelled', not 'timeout' ────
  Future<void> _autoDecline() async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({
      'status':      'cancelled',
      'cancelledBy': 'auto',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  // ── FIX 1, 3, 6, 7: Accept ───────────────────────────────────
  // - Status → 'accepted' (not changed)
  // - scheduledAt is NOT touched — it was set by the customer at booking time
  // - confirmedAt written (FIX 7)
  // - Customer notification written in same batch (FIX 7)
  // - Only baseAmount shown (FIX 6, platform fee stays internal)
  Future<void> _accept(Map<String, dynamic> data) async {
    setState(() => _isAccepting = true);
    _timer?.cancel();

    final auth        = context.read<AuthProvider>();
    final helperName  = auth.helper?.name ?? '';
    final helperUid   = auth.helper?.uid  ?? '';
    final serviceName = (data['serviceName']  as String?) ?? 'Service';
    final userId      = (data['userId']       as String?) ?? '';
    final scheduledTs = data['scheduledAt']   as Timestamp?;
    final formatted   = scheduledTs != null
        ? DateFormat('d MMM yyyy, h:mm a')
        .format(scheduledTs.toDate().toLocal())
        : '';

    try {
      final db    = FirebaseFirestore.instance;
      final batch = db.batch();

      // 1. Update booking — DO NOT change scheduledAt (set by customer)
      batch.update(db.collection('bookings').doc(widget.bookingId), {
        'status':      'accepted',
        'helperId':    helperUid,
        'helperName':  helperName,
        'acceptedAt':  FieldValue.serverTimestamp(),
        'confirmedAt': FieldValue.serverTimestamp(), // FIX 7
      });

      // 2. FIX 7 — Write notification to customer's subcollection
      if (userId.isNotEmpty) {
        final notifRef = db
            .collection('notifications')
            .doc(userId)
            .collection('items')
            .doc();
        batch.set(notifRef, {
          'type':      'booking_accepted',
          'title':     'Booking Confirmed! ✅',
          'body':      '$helperName has accepted your $serviceName booking'
              '${formatted.isNotEmpty ? ' for $formatted' : ''}.',
          'bookingId': widget.bookingId,
          'read':      false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Create the chat and send confirmation message
      try {
        await BookingChatService.instance.onBookingAccepted(
          bookingId:     widget.bookingId,
          helperId:      helperUid,
          helperName:    helperName,
          userId:        userId,
          userName:      (data['userName'] ?? 'Customer') as String,
          serviceName:   serviceName,
          scheduledTime: formatted,
        );
      } catch (e) {
        debugPrint('[IncomingBookingDetail] BookingChatService error: $e');
      }

      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:         Text('Booking accepted! Check your upcoming jobs.'),
            backgroundColor: AppColors.success,
            behavior:        SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  // ── FIX 1: Decline writes 'cancelled', not 'declined' ────────
  Future<void> _decline() async {
    setState(() => _isDeclining = true);
    _timer?.cancel();
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({
      'status':      'cancelled',
      'cancelledBy': 'helper',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!.data() as Map<String, dynamic>? ?? {};

          final serviceName   = (data['serviceName']   as String?) ?? 'Service';
          final description   = (data['description']   as String?) ?? 'No description.';
          final address       = (data['address']       as String?) ?? '';
          final paymentMethod = (data['paymentMethod'] as String?) ?? 'Cash';
          final rating        = ((data['userRating']   ?? 0.0) as num).toDouble();
          final reviews       = (data['userReviews']   ?? 0)   as int;

          // FIX 3 — read customer's scheduledAt (set at booking, never changed)
          final scheduledTs = data['scheduledAt'] as Timestamp?;
          final scheduledDt = scheduledTs?.toDate().toLocal();

          // FIX 6 — baseAmount only; platform fee is internal app revenue
          final helperAmount = (data['baseAmount']  as num?)?.toDouble()
              ?? (data['totalAmount'] as num?)?.toDouble()
              ?? 0.0;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildMapSection(isDark)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),

                        // FIX 5 — timer card only shown for instant bookings
                        if (_timerActive) ...[
                          _buildTimerCard(isDark),
                          const SizedBox(height: 16),
                        ],

                        // FIX 3 — show customer's scheduled date/time, read-only
                        if (scheduledDt != null) ...[
                          _buildScheduleCard(scheduledDt, isDark),
                          const SizedBox(height: 16),
                        ],

                        _buildCustomerCard(
                            rating: rating, reviews: reviews, isDark: isDark),
                        const SizedBox(height: 16),

                        Row(children: [
                          Expanded(child: _buildInfoCard(
                            label: 'SERVICE',
                            value: serviceName,
                            icon:  Icons.build_rounded,
                            isDark: isDark,
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildInfoCard(
                            // FIX 6 — "YOUR EARNINGS" = baseAmount; no platform fee
                            label: 'YOUR\nEARNINGS',
                            value: '₹${helperAmount.toStringAsFixed(0)}',
                            icon:  Icons.wallet_rounded,
                            isDark: isDark,
                          )),
                        ]),
                        const SizedBox(height: 12),

                        // FIX 6 — payment method + address card
                        _buildPaymentAddressCard(
                            paymentMethod, address, isDark),
                        const SizedBox(height: 16),

                        _buildDescriptionCard(description, isDark),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildBottomActions(data, isDark),
              ),
              Positioned(
                top: 0, left: 0, right: 0,
                child: _buildAppBarOverlay(context, isDark),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Schedule card (FIX 3) — customer's date, read-only ───────
  Widget _buildScheduleCard(DateTime dt, bool isDark) {
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(dt);
    final timeStr = DateFormat('h:mm a').format(dt);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brandPurple.withOpacity(0.35)),
      ),
      child: Row(children: [
        Container(
          padding:    const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color:        AppColors.brandPurple.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_today_rounded,
              color: AppColors.brandPurple, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SCHEDULED BY CUSTOMER', style: TextStyle(
              color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2,
            )),
            const SizedBox(height: 4),
            Text(dateStr, style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   14, fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 2),
            Text(timeStr, style: const TextStyle(
              color:      AppColors.brandPurple,
              fontSize:   13, fontWeight: FontWeight.w600,
            )),
          ],
        )),
        Container(
          padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color:        AppColors.brandPurple.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.brandPurple.withOpacity(0.25)),
          ),
          child: const Text('Read-only', style: TextStyle(
            color: AppColors.brandPurple,
            fontSize: 10, fontWeight: FontWeight.w600,
          )),
        ),
      ]),
    );
  }

  // ── Payment + address card (FIX 6) ───────────────────────────
  // Platform fee is NEVER shown here. Helper sees only Cash/UPI badge.
  Widget _buildPaymentAddressCard(
      String paymentMethod, String address, bool isDark) {
    final isCash   = paymentMethod == 'Cash';
    final payColor = isCash
        ? const Color(0xFF16A34A)
        : const Color(0xFF7C3AED);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Payment badge
        Container(
          padding:    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color:        payColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: payColor.withOpacity(0.30)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
              isCash ? Icons.payments_rounded : Icons.phone_android_rounded,
              size: 13, color: payColor,
            ),
            const SizedBox(width: 5),
            Text(
              isCash ? 'Cash Payment' : 'UPI Payment',
              style: TextStyle(
                color: payColor, fontSize: 12, fontWeight: FontWeight.w700,
              ),
            ),
          ]),
        ),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.location_on_rounded,
                size:  15,
                color: isDark
                    ? AppColors.textSoftDark
                    : AppColors.textSoftLight),
            const SizedBox(width: 6),
            Expanded(child: Text(address, style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13, height: 1.5,
            ))),
          ]),
        ],
      ]),
    );
  }

  Widget _buildAppBarOverlay(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 8, right: 16,
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding:    const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:        isDark
                  ? AppColors.cardDark.withOpacity(0.8)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size:  18,
                color: isDark ? Colors.white : AppColors.textDarkLight),
          ),
        ),
        const Expanded(
          child: Text(
            'Incoming Request',
            textAlign: TextAlign.center,
            style: TextStyle(
              color:      Colors.white,
              fontSize:   18,
              fontWeight: FontWeight.w700,
              shadows:    [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        ),
        const SizedBox(width: 48),
      ]),
    );
  }

  Widget _buildMapSection(bool isDark) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.gradientStart, AppColors.gradientEnd]
              : [AppColors.brandPurple, AppColors.cyanAccent],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _MapGridPainter(),
        child: Center(
          child: Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color:  Colors.white.withOpacity(0.15),
              shape:  BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildTimerCard(bool isDark) {
    final isUrgent = _secondsLeft <= 15;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: (isUrgent ? AppColors.danger : AppColors.brandPurple)
            .withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isUrgent ? AppColors.danger : AppColors.brandPurple)
              .withOpacity(0.3),
        ),
      ),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'INSTANT BOOKING — RESPOND QUICKLY',
            style: TextStyle(
              color: isUrgent ? AppColors.danger : AppColors.brandPurple,
              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Auto-declines in $_secondsLeft seconds',
            style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13,
            ),
          ),
        ])),
        const SizedBox(width: 16),
        SizedBox(
          width: 44, height: 44,
          child: Stack(alignment: Alignment.center, children: [
            AnimatedBuilder(
              animation: _timerAnim,
              builder: (_, __) => CircularProgressIndicator(
                value:           _timerAnim.value,
                strokeWidth:     4,
                backgroundColor: isDark
                    ? AppColors.borderDark
                    : AppColors.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isUrgent ? AppColors.danger : AppColors.brandPurple,
                ),
              ),
            ),
            Icon(Icons.timer_outlined, size: 22,
                color: isUrgent ? AppColors.danger : AppColors.brandPurple),
          ]),
        ),
      ]),
    );
  }

  Widget _buildCustomerCard({
    required double rating,
    required int    reviews,
    required bool   isDark,
  }) {
    // Note: 'userName' is NOT stored in bookings (per data model).
    // The customer is shown generically; their scheduledAt is shown in the
    // schedule card above.
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color:  AppColors.gradientEnd.withOpacity(0.3),
            shape:  BoxShape.circle,
            border: Border.all(
                color: AppColors.cyanAccent.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.person_rounded,
              color: AppColors.cyanAccent, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Customer', style: TextStyle(
            color:      isDark ? Colors.white : AppColors.textDarkLight,
            fontSize:   17, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.star_rounded,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 3),
            Text(rating.toStringAsFixed(1), style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   13, fontWeight: FontWeight.w600,
            )),
            Text('  ($reviews reviews)', style: TextStyle(
              color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 12,
            )),
          ]),
        ])),
      ]),
    );
  }

  Widget _buildInfoCard({
    required String   label,
    required String   value,
    required IconData icon,
    required bool     isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark
            ? AppColors.gradientMid.withOpacity(0.5)
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
          color:       AppColors.cyanAccent,
          fontSize:    10,
          fontWeight:  FontWeight.w700,
          letterSpacing: 1,
        )),
        const SizedBox(height: 10),
        Row(children: [
          Icon(icon, color: AppColors.cyanAccent, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w700,
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _buildDescriptionCard(String description, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DESCRIPTION', style: TextStyle(
          color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5,
        )),
        const SizedBox(height: 10),
        Text(description, style: TextStyle(
          color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
          fontSize: 14, height: 1.6,
        )),
      ]),
    );
  }

  // ── Bottom action buttons ─────────────────────────────────────
  Widget _buildBottomActions(Map<String, dynamic> data, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgDark : AppColors.bgLight,
        border: Border(top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isAccepting ? null : () => _accept(data),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isAccepting
                ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded,
                size: 20, color: Colors.white),
            label: Text(
              _isAccepting ? 'Accepting...' : 'Accept Request',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isDeclining ? null : _decline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.danger, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              foregroundColor: AppColors.danger,
            ),
            icon: _isDeclining
                ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.danger))
                : const Icon(Icons.cancel_outlined,
                size: 20, color: AppColors.danger),
            label: Text(
              _isDeclining ? 'Declining...' : 'Decline',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: AppColors.danger),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Map grid background painter ───────────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color       = Colors.white.withOpacity(0.07)
      ..strokeWidth = 1;
    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    final road = Paint()
      ..color       = Colors.white.withOpacity(0.12)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(size.width * 0.2, 0),
        Offset(size.width * 0.4, size.height), road);
    canvas.drawLine(Offset(0, size.height * 0.4),
        Offset(size.width, size.height * 0.55), road);
    canvas.drawLine(Offset(size.width * 0.6, 0),
        Offset(size.width * 0.8, size.height), road);
  }

  @override
  bool shouldRepaint(_) => false;
}