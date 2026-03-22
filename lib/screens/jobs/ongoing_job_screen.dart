// lib/screens/jobs/ongoing_job_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';

/// Stages of a job lifecycle
enum _JobStage { navigating, started, completing, done }

class OngoingJobScreen extends StatefulWidget {
  final String bookingId;
  const OngoingJobScreen({super.key, required this.bookingId});

  @override
  State<OngoingJobScreen> createState() => _OngoingJobScreenState();
}

class _OngoingJobScreenState extends State<OngoingJobScreen>
    with TickerProviderStateMixin {

  _JobStage _stage       = _JobStage.navigating;
  bool      _isUpdating  = false;
  Timer?    _jobTimer;
  int       _elapsedSecs = 0;

  late final AnimationController _stageCtrl;
  late final Animation<double>   _stageFade;

  @override
  void initState() {
    super.initState();
    _stageCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _stageFade = CurvedAnimation(parent: _stageCtrl, curve: Curves.easeOut);
    _stageCtrl.forward();
  }

  @override
  void dispose() {
    _jobTimer?.cancel();
    _stageCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _jobTimer = Timer.periodic(const Duration(seconds: 1), (_) {
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

  Future<void> _transition(_JobStage next, {Map<String, dynamic>? updates}) async {
    setState(() => _isUpdating = true);
    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        ...?updates,
      };
      await FirebaseFirestore.instance
          .collection('bookings').doc(widget.bookingId)
          .update(data);
    } catch (e) {
      _snack('Update failed. Try again.', error: true);
      setState(() => _isUpdating = false);
      return;
    }
    _stageCtrl.reset();
    setState(() { _stage = next; _isUpdating = false; });
    _stageCtrl.forward();

    if (next == _JobStage.started) _startTimer();
    if (next == _JobStage.done) {
      _jobTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _showCompletionDialog();
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings').doc(widget.bookingId).snapshots(),
        builder: (context, snap) {
          final data        = snap.data?.data() as Map<String, dynamic>? ?? {};
          final userName    = data['userName']    as String? ?? 'Customer';
          final serviceName = data['serviceName'] as String? ?? 'Service';
          final amount      = ((data['amount'] ?? 0) as num).toDouble();
          final address     = data['address']     as String? ?? 'Loading address...';
          final userPhone   = data['userPhone']   as String? ?? '';

          return Column(children: [
            // ── Header ──────────────────────────────────────────
            _buildHeader(isDark, serviceName),

            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: FadeTransition(
                opacity: _stageFade,
                child: Column(children: [
                  // Stage progress indicator
                  _StageIndicator(stage: _stage),
                  const SizedBox(height: 20),

                  // Customer info card
                  _CustomerCard(
                      name: userName, phone: userPhone,
                      address: address, isDark: isDark),
                  const SizedBox(height: 16),

                  // Job + earnings card
                  _JobInfoRow(
                      service: serviceName, amount: amount,
                      elapsed: _stage == _JobStage.started ? _elapsed : null,
                      isDark: isDark),
                  const SizedBox(height: 16),

                  // Stage-specific content
                  if (_stage == _JobStage.navigating)
                    _NavigatingCard(isDark: isDark),
                  if (_stage == _JobStage.started)
                    _ActiveJobCard(elapsed: _elapsed, isDark: isDark),
                  if (_stage == _JobStage.completing)
                    _CompletingCard(isDark: isDark),

                  const SizedBox(height: 80),
                ]),
              ),
            )),
          ]);
        },
      ),

      // ── Bottom action bar ─────────────────────────────────────
      bottomNavigationBar: _buildActionBar(isDark),
    );
  }

  Widget _buildHeader(bool isDark, String serviceName) {
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
          Text(_stageTitle, style: const TextStyle(
              color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
          Text(serviceName, style: TextStyle(
              color: Colors.white.withOpacity(0.65), fontSize: 12)),
        ])),
        // Stage badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        _stageColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stageColor.withOpacity(0.5)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                  color: _stageColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(_stageBadge, style: TextStyle(
                color: _stageColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildActionBar(bool isDark) {
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
      child: _buildActionButton(isDark),
    );
  }

  Widget _buildActionButton(bool isDark) {
    switch (_stage) {
      case _JobStage.navigating:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : () => _transition(
              _JobStage.started,
              updates: {'status': 'in_progress', 'startedAt': FieldValue.serverTimestamp()},
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isUpdating
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.play_circle_rounded, size: 22),
            label: Text(_isUpdating ? 'Starting...' : 'Start Job',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        );

      case _JobStage.started:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : () => _transition(_JobStage.completing),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandPurple,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isUpdating
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle_rounded, size: 22),
            label: Text(_isUpdating ? 'Processing...' : 'Mark as Complete',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        );

      case _JobStage.completing:
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isUpdating ? null : () => _transition(
              _JobStage.done,
              updates: {'status': 'completed', 'completedAt': FieldValue.serverTimestamp()},
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _isUpdating
                ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.verified_rounded, size: 22),
            label: Text(_isUpdating ? 'Completing...' : 'Confirm Completion',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        );

      case _JobStage.done:
        return const SizedBox.shrink();
    }
  }

  // ── Completion dialog ─────────────────────────────────────────
  Future<void> _showCompletionDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Great work! Your payment will be\ncredited to your wallet shortly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 14, height: 1.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                onPressed: () {
                  Navigator.pop(context); // close dialog
                  Navigator.pop(context); // back to dashboard
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

  String get _stageTitle {
    switch (_stage) {
      case _JobStage.navigating:  return 'Navigate to Customer';
      case _JobStage.started:     return 'Job In Progress';
      case _JobStage.completing:  return 'Confirm Completion';
      case _JobStage.done:        return 'Job Done';
    }
  }

  String get _stageBadge {
    switch (_stage) {
      case _JobStage.navigating:  return 'DRIVING';
      case _JobStage.started:     return 'ACTIVE';
      case _JobStage.completing:  return 'FINISHING';
      case _JobStage.done:        return 'DONE';
    }
  }

  Color get _stageColor {
    switch (_stage) {
      case _JobStage.navigating:  return AppColors.cyanAccent;
      case _JobStage.started:     return AppColors.onlineGreen;
      case _JobStage.completing:  return AppColors.warning;
      case _JobStage.done:        return AppColors.success;
    }
  }
}

// ── Stage indicator ───────────────────────────────────────────────────────────
class _StageIndicator extends StatelessWidget {
  final _JobStage stage;
  const _StageIndicator({required this.stage});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final stages  = [_JobStage.navigating, _JobStage.started, _JobStage.completing, _JobStage.done];
    final labels  = ['Navigate', 'Working', 'Complete', 'Done'];
    final current = stages.indexOf(stage);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Row(
        children: List.generate(stages.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connector line
            final done = current > i ~/ 2;
            return Expanded(child: Container(
              height: 2,
              color: done ? AppColors.success : (isDark ? AppColors.borderDark : AppColors.borderLight),
            ));
          }
          final idx  = i ~/ 2;
          final done = current > idx;
          final active = current == idx;
          return Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: done    ? AppColors.success
                    : active  ? AppColors.brandPurple
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

// ── Customer card ─────────────────────────────────────────────────────────────
class _CustomerCard extends StatelessWidget {
  final String name, phone, address;
  final bool isDark;
  const _CustomerCard({
    required this.name, required this.phone,
    required this.address, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: AppColors.brandPurple.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, color: AppColors.brandPurple, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   16, fontWeight: FontWeight.w700)),
            if (phone.isNotEmpty)
              Row(children: [
                const Icon(Icons.phone_rounded, size: 12, color: AppColors.success),
                const SizedBox(width: 4),
                Text(phone, style: TextStyle(
                    color: AppColors.success, fontSize: 13, fontWeight: FontWeight.w500)),
              ]),
          ])),
          // Call button
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

// ── Job info row ──────────────────────────────────────────────────────────────
class _JobInfoRow extends StatelessWidget {
  final String service;
  final double amount;
  final String? elapsed;
  final bool isDark;
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
          label: 'EARNINGS', value: '₹${amount.toStringAsFixed(0)}',
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
  final String label, value;
  final IconData icon;
  final bool isDark, highlight;
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

// ── Stage-specific cards ──────────────────────────────────────────────────────
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
        border: Border.all(
            color: AppColors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
              color:        AppColors.cyanAccent.withOpacity(0.12),
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
        Text('Press "Start Job" when you arrive at the customer\'s location.',
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
                    color:    isDark ? AppColors.warning : const Color(0xFF92400E),
                    fontSize: 12))),
          ]),
        ),
      ]),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final String elapsed;
  final bool isDark;
  const _ActiveJobCard({required this.elapsed, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.onlineGreen.withOpacity(0.35)),
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

class _CompletingCard extends StatelessWidget {
  final bool isDark;
  const _CompletingCard({required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Column(children: [
        const Icon(Icons.assignment_turned_in_rounded,
            color: AppColors.warning, size: 40),
        const SizedBox(height: 12),
        Text('Confirm Job Completion',
            style: TextStyle(
                color:      isDark ? Colors.white : AppColors.textDarkLight,
                fontSize:   16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Ask the customer to confirm the work is done before you tap "Confirm".',
            textAlign: TextAlign.center,
            style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13, height: 1.5)),
      ]),
    );
  }
}