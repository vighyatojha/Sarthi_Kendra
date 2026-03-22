// lib/screens/auth/helper_register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/smooth_route.dart';
import '../kyc/kyc_screen.dart';

class HelperRegisterScreen extends StatefulWidget {
  const HelperRegisterScreen({super.key});
  @override
  State<HelperRegisterScreen> createState() => _HelperRegisterScreenState();
}

class _HelperRegisterScreenState extends State<HelperRegisterScreen>
    with SingleTickerProviderStateMixin {

  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _areaCtrl     = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  bool _agreedToTerms  = false;
  int  _currentStep    = 0;

  final List<String> _allServices = [
    'Plumber', 'Electrician', 'AC Repair', 'Carpenter',
    'Painter', 'House Cleaning', 'Appliance Repair',
    'Pest Control', 'Security Guard', 'Driver',
    'Cook / Chef', 'Gardener', 'Tutor',
  ];
  final Set<String> _selectedServices = {};

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _currentStep = 1);
    _animCtrl.reset();
    _animCtrl.forward();
  }

  void _prevStep() {
    setState(() => _currentStep = 0);
    _animCtrl.reset();
    _animCtrl.forward();
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    if (_selectedServices.isEmpty) {
      _showSnack('Select at least one service.', isError: true); return;
    }
    if (_areaCtrl.text.trim().isEmpty) {
      _showSnack('Please enter your service area.', isError: true); return;
    }
    if (!_agreedToTerms) {
      _showSnack('Please agree to Terms & Conditions.', isError: true); return;
    }

    setState(() => _isLoading = true);

    final auth    = context.read<AuthProvider>();
    final success = await auth.register(
      name:     _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      services: _selectedServices.toList(),
      area:     _areaCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushAndRemoveUntil(
        SmoothRoute(page: const KycScreen()),
            (_) => false,
      );
    } else {
      _showSnack(auth.errorMessage ?? 'Registration failed.', isError: true);
    }
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
      body: Column(children: [
        _buildHeader(isDark),
        _buildStepIndicator(isDark),
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: _currentStep == 0
                  ? _buildStep1(isDark)
                  : _buildStep2(isDark),
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
        top:    MediaQuery.of(context).padding.top + 12,
        bottom: 16, left: 8, right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft, end: Alignment.bottomRight,
          colors: [AppColors.gradientStart, AppColors.gradientMid, AppColors.gradientEnd],
        ),
      ),
      child: Row(children: [
        IconButton(
          onPressed: () => _currentStep == 0 ? Navigator.pop(context) : _prevStep(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
        ),
        const Expanded(child: Text('Create Sarthi Account',
            style: TextStyle(color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.w700))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Step ${_currentStep + 1} / 2',
              style: const TextStyle(
                  color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Container(
      color:   isDark ? AppColors.cardDark : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(children: [
        _StepDot(number: 1, label: 'Personal Info',
            active: _currentStep == 0, done: _currentStep > 0),
        Expanded(child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          color: _currentStep > 0
              ? AppColors.brandPurple
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        )),
        _StepDot(number: 2, label: 'Services',
            active: _currentStep == 1, done: false),
      ]),
    );
  }

  Widget _buildStep1(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(children: [
        _Card(isDark: isDark, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardTitle('Personal Details', isDark: isDark),
          const SizedBox(height: 16),
          _Field(controller: _nameCtrl, label: 'Full Name',
              hint: 'Ramesh Kumar', icon: Icons.person_outline_rounded,
              isDark: isDark,
              validator: (v) => v!.isEmpty ? 'Name is required' : null),
          const SizedBox(height: 14),
          _Field(controller: _phoneCtrl, label: 'Mobile Number',
              hint: '9876543210', icon: Icons.phone_android_rounded,
              isDark: isDark, inputType: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10)],
              validator: (v) {
                if (v!.isEmpty)  return 'Phone is required';
                if (v.length != 10) return 'Enter 10-digit number';
                return null;
              }),
          const SizedBox(height: 14),
          _Field(controller: _emailCtrl, label: 'Email Address',
              hint: 'ramesh@gmail.com', icon: Icons.email_outlined,
              isDark: isDark, inputType: TextInputType.emailAddress,
              validator: (v) {
                if (v!.isEmpty)       return 'Email is required';
                if (!v.contains('@')) return 'Invalid email';
                return null;
              }),
        ])),
        const SizedBox(height: 16),
        _Card(isDark: isDark, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          _CardTitle('Set Password', isDark: isDark),
          const SizedBox(height: 16),
          _PasswordField(
              controller: _passwordCtrl, label: 'Password',
              obscure: _obscurePass, isDark: isDark,
              onToggle: () => setState(() => _obscurePass = !_obscurePass),
              validator: (v) {
                if (v!.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Minimum 6 characters';
                return null;
              }),
          const SizedBox(height: 14),
          _PasswordField(
              controller: _confirmCtrl, label: 'Confirm Password',
              obscure: _obscureConfirm, isDark: isDark,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) =>
              v != _passwordCtrl.text ? 'Passwords do not match' : null),
        ])),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _nextStep,
            icon:  const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continue to Services'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: RichText(text: TextSpan(
            text:  'Already have an account? ',
            style: TextStyle(
              color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize: 13,
            ),
            children: const [TextSpan(
              text:  'Login →',
              style: TextStyle(
                  color: AppColors.brandPurple, fontWeight: FontWeight.w700),
            )],
          )),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _buildStep2(bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Info banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColors.brandPurple.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.brandPurple.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.brandPurple, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'After registration, upload KYC documents. '
                'Your account will be activated after admin verification.',
            style: TextStyle(
              color:    isDark ? AppColors.lightPurple : AppColors.brandPurple,
              fontSize: 12, height: 1.5,
            ),
          )),
        ]),
      ),
      const SizedBox(height: 16),

      _Card(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CardTitle('Service Area', isDark: isDark),
        const SizedBox(height: 12),
        TextFormField(
          controller: _areaCtrl,
          style: TextStyle(color: isDark ? Colors.white : AppColors.textDarkLight),
          decoration: const InputDecoration(
            hintText:   'e.g. Vesu, Surat',
            prefixIcon: Icon(Icons.location_on_outlined,
                color: AppColors.brandPurple, size: 20),
          ),
        ),
      ])),
      const SizedBox(height: 16),

      _Card(isDark: isDark, child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _CardTitle('Select Services', isDark: isDark),
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:        AppColors.brandPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('${_selectedServices.length} selected',
                style: const TextStyle(
                    color: AppColors.brandPurple,
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 4),
        Text('Select all services you can provide',
            style: TextStyle(
                color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 12)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _allServices.map((svc) {
            final selected = _selectedServices.contains(svc);
            return GestureDetector(
              onTap: () => setState(() => selected
                  ? _selectedServices.remove(svc)
                  : _selectedServices.add(svc)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.brandPurple
                      : (isDark ? AppColors.surfaceDark : AppColors.bgLight),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? AppColors.brandPurple
                        : (isDark ? AppColors.borderDark : AppColors.borderLight),
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selected) ...[
                    const Icon(Icons.check_circle_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(svc, style: TextStyle(
                    color:      selected ? Colors.white
                        : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
                    fontSize:   13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  )),
                ]),
              ),
            );
          }).toList(),
        ),
      ])),
      const SizedBox(height: 16),

      // Terms
      GestureDetector(
        onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22, height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color:        _agreedToTerms ? AppColors.brandPurple : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _agreedToTerms
                    ? AppColors.brandPurple
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: 2,
              ),
            ),
            child: _agreedToTerms
                ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(child: RichText(text: TextSpan(
            text: 'I agree to the ',
            style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13),
            children: const [
              TextSpan(text: 'Terms & Conditions',
                  style: TextStyle(
                      color: AppColors.brandPurple, fontWeight: FontWeight.w600)),
              TextSpan(text: ' and '),
              TextSpan(text: 'Privacy Policy',
                  style: TextStyle(
                      color: AppColors.brandPurple, fontWeight: FontWeight.w600)),
            ],
          ))),
        ]),
      ),
      const SizedBox(height: 24),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleRegister,
          icon: _isLoading
              ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.how_to_reg_rounded, size: 20),
          label: Text(
            _isLoading ? 'Creating Account...' : 'Create Account',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label, hint;
  final IconData                   icon;
  final bool                       isDark;
  final TextInputType?             inputType;
  final List<TextInputFormatter>?  formatters;
  final String? Function(String?)? validator;
  const _Field({required this.controller, required this.label,
    required this.hint, required this.icon, required this.isDark,
    this.inputType, this.formatters, this.validator});

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(
        color:      isDark ? AppColors.textMidDark : AppColors.textDarkLight,
        fontSize:   13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller, keyboardType: inputType,
      inputFormatters: formatters,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textDarkLight),
      decoration: InputDecoration(
        hintText:   hint,
        prefixIcon: Icon(icon, color: AppColors.brandPurple, size: 20),
      ),
      validator: validator,
    ),
  ]);
}

class _PasswordField extends StatelessWidget {
  final TextEditingController      controller;
  final String                     label;
  final bool                       obscure, isDark;
  final VoidCallback               onToggle;
  final String? Function(String?)? validator;
  const _PasswordField({required this.controller, required this.label,
    required this.obscure, required this.isDark,
    required this.onToggle, this.validator});

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(
        color:      isDark ? AppColors.textMidDark : AppColors.textDarkLight,
        fontSize:   13, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    TextFormField(
      controller: controller, obscureText: obscure,
      style: TextStyle(color: isDark ? Colors.white : AppColors.textDarkLight),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline_rounded,
            color: AppColors.brandPurple, size: 20),
        suffixIcon: GestureDetector(
          onTap: onToggle,
          child: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: isDark ? AppColors.textMidDark : AppColors.textSoftLight,
            size: 20,
          ),
        ),
      ),
      validator: validator,
    ),
  ]);
}

class _Card extends StatelessWidget {
  final Widget child;
  final bool   isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color:        isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight),
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  final String text;
  final bool   isDark;
  const _CardTitle(this.text, {required this.isDark});

  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(
      color:      isDark ? Colors.white : AppColors.textDarkLight,
      fontSize:   16, fontWeight: FontWeight.w700));
}

class _StepDot extends StatelessWidget {
  final int    number;
  final String label;
  final bool   active, done;
  const _StepDot({required this.number, required this.label,
    required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 28, height: 28,
        decoration: BoxDecoration(
          color:  done || active ? AppColors.brandPurple : Colors.transparent,
          shape:  BoxShape.circle,
          border: Border.all(
            color: done || active ? AppColors.brandPurple
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: 2,
          ),
        ),
        child: Center(child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text('$number', style: TextStyle(
            color:      active ? Colors.white
                : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
            fontSize:   12, fontWeight: FontWeight.w700))),
      ),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(
          color:      active || done ? AppColors.brandPurple
              : (isDark ? AppColors.textMidDark : AppColors.textMidLight),
          fontSize:   10, fontWeight: FontWeight.w600)),
    ]);
  }
}