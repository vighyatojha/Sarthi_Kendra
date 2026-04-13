
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/realtime_db_service.dart';
import '../../theme/app_theme.dart';
import '../review/mutual_review_sheet.dart';
import '../../providers/auth_provider.dart';

class OngoingJobScreen extends StatefulWidget {
  final String bookingId;
  const OngoingJobScreen({super.key, required this.bookingId});

  @override
  State<OngoingJobScreen> createState() => _OngoingJobScreenState();
}

class _OngoingJobScreenState extends State<OngoingJobScreen>
    with TickerProviderStateMixin {

  // ── Elapsed timer (only active when status == 'ongoing') ─────
  Timer? _timer;
  int    _elapsedSecs    = 0;
  bool   _timerRunning   = false;

  // ── Guard: show completion dialog only once ───────────────────
  bool _completionShown  = false;

  // ── Action loading ────────────────────────────────────────────
  bool _isUpdating       = false;

  // ── Fade animation between stages ────────────────────────────
  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Elapsed timer helpers ─────────────────────────────────────
  /// FIX 10 — Timer starts from Firestore `startedAt` Timestamp,
  /// not from local state. Called once when stream first shows 'ongoing'.
  void _maybeStartTimer(Timestamp? startedAt) {
    if (_timerRunning) return;
    _timerRunning = true;
    if (startedAt != null) {
      // Seed elapsed from how long ago the helper actually started
      _elapsedSecs =
          DateTime.now().difference(startedAt.toDate()).inSeconds.clamp(0, 999999);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSecs++);
    });
  }

  String get _elapsed {
    final h = _elapsedSecs ~/ 3600;
    final m = (_elapsedSecs % 3600) ~/ 60;
    final s = _elapsedSecs % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Firestore actions ─────────────────────────────────────────

  /// FIX 10 — "Start Job": writes 'ongoing' + startedAt.
  /// Does NOT change scheduledAt (set by customer).
  Future<void> _startJob() async {
    setState(() => _isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .update({
        'status':    'ongoing',
        'startedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _fadeCtrl.reset();
      _fadeCtrl.forward();
    } catch (_) {
      _snack('Update failed. Try again.', error: true);
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  /// FIX 10 — "Mark Complete": batch write — booking completed + helper counter.
  /// Shows confirmation sheet first to prevent accidental taps.
  Future<void> _confirmAndComplete(String helperUid) async {
    final confirmed = await showModalBottomSheet<bool>(
      context:   context,
      isDismissible: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CompleteConfirmSheet(),
    );
    if (confirmed != true) return;

    setState(() => _isUpdating = true);
    try {
      _timer?.cancel();
      final db    = FirebaseFirestore.instance;
      final batch = db.batch();

      batch.update(db.collection('bookings').doc(widget.bookingId), {
        'status':      'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt':   FieldValue.serverTimestamp(),
      });

      // FIX 10 — increment completedJobs on the helper document
      if (helperUid.isNotEmpty) {
        batch.update(db.collection('helpers').doc(helperUid), {
          'completedJobs': FieldValue.increment(1),
        });
      }

      await batch.commit();
      // Completion dialog will be shown by the StreamBuilder listener
    } catch (_) {
      _snack('Update failed. Try again.', error: true);
    }
    if (mounted) setState(() => _isUpdating = false);
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final helperUid = context.read<AuthProvider>().helper?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snap) {
          final data    = snap.data?.data() as Map<String, dynamic>? ?? {};
          // FIX 10 — drive EVERYTHING from Firestore status
          final status  = (data['status'] as String?) ?? 'accepted';

          // FIX 10 — userName is NOT stored in bookings (per data model).
          // Display customer generically.
          final serviceName = (data['serviceName'] as String?) ?? 'Service';
          // FIX 10 — baseAmount only; platform fee (platformFee) is app revenue
          final amount      = (data['baseAmount']  as num?)?.toDouble()
              ?? (data['totalAmount'] as num?)?.toDouble()
              ?? 0.0;
          final address     = (data['address']     as String?) ?? '';
          final userPhone   = (data['userPhone']   as String?) ?? '';
          final startedAt   = data['startedAt']    as Timestamp?;

          // FIX 10 — start timer from Firestore startedAt when status is 'ongoing'
          if (status == 'ongoing') {
            WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _maybeStartTimer(startedAt));
          }

          // FIX 10 — when Firestore confirms 'completed', show dialog once
          if (status == 'completed' && !_completionShown) {
            _completionShown = true;
            WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _showCompletionDialog());
          }

          return Column(children: [
            _buildHeader(isDark, serviceName, status),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: FadeTransition(
                opacity: _fade,
                child: Column(children: [
                  // FIX 10 — stage indicator reads from Firestore status
                  _StageIndicator(status: status),
                  const SizedBox(height: 20),

                  _CustomerCard(
                      phone:   userPhone,
                      address: address,
                      isDark:  isDark),
                  const SizedBox(height: 16),

                  _JobInfoRow(
                      service: serviceName,
                      amount:  amount,
                      elapsed: status == 'ongoing' ? _elapsed : null,
                      isDark:  isDark),
                  const SizedBox(height: 16),

                  // FIX 10 — show correct card based on Firestore status
                  if (status == 'accepted')
                    _NavigatingCard(isDark: isDark),
                  if (status == 'ongoing')
                    _ActiveJobCard(elapsed: _elapsed, isDark: isDark),
                  if (status == 'completed')
                    _CompletedCard(isDark: isDark),

                  const SizedBox(height: 80),
                ]),
              ),
            )),
          ]);
        },
      ),

      // ── Bottom action bar ─────────────────────────────────────
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .doc(widget.bookingId)
            .snapshots(),
        builder: (context, snap) {
          final data   = snap.data?.data() as Map<String, dynamic>? ?? {};
          final status = (data['status'] as String?) ?? 'accepted';
          return _buildActionBar(isDark, status, helperUid);
        },
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, String serviceName, String status) {
    final title = _headerTitle(status);
    final badge = _headerBadge(status);
    final color = _headerColor(status);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 8, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF3B0764), Color(0xFF5B21B6), Color(0xFF7C3AED)],
        ),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          Text(serviceName, style: TextStyle(
              color: Colors.white.withOpacity(0.65), fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(badge, style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  // ── Action bar ────────────────────────────────────────────────
  Widget _buildActionBar(bool isDark, String status, String helperUid) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        border: Border(top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: _buildActionButton(isDark, status, helperUid),
    );
  }

  Widget _buildActionButton(bool isDark, String status, String helperUid) {
    // FIX 10 — action button driven by Firestore status, not local enum
    if (status == 'accepted') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isUpdating ? null : _startJob,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isUpdating
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.play_circle_rounded, size: 22, color: Colors.white),
          label: Text(_isUpdating ? 'Starting...' : 'Start Job',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
    }

    if (status == 'ongoing') {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isUpdating ? null : () => _confirmAndComplete(helperUid),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.brandPurple,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isUpdating
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 22, color: Colors.white),
          label: Text(_isUpdating ? 'Processing...' : 'Mark as Complete',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Completion dialog ─────────────────────────────────────────
  Future<void> _showCompletionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context:          context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor:
        isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded,
                  color: AppColors.success, size: 40),
            ),
            const SizedBox(height: 20),
            Text('Job Completed! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Great work! Your payment will be\ncredited to your wallet shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 14, height: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color:        AppColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.timer_outlined,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text('Duration: $_elapsed',
                    style: const TextStyle(
                        color: AppColors.success,
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // close dialog
                  await Future.delayed(const Duration(milliseconds: 300));
                  if (!mounted) return;

                  final doc = await FirebaseFirestore.instance
                      .collection('bookings')
                      .doc(widget.bookingId)
                      .get();
                  if (!mounted) return;

                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final userId   = (data['userId']   as String?) ?? '';
                  final userName = (data['userName'] ??
                      data['customerName'] ?? 'Customer') as String;
                  final service  = (data['serviceName'] ?? 'Service') as String;

                  if (userId.isNotEmpty) {
                    await MutualReviewSheet.showForHelper(
                      context,
                      bookingId:   widget.bookingId,
                      userId:      userId,
                      userName:    userName,
                      serviceName: service,
                      onAfterClose: () {
                        final chatId = widget.bookingId;
                        RealtimeDbService.instance.deleteChat(chatId).then((_) {
                          FirebaseFirestore.instance
                              .collection('chats')
                              .doc(chatId)
                              .update({'bookingStatus': 'review_done'})
                              .catchError((_) {});
                        });
                        if (mounted) Navigator.pop(context);
                      },
                    );
                  } else {
                    if (mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Back to Dashboard',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Header helpers ────────────────────────────────────────────
  String _headerTitle(String status) {
    switch (status) {
      case 'accepted':  return 'Navigate to Customer';
      case 'ongoing':   return 'Job In Progress';
      case 'completed': return 'Job Done';
      default:          return 'Job Details';
    }
  }

  String _headerBadge(String status) {
    switch (status) {
      case 'accepted':  return 'DRIVING';
      case 'ongoing':   return 'ACTIVE';
      case 'completed': return 'DONE';
      default:          return status.toUpperCase();
    }
  }

  Color _headerColor(String status) {
    switch (status) {
      case 'accepted':  return AppColors.cyanAccent;
      case 'ongoing':   return AppColors.onlineGreen;
      case 'completed': return AppColors.success;
      default:          return AppColors.brandPurple;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE INDICATOR
// FIX 10 — accepts status String instead of _JobStage enum
// ─────────────────────────────────────────────────────────────────────────────
class _StageIndicator extends StatelessWidget {
  /// Firestore status string: 'accepted' | 'ongoing' | 'completed'
  final String status;
  const _StageIndicator({required this.status});

  int get _currentStep {
    switch (status) {
      case 'accepted':  return 0;
      case 'ongoing':   return 1;
      case 'completed': return 3;
      default:          return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final labels  = ['Navigate', 'Working', 'Complete', 'Done'];
    final current = _currentStep;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = current > i ~/ 2;
            return Expanded(child: Container(
              height: 2,
              color: done
                  ? AppColors.success
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ));
          }
          final idx    = i ~/ 2;
          final done   = current > idx;
          final active = current == idx;
          return Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done   ? AppColors.success
                    : active ? AppColors.brandPurple
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: done   ? AppColors.success
                      : active ? AppColors.brandPurple
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  width: 2,
                ),
              ),
              child: Center(child: done
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : active
                  ? Container(width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle))
                  : Text('${idx + 1}', style: TextStyle(
                  color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                  fontSize: 11, fontWeight: FontWeight.w600))),
            ),
            const SizedBox(height: 5),
            Text(labels[idx], style: TextStyle(
              color: active || done ? AppColors.brandPurple
                  : (isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
              fontSize: 9, fontWeight: FontWeight.w600,
            )),
          ]);
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOMER CARD
// FIX 10 — 'userName' not stored in bookings; shows generic label
// ─────────────────────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  // Note: userName is NOT stored in the bookings collection (per data model).
  // We show "Customer" generically; phone and address come from booking doc.
  final String phone, address;
  final bool   isDark;
  const _CustomerCard({
    required this.phone, required this.address, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded,
                color: AppColors.brandPurple, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Customer', style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   16, fontWeight: FontWeight.w700)),
            if (phone.isNotEmpty)
              Row(children: [
                const Icon(Icons.phone_rounded,
                    size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(phone, style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
          ])),
          if (phone.isNotEmpty)
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color:        AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.call_rounded,
                  color: AppColors.success, size: 20),
            ),
        ]),
        if (address.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.location_on_rounded,
                color: AppColors.brandPurple, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(address, style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13, height: 1.4))),
          ]),
        ],
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// JOB INFO ROW
// ─────────────────────────────────────────────────────────────────────────────
class _JobInfoRow extends StatelessWidget {
  final String  service;
  final double  amount;
  final String? elapsed;
  final bool    isDark;
  const _JobInfoRow({
    required this.service, required this.amount,
    this.elapsed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _InfoTile(
          label: 'SERVICE', value: service,
          icon: Icons.build_rounded, isDark: isDark)),
      const SizedBox(width: 12),
      Expanded(child: _InfoTile(
          label: 'YOUR EARNINGS',
          value: '₹${amount.toStringAsFixed(0)}',
          icon: Icons.wallet_rounded, isDark: isDark,
          highlight: true)),
      if (elapsed != null) ...[
        const SizedBox(width: 12),
        Expanded(child: _InfoTile(
            label: 'TIME', value: elapsed!,
            icon: Icons.timer_rounded, isDark: isDark)),
      ],
    ]);
  }
}

class _InfoTile extends StatelessWidget {
  final String   label, value;
  final IconData icon;
  final bool     isDark, highlight;
  const _InfoTile({
    required this.label, required this.value,
    required this.icon, required this.isDark, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        isDark
            ? AppColors.cardDark
            : (highlight ? AppColors.brandPurple.withOpacity(0.05) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: highlight
                ? AppColors.brandPurple.withOpacity(0.25)
                : (isDark ? AppColors.borderDark : AppColors.borderLight)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(
            color: AppColors.cyanAccent,
            fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        Row(children: [
          Icon(icon, size: 15,
              color: highlight ? AppColors.brandPurple : AppColors.cyanAccent),
          const SizedBox(width: 5),
          Expanded(child: Text(value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   14, fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STAGE-SPECIFIC CARDS
// FIX 10 — shown/hidden based on Firestore status, not local _JobStage
// ─────────────────────────────────────────────────────────────────────────────

/// Shown when status == 'accepted': navigate to customer first
class _NavigatingCard extends StatelessWidget {
  final bool isDark;
  const _NavigatingCard({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color: AppColors.cyanAccent.withOpacity(0.12),
              shape: BoxShape.circle),
          child: const Icon(Icons.navigation_rounded,
              color: AppColors.cyanAccent, size: 28),
        ),
        const SizedBox(height: 14),
        Text('Head to Customer Location',
            style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
            'Press "Start Job" when you arrive at the customer\'s location.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13, height: 1.5)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:        AppColors.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(
                'Only start after you physically arrive.',
                style: TextStyle(
                    color: isDark
                        ? AppColors.warning
                        : const Color(0xFF92400E),
                    fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}

/// Shown when status == 'ongoing': live elapsed timer display
class _ActiveJobCard extends StatelessWidget {
  final String elapsed;
  final bool   isDark;
  const _ActiveJobCard({required this.elapsed, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.onlineGreen.withOpacity(0.35)),
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 10, height: 10,
            decoration: const BoxDecoration(
                color: AppColors.onlineGreen, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text('Job In Progress', style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color:        AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.timer_rounded, color: AppColors.success, size: 20),
            const SizedBox(width: 8),
            Text(elapsed, style: const TextStyle(
                color:      AppColors.success,
                fontSize:   24, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ]),
        ),
        const SizedBox(height: 12),
        Text('When the job is done, press "Mark as Complete".',
            textAlign: TextAlign.center,
            style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

/// Shown when status == 'completed': success banner while dialog loads
class _CompletedCard extends StatelessWidget {
  final bool isDark;
  const _CompletedCard({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.35)),
      ),
      child: Column(children: [
        const Icon(Icons.check_circle_rounded,
            color: AppColors.success, size: 48),
        const SizedBox(height: 12),
        Text('Job Completed!',
            style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Great work! Your earnings will be credited shortly.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13, height: 1.5)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETE CONFIRMATION BOTTOM SHEET
// Shown when helper taps "Mark as Complete" — prevents accidental taps
// ─────────────────────────────────────────────────────────────────────────────
class _CompleteConfirmSheet extends StatelessWidget {
  const _CompleteConfirmSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4)),
        ),
        const Icon(Icons.assignment_turned_in_rounded,
            color: AppColors.warning, size: 44),
        const SizedBox(height: 14),
        const Text('Confirm Job Completion',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Ask the customer to confirm the work is done before tapping Confirm.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Colors.grey, fontWeight: FontWeight.w600)),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Confirm',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 15)),
          )),
        ]),
      ]),
    );
  }
}