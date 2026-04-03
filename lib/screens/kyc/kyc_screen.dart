// lib/screens/kyc/kyc_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../dashboard/helper_dashboard.dart';

const _purple     = Color(0xFF7C3AED);
const _purpleDeep = Color(0xFF3B0764);

extension _Op on Color {
  Color op(double a) => withValues(alpha: a);
}

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});
  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final _formKey      = GlobalKey<FormState>();
  final _aadhaarCtrl  = TextEditingController();
  final _panCtrl      = TextEditingController();

  bool _submitting = false;
  bool _waiting    = false;

  @override
  void dispose() {
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.submitKyc({
      'aadharNumber': _aadhaarCtrl.text.trim(),
      'aadhaar':      _aadhaarCtrl.text.trim(),
      'panNumber':    _panCtrl.text.trim(),
      'pan':          _panCtrl.text.trim(),
    });

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      _snack('KYC submitted! We\'ll review within 24 hours.');
      _goToDashboard();
    } else {
      _snack(auth.errorMessage ?? 'Submission failed. Try again.',
          err: true);
    }
  }

  Future<void> _wait() async {
    setState(() => _waiting = true);
    await context.read<AuthProvider>().skipKyc();
    if (!mounted) return;
    _goToDashboard();
  }

  void _goToDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HelperDashboard()),
          (_) => false,
    );
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor:
        err ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
      ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF2F4F8),
      body: Column(children: [
        _buildHeader(isDark),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _buildInfoCard(isDark),
                const SizedBox(height: 16),
                _buildFormCard(isDark),
                const SizedBox(height: 20),
                _buildSubmitBtn(),
                const SizedBox(height: 12),
                _buildWaitBtn(isDark),
                const SizedBox(height: 20),
                _buildWaitInfo(isDark),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 24, left: 24, right: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E0640), Color(0xFF3B0764), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Progress steps
        Row(children: [
          _step('1', 'Account', done: true),
          _stepLine(),
          _step('2', 'KYC', active: true),
          _stepLine(),
          _step('3', 'Go Live'),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: Colors.white.op(0.15),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.op(0.20)),
            ),
            child: const Icon(Icons.verified_user_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('KYC Verification',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            Text('Verify your identity to start earning',
                style: TextStyle(
                    color: Colors.white.op(0.65), fontSize: 12)),
          ]),
        ]),
      ]),
    );
  }

  Widget _step(String num, String label,
      {bool done = false, bool active = false}) {
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: done
              ? const Color(0xFF059669)
              : active
              ? Colors.white
              : Colors.white.op(0.20),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: done
              ? const Icon(Icons.check_rounded,
              color: Colors.white, size: 14)
              : Text(num,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? _purple : Colors.white.op(0.60))),
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: (done || active)
                  ? Colors.white
                  : Colors.white.op(0.50))),
    ]);
  }

  Widget _stepLine() => Expanded(
    child: Container(
      height: 1.5,
      margin: const EdgeInsets.only(bottom: 18, left: 6, right: 6),
      color: Colors.white.op(0.25),
    ),
  );

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).op(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7C3AED).op(0.25)),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: _purple, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('Why KYC is required',
                style: TextStyle(
                    color: _purple,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        _infoRow(Icons.security_rounded,
            'Builds trust with customers'),
        _infoRow(Icons.payments_rounded,
            'Required to receive payouts'),
        _infoRow(Icons.verified_rounded,
            'Unlocks "Go Live" to accept bookings'),
        _infoRow(Icons.access_time_rounded,
            'Review takes 24–48 hours'),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(children: [
      Icon(icon, color: _purple.op(0.70), size: 14),
      const SizedBox(width: 8),
      Text(text,
          style: TextStyle(
              fontSize: 12,
              color: _purple.op(0.80))),
    ]),
  );

  Widget _buildFormCard(bool isDark) {
    final sub = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final txt = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? const Color(0xFF2D2D3D)
                : const Color(0xFFE8E4F3)),
        boxShadow: [
          BoxShadow(
              color: _purple.op(0.05),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enter Your Details',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937))),
        const SizedBox(height: 18),

        // Aadhaar
        _label(Icons.credit_card_outlined,
            'Aadhaar Card Number', sub),
        const SizedBox(height: 6),
        TextFormField(
          controller: _aadhaarCtrl,
          keyboardType: TextInputType.number,
          maxLength: 12,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
              color: txt, fontSize: 13, fontWeight: FontWeight.w500),
          decoration: _dec(isDark,
              hint: '12-digit Aadhaar number',
              icon: Icons.credit_card_outlined,
              color: _purple),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Aadhaar is required';
            if (v.length != 12) return 'Enter valid 12-digit Aadhaar';
            return null;
          },
        ),

        const SizedBox(height: 14),

        // PAN
        _label(Icons.assignment_ind_outlined, 'PAN Card Number', sub),
        const SizedBox(height: 6),
        TextFormField(
          controller: _panCtrl,
          textCapitalization: TextCapitalization.characters,
          maxLength: 10,
          style: TextStyle(
              color: txt, fontSize: 13, fontWeight: FontWeight.w500),
          decoration: _dec(isDark,
              hint: 'ABCDE1234F',
              icon: Icons.assignment_ind_outlined,
              color: const Color(0xFF0284C7)),
          validator: (v) {
            if (v == null || v.isEmpty) return 'PAN is required';
            if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$')
                .hasMatch(v.toUpperCase())) {
              return 'Enter valid PAN (e.g. ABCDE1234F)';
            }
            return null;
          },
        ),
      ]),
    );
  }

  Widget _label(IconData icon, String text, Color sub) => Row(children: [
    Icon(icon, size: 11, color: _purple),
    const SizedBox(width: 5),
    Text(text,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
  ]);

  InputDecoration _dec(bool isDark,
      {required String hint,
        required IconData icon,
        required Color color}) =>
      InputDecoration(
        hintText: hint,
        counterText: '',
        hintStyle: TextStyle(
            color: isDark
                ? const Color(0xFF484F58)
                : const Color(0xFFADB5BD),
            fontSize: 13),
        prefixIcon: Icon(icon, color: color, size: 18),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 11),
        isDense: true,
        filled: true,
        fillColor:
        isDark ? const Color(0xFF23232F) : color.op(0.03),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFF2D2D3D)
                  : color.op(0.18)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
          const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFFDC2626), width: 1.5),
        ),
      );

  Widget _buildSubmitBtn() {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: _submitting
              ? const LinearGradient(
              colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
              : const LinearGradient(
              colors: [
                Color(0xFF6D28D9),
                Color(0xFF7C3AED),
                Color(0xFF9333EA)
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _submitting
              ? []
              : [
            BoxShadow(
                color: _purple.op(0.38),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_submitting)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
              else
                const Icon(Icons.verified_user_rounded,
                    color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                _submitting
                    ? 'Submitting KYC...'
                    : 'Submit KYC Documents',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ]),
      ),
    );
  }

  Widget _buildWaitBtn(bool isDark) {
    return GestureDetector(
      onTap: _waiting ? null : _wait,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF2D2D3D)
                  : const Color(0xFFE8E4F3),
              width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_waiting)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _purple))
              else
                Icon(Icons.access_time_rounded,
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                    size: 18),
              const SizedBox(width: 8),
              Text(
                _waiting ? 'Please wait...' : 'Wait — I\'ll do this later',
                style: TextStyle(
                    color: isDark
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF6B7280),
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            ]),
      ),
    );
  }

  Widget _buildWaitInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).op(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFFF59E0B).op(0.30)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_clock_outlined,
                color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dashboard access is limited without KYC',
                        style: TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'You can browse the app but "Go Live" will stay locked '
                          'until KYC is approved. Complete it anytime from your profile.',
                      style: TextStyle(
                          color: const Color(0xFF92400E).op(0.80),
                          fontSize: 11,
                          height: 1.5),
                    ),
                  ]),
            ),
          ]),
    );
  }
}