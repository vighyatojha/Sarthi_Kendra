// lib/screens/auth/register_screen.dart
// FIXED: Light theme, password strength bar, curved card section,
//        curve divider between purple header and white body
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../kyc/kyc_screen.dart';

// ── Tokens (light-only) ───────────────────────────────────────────────────────
const _kPurple      = Color(0xFF5B21D4);
const _kPurpleLight = Color(0xFF7C3AED);
const _kBg          = Color(0xFFF0EEFF);
const _kCardBg      = Color(0xFFFFFFFF);
const _kText1       = Color(0xFF1A0A3C);
const _kText2       = Color(0xFF4B5563);
const _kText3       = Color(0xFF9CA3AF);
const _kBorder      = Color(0xFFE8E3F8);
const _kInputBg     = Color(0xFFF3F0FD);

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  bool _googleLoading  = false;

  // Password strength (0.0 – 1.0)
  double _passStrength = 0.0;
  String _passLabel    = '';
  Color  _passColor    = Colors.transparent;

  @override
  void initState() {
    super.initState();
    _passCtrl.addListener(_evalPassword);
  }

  void _evalPassword() {
    final p = _passCtrl.text;
    double score = 0;
    if (p.length >= 6)                                          score += 0.2;
    if (p.length >= 10)                                         score += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(p))                           score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(p))                           score += 0.2;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(p))        score += 0.2;

    String label; Color color;
    if (p.isEmpty) { label = ''; color = Colors.transparent; }
    else if (score <= 0.2) { label = 'Very weak'; color = const Color(0xFFEF4444); }
    else if (score <= 0.4) { label = 'Weak';      color = const Color(0xFFF97316); }
    else if (score <= 0.6) { label = 'Fair';      color = const Color(0xFFF59E0B); }
    else if (score <= 0.8) { label = 'Strong';    color = const Color(0xFF22C55E); }
    else                   { label = 'Very strong'; color = const Color(0xFF16A34A); }

    setState(() { _passStrength = score; _passLabel = label; _passColor = color; });
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final ok   = await auth.register(
      name:     _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      services: [],
      area:     '',
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      _goToKyc();
    } else {
      _snack(auth.errorMessage ?? 'Registration failed. Try again.', err: true);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => _googleLoading = true);
    final auth = context.read<AuthProvider>();
    final ok   = await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _googleLoading = false);
    if (ok) {
      _goToKyc();
    } else if (auth.errorMessage != null) {
      _snack(auth.errorMessage!, err: true);
    }
  }

  void _goToKyc() => Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const KycScreen()));

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(children: [
        // ── Purple header with curved bottom ──────────────────────────
        _buildHeader(),
        // ── Scrollable form body ────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _buildGoogleBtn(),
                const SizedBox(height: 18),
                _buildDivider(),
                const SizedBox(height: 18),
                _buildFormCard(),
                const SizedBox(height: 20),
                _buildRegisterBtn(),
                const SizedBox(height: 16),
                _buildLoginLink(),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Purple header (curved bottom) ────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B0764), Color(0xFF5B21B6)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.25)),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 16),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Create Account',
                style: TextStyle(color: Colors.white,
                    fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('Join as a Sarthi helper and start earning',
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 13)),
          ]),
        ),
      ),
    );
  }

  Widget _buildGoogleBtn() {
    return GestureDetector(
      onTap: _googleLoading ? null : _googleSignIn,
      child: Container(
        width: double.infinity, height: 52,
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder, width: 1.5),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: _googleLoading
            ? const Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _kPurple)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Center(child: Text('G',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                    color: Color(0xFF4285F4)))),
          ),
          const SizedBox(width: 10),
          const Text('Continue with Google',
              style: TextStyle(color: _kText1, fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider(color: Color(0xFFE5E0F5))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or register with email',
            style: TextStyle(fontSize: 12, color: _kText3)),
      ),
      const Expanded(child: Divider(color: Color(0xFFE5E0F5))),
    ]);
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
            color: _kPurple.withOpacity(0.06),
            blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(children: [
        _RegField(ctrl: _nameCtrl, label: 'FULL NAME',
            hint: 'Ramesh Kumar', icon: Icons.badge_outlined,
            color: _kPurple,
            validator: (v) => v!.trim().isEmpty ? 'Name is required' : null),
        const SizedBox(height: 14),
        _RegField(ctrl: _emailCtrl, label: 'EMAIL ADDRESS',
            hint: 'ramesh@email.com', icon: Icons.email_outlined,
            color: const Color(0xFF0284C7),
            inputType: TextInputType.emailAddress,
            validator: (v) {
              if (v!.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v))
                return 'Enter a valid email';
              return null;
            }),
        const SizedBox(height: 14),
        _RegField(ctrl: _phoneCtrl, label: 'MOBILE NUMBER',
            hint: '9876543210', icon: Icons.phone_android_rounded,
            color: const Color(0xFF059669),
            inputType: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10)],
            validator: (v) {
              if (v!.isEmpty) return 'Phone is required';
              if (v.length != 10) return 'Enter 10-digit number';
              return null;
            }),
        const SizedBox(height: 14),

        // ── Password with strength bar ─────────────────────────────────
        _PassField(ctrl: _passCtrl, label: 'PASSWORD',
            obscure: _obscurePass,
            onToggle: () => setState(() => _obscurePass = !_obscurePass),
            validator: (v) {
              if (v!.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            }),
        // Strength bar
        if (_passCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _StrengthBar(strength: _passStrength, label: _passLabel,
              color: _passColor),
        ],

        const SizedBox(height: 14),
        _PassField(ctrl: _confirmCtrl, label: 'CONFIRM PASSWORD',
            obscure: _obscureConfirm,
            onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (v) {
              if (v!.isEmpty) return 'Please confirm your password';
              if (v != _passCtrl.text) return 'Passwords do not match';
              return null;
            }),
      ]),
    );
  }

  Widget _buildRegisterBtn() {
    return GestureDetector(
      onTap: _loading ? null : _register,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity, height: 54,
        decoration: BoxDecoration(
          gradient: _loading
              ? const LinearGradient(colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)])
              : const LinearGradient(
              colors: [Color(0xFF4C1D95), _kPurple, Color(0xFF9333EA)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _loading ? [] : [BoxShadow(
              color: _kPurple.withOpacity(0.35),
              blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_loading)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(_loading ? 'Creating account...' : 'Create Account',
              style: const TextStyle(color: Colors.white,
                  fontSize: 15, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Already have an account? ',
          style: TextStyle(color: _kText2, fontSize: 13)),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Text('Sign In',
            style: TextStyle(color: _kPurpleLight,
                fontSize: 13, fontWeight: FontWeight.w800)),
      ),
    ]);
  }
}

// ── Password strength bar ─────────────────────────────────────────────────────
class _StrengthBar extends StatelessWidget {
  final double strength;
  final String label;
  final Color color;
  const _StrengthBar({required this.strength, required this.label,
    required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: List.generate(5, (i) {
        final filled = (i + 1) <= (strength * 5).ceil();
        return Expanded(child: Container(
          margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
          height: 4,
          decoration: BoxDecoration(
            color: filled ? color : const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(2),
          ),
        ));
      })),
      const SizedBox(height: 5),
      Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    ]);
  }
}

// ── Regular form field ────────────────────────────────────────────────────────
class _RegField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final Color color;
  final TextInputType? inputType;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;

  const _RegField({required this.ctrl, required this.label, required this.hint,
    required this.icon, required this.color, this.inputType,
    this.formatters, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: _kText2, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        inputFormatters: formatters,
        style: const TextStyle(color: _kText1, fontSize: 14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _kText3, fontSize: 13),
          prefixIcon: Icon(icon, color: color, size: 18),
          filled: true, fillColor: _kInputBg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          isDense: true,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _kPurple, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        ),
        validator: validator,
      ),
    ]);
  }
}

// ── Password field ────────────────────────────────────────────────────────────
class _PassField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;

  const _PassField({required this.ctrl, required this.label,
    required this.obscure, required this.onToggle, this.validator});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(
          color: _kText2, fontSize: 10,
          fontWeight: FontWeight.w700, letterSpacing: 1.1)),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: const TextStyle(color: _kText1, fontSize: 14,
            fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: '• • • • • • • •',
          hintStyle: const TextStyle(color: _kText3, fontSize: 13),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: _kPurple, size: 18),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: _kText3, size: 18,
            ),
          ),
          filled: true, fillColor: _kInputBg,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
          isDense: true,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: _kPurple, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFDC2626))),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5)),
        ),
        validator: validator,
      ),
    ]);
  }
}