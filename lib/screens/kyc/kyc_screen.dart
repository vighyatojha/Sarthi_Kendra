// lib/screens/kyc/kyc_screen.dart  ← FIXED VERSION
// CHANGES FROM ORIGINAL (marked ← FIX):
//   1. kycData map now uses 'aadharNumber'/'panNumber' keys
//      (admin also accepts 'aadhaar'/'pan' due to || fallback, but explicit is safer)
//
// Note: The real root-cause bugs are ALL in auth_provider.dart → submitKyc().
// This file is mostly correct; the key change is being explicit about field names.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../dashboard/helper_dashboard.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({super.key});

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  bool _isSubmitting = false;
  bool _isSkipping   = false;

  final _aadhaarCtrl = TextEditingController();
  final _panCtrl     = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  @override
  void dispose() {
    _aadhaarCtrl.dispose();
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitKyc() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final auth = context.read<AuthProvider>();
    final success = await auth.submitKyc({
      // ← FIX: Use 'aadharNumber' to match admin's primary key.
      //   Admin reads: docs.aadharNumber || docs.aadhaar
      //   Using 'aadharNumber' ensures the primary slot is filled.
      'aadharNumber': _aadhaarCtrl.text.trim(),
      'aadhaar':      _aadhaarCtrl.text.trim(), // keep fallback key too
      'panNumber':    _panCtrl.text.trim(),
      'pan':          _panCtrl.text.trim(),     // keep fallback key too
    });

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _goToDashboard();
    } else {
      _showSnack(auth.errorMessage ?? 'Submission failed. Try again.', isError: true);
    }
  }

  Future<void> _skipKyc() async {
    setState(() => _isSkipping = true);
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg),
      backgroundColor: isError ? AppColors.danger : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSkipBanner(isDark),
                    const SizedBox(height: 20),
                    _buildInfoBox(isDark),
                    const SizedBox(height: 20),
                    _buildKycCard(isDark),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 16),
                    _buildSkipButton(isDark),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      width:   double.infinity,
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 16,
        bottom: 20,
        left:   20,
        right:  20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'KYC Verification',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _isSkipping ? null : _skipKyc,
                style: TextButton.styleFrom(
                  padding:         const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  backgroundColor: Colors.white.withOpacity(0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _isSkipping
                    ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
                    : const Text(
                  'Skip for now',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Complete verification to unlock all features',
            style: TextStyle(
              color:    Colors.white.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You can skip KYC now and complete it later from your profile. '
                  'Without KYC, some features may be restricted.',
              style: TextStyle(
                color:    isDark
                    ? AppColors.warning
                    : const Color(0xFF7A5200),
                fontSize: 12,
                height:   1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox(bool isDark) {
    final steps = [
      (Icons.credit_card_outlined,       'Aadhaar Card Number'),
      (Icons.assignment_ind_outlined,    'PAN Card Number'),
      (Icons.access_time_rounded,        'Review within 24–48 hours'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:        AppColors.brandPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.info_outline_rounded,
                    color: AppColors.brandPurple, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'What you need',
                style: TextStyle(
                  color:      isDark ? Colors.white : AppColors.textDarkLight,
                  fontSize:   15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(s.$1, color: AppColors.brandPurple, size: 18),
                const SizedBox(width: 10),
                Text(
                  s.$2,
                  style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildKycCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Your Details',
            style: TextStyle(
              color:      isDark ? Colors.white : AppColors.textDarkLight,
              fontSize:   16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          _buildFieldLabel(
            icon:   Icons.credit_card_outlined,
            label:  'Aadhaar Card Number',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller:      _aadhaarCtrl,
            keyboardType:    TextInputType.number,
            maxLength:       12,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textDarkLight,
            ),
            decoration: InputDecoration(
              hintText:  'Enter 12-digit Aadhaar number',
              counterText: '',
              prefixIcon: const Icon(Icons.credit_card_outlined,
                  color: AppColors.brandPurple, size: 20),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Aadhaar number is required';
              if (v.length != 12)         return 'Enter valid 12-digit Aadhaar';
              return null;
            },
          ),

          const SizedBox(height: 16),

          _buildFieldLabel(
            icon:   Icons.assignment_ind_outlined,
            label:  'PAN Card Number',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller:    _panCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength:     10,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textDarkLight,
            ),
            decoration: InputDecoration(
              hintText:   'e.g. ABCDE1234F',
              counterText: '',
              prefixIcon: const Icon(Icons.assignment_ind_outlined,
                  color: AppColors.brandPurple, size: 20),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'PAN number is required';
              final panRegex = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]{1}$');
              if (!panRegex.hasMatch(v.toUpperCase())) {
                return 'Enter valid PAN (e.g. ABCDE1234F)';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel({
    required IconData icon,
    required String   label,
    required bool     isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.brandPurple),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color:      isDark ? AppColors.textMidDark : AppColors.textDarkLight,
            fontSize:   13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitKyc,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSubmitting
            ? const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.verified_user_rounded, size: 20),
        label: Text(
          _isSubmitting ? 'Submitting KYC...' : 'Submit KYC Documents',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isSkipping ? null : _skipKyc,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: _isSkipping
            ? SizedBox(
          width:  18,
          height: 18,
          child:  CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
          ),
        )
            : Icon(
          Icons.skip_next_rounded,
          size:  20,
          color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
        ),
        label: Text(
          'Skip & Complete Later',
          style: TextStyle(
            color:      isDark ? AppColors.textMidDark : AppColors.textMidLight,
            fontSize:   15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}