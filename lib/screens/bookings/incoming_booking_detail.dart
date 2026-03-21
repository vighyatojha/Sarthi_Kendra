// lib/screens/bookings/incoming_booking_detail.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

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

  int    _secondsLeft  = 60;
  Timer? _timer;
  bool   _isAccepting  = false;
  bool   _isDeclining  = false;

  late final AnimationController _timerCtrl;
  late final Animation<double>   _timerAnim;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 60),
    )..forward();
    _timerAnim = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _timerCtrl, curve: Curves.linear),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        _timer?.cancel();
        _autoDecline();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerCtrl.dispose();
    super.dispose();
  }

  Future<void> _autoDecline() async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({'status': 'timeout'});
    if (mounted) Navigator.pop(context);
  }

  Future<void> _accept() async {
    setState(() => _isAccepting = true);
    final auth = context.read<AuthProvider>();

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({
      'status':     'accepted',
      'helperId':   auth.helper?.uid,   // ← fixed: uid not id
      'helperName': auth.helper?.name,
      'acceptedAt': FieldValue.serverTimestamp(),
    });

    _timer?.cancel();
    if (mounted) {
      setState(() => _isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:         Text('Booking accepted! Head to customer location.'),
          backgroundColor: AppColors.success,
          behavior:        SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _decline() async {
    setState(() => _isDeclining = true);
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.bookingId)
        .update({
      'status':     'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
    _timer?.cancel();
    if (mounted) Navigator.pop(context);
  }

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
          final data        = snap.data!.data() as Map<String, dynamic>? ?? {};
          final userName    = data['userName']    ?? 'Customer';
          final serviceName = data['serviceName'] ?? 'Service';
          final description = data['description'] ?? 'No description provided.';
          final amount      = data['amount']      ?? 0;
          final rating      = ((data['userRating'] ?? 0.0) as num).toDouble();
          final reviews     = (data['userReviews'] ?? 0) as int;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                      child: _buildMapSection(isDark)),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 16),
                        _buildTimerCard(isDark),
                        const SizedBox(height: 16),
                        _buildCustomerCard(
                          userName: userName,
                          rating:   rating,
                          reviews:  reviews,
                          isDark:   isDark,
                        ),
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
                            label: 'ESTIMATED\nEARNINGS',
                            value: '₹$amount',
                            icon:  Icons.wallet_rounded,
                            isDark: isDark,
                          )),
                        ]),
                        const SizedBox(height: 16),
                        _buildDescriptionCard(description, isDark),
                      ]),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: _buildBottomActions(isDark),
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
    return Stack(children: [
      Container(
        height: 260,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [Color(0xFF1A6B8A), Color(0xFF0F4C75), Color(0xFF1B2838)],
          ),
        ),
        child: Stack(children: [
          CustomPaint(
            size: const Size(double.infinity, 260),
            painter: _MapGridPainter(),
          ),
          Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:        AppColors.brandPurple,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('CUSTOMER LOCATION',
                        style: TextStyle(
                            color: Colors.white, fontSize: 10,
                            fontWeight: FontWeight.w700, letterSpacing: 1)),
                  ),
                  Container(
                      margin: const EdgeInsets.only(top: 4),
                      width: 2, height: 16,
                      color: AppColors.brandPurple),
                  Container(
                      width: 14, height: 14,
                      decoration: const BoxDecoration(
                          color: AppColors.brandPurple, shape: BoxShape.circle)),
                ]),
          ),
        ]),
      ),
      Positioned(
        bottom: 12, left: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:        AppColors.gradientStart.withOpacity(0.9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.navigation_rounded,
                size: 14, color: AppColors.cyanAccent),
            SizedBox(width: 6),
            Text('1.2 km away', style: TextStyle(
                color: Colors.white, fontSize: 13,
                fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildTimerCard(bool isDark) {
    final mm       = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss       = (_secondsLeft %  60).toString().padLeft(2, '0');
    final isUrgent = _secondsLeft <= 15;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUrgent
              ? AppColors.danger.withOpacity(0.5)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(children: [
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TIME REMAINING', style: TextStyle(
            color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
            fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          )),
          const SizedBox(height: 6),
          RichText(text: TextSpan(children: [
            TextSpan(text: '$mm:', style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   32, fontWeight: FontWeight.w800,
            )),
            TextSpan(text: ss, style: TextStyle(
              color:      isUrgent ? AppColors.danger : AppColors.brandPurple,
              fontSize:   32, fontWeight: FontWeight.w800,
            )),
          ])),
        ])),
        SizedBox(
          width: 52, height: 52,
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
    required String userName,
    required double rating,
    required int    reviews,
    required bool   isDark,
  }) {
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
          Text(userName, style: TextStyle(
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
            Text('  ($reviews Reviews)', style: TextStyle(
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
          color: AppColors.cyanAccent,
          fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
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

  Widget _buildBottomActions(bool isDark) {
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
            onPressed: _isAccepting ? null : _accept,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: _isAccepting
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_outline_rounded, size: 20),
            label: Text(_isAccepting ? 'Accepting...' : 'Accept Request',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isDeclining ? null : _decline,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              foregroundColor:
              isDark ? AppColors.textMidDark : AppColors.textMidLight,
            ),
            icon: _isDeclining
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cancel_outlined, size: 20),
            label: Text(_isDeclining ? 'Declining...' : 'Decline',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

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