// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../kyc/kyc_screen.dart';

const _purple     = Color(0xFF7C3AED);
const _purpleDeep = Color(0xFF3B0764);
const _purpleLight= Color(0xFFEDE9FE);

extension _Op on Color {
  Color op(double a) => withValues(alpha: a);
}

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

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name:     _nameCtrl.text.trim(),
      email:    _emailCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      phone:    _phoneCtrl.text.trim(),
      services: [],   // services collected in edit profile later
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

  void _goToKyc() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const KycScreen()),
    );
  }

  void _snack(String msg, {bool err = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: err ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF2F4F8),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Form(
              key: _formKey,
              child: Column(children: [
                _buildGoogleBtn(isDark),
                const SizedBox(height: 20),
                _buildDivider(),
                const SizedBox(height: 20),
                _buildCard(isDark),
                const SizedBox(height: 20),
                _buildRegisterBtn(),
                const SizedBox(height: 16),
                _buildLoginLink(isDark),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildHeader() {
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
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.op(0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: Colors.white.op(0.20)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 16),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Join as Helper',
            style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Create your account and start earning',
            style: TextStyle(
                color: Colors.white.op(0.65), fontSize: 13)),
      ]),
    );
  }

  Widget _buildGoogleBtn(bool isDark) {
    return GestureDetector(
      onTap: _googleLoading ? null : _googleSignIn,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A24) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark
                  ? const Color(0xFF2D2D3D)
                  : const Color(0xFFE8E4F3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.op(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: _googleLoading
            ? const Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: _purple)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Google G icon
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Center(
              child: Text('G',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF4285F4))),
            ),
          ),
          const SizedBox(width: 10),
          Text('Continue with Google',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              )),
        ]),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider()),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('or register with email',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500)),
      ),
      const Expanded(child: Divider()),
    ]);
  }

  Widget _buildCard(bool isDark) {
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
      child: Column(children: [
        _field(
          ctrl: _nameCtrl, isDark: isDark,
          label: 'Full Name',
          hint: 'Ramesh Kumar',
          icon: Icons.badge_outlined,
          color: _purple,
          validator: (v) =>
          v!.trim().isEmpty ? 'Name is required' : null,
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _emailCtrl, isDark: isDark,
          label: 'Email Address',
          hint: 'ramesh@email.com',
          icon: Icons.email_outlined,
          color: const Color(0xFF0284C7),
          inputType: TextInputType.emailAddress,
          validator: (v) {
            if (v!.isEmpty) return 'Email is required';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _field(
          ctrl: _phoneCtrl, isDark: isDark,
          label: 'Mobile Number',
          hint: '9876543210',
          icon: Icons.phone_android_rounded,
          color: const Color(0xFF059669),
          inputType: TextInputType.phone,
          formatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: (v) {
            if (v!.isEmpty) return 'Phone is required';
            if (v.length != 10) return 'Enter valid 10-digit number';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _passwordField(
          ctrl: _passCtrl, isDark: isDark,
          label: 'Password',
          obscure: _obscurePass,
          onToggle: () => setState(() => _obscurePass = !_obscurePass),
          validator: (v) {
            if (v!.isEmpty) return 'Password is required';
            if (v.length < 6) return 'Minimum 6 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _passwordField(
          ctrl: _confirmCtrl, isDark: isDark,
          label: 'Confirm Password',
          obscure: _obscureConfirm,
          onToggle: () =>
              setState(() => _obscureConfirm = !_obscureConfirm),
          validator: (v) {
            if (v!.isEmpty) return 'Please confirm your password';
            if (v != _passCtrl.text) return 'Passwords do not match';
            return null;
          },
        ),
      ]),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required bool isDark,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType? inputType,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    final sub = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final txt = isDark ? Colors.white : const Color(0xFF111827);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sub)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: inputType,
        inputFormatters: formatters,
        style: TextStyle(
            color: txt, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: isDark
                  ? const Color(0xFF484F58)
                  : const Color(0xFFADB5BD),
              fontSize: 13),
          prefixIcon: Icon(icon, color: color, size: 16),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 11),
          isDense: true,
          filled: true,
          fillColor:
          isDark ? const Color(0xFF23232F) : color.op(0.03),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color:
                isDark ? const Color(0xFF2D2D3D) : color.op(0.18)),
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
        ),
        validator: validator,
      ),
    ]);
  }

  Widget _passwordField({
    required TextEditingController ctrl,
    required bool isDark,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    final sub = isDark
        ? const Color(0xFF9CA3AF)
        : const Color(0xFF6B7280);
    final txt = isDark ? Colors.white : const Color(0xFF111827);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(Icons.lock_outline_rounded, size: 11, color: _purple),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sub)),
      ]),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(
            color: txt, fontSize: 13, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: '••••••••',
          hintStyle: TextStyle(
              color: isDark
                  ? const Color(0xFF484F58)
                  : const Color(0xFFADB5BD),
              fontSize: 13),
          prefixIcon: const Icon(Icons.lock_outline_rounded,
              color: _purple, size: 16),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: sub,
              size: 18,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 11),
          isDense: true,
          filled: true,
          fillColor:
          isDark ? const Color(0xFF23232F) : _purple.op(0.03),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2D2D3D)
                    : _purple.op(0.18)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: _purple, width: 1.5),
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
        ),
        validator: validator,
      ),
    ]);
  }

  Widget _buildRegisterBtn() {
    return GestureDetector(
      onTap: _loading ? null : _register,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: _loading
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
          boxShadow: _loading
              ? []
              : [
            BoxShadow(
                color: _purple.op(0.38),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_loading)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
          else
            const Icon(Icons.arrow_forward_rounded,
                color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            _loading ? 'Creating account...' : 'Create Account',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800),
          ),
        ]),
      ),
    );
  }

  Widget _buildLoginLink(bool isDark) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('Already have an account? ',
          style: TextStyle(
              color: isDark
                  ? const Color(0xFF9CA3AF)
                  : const Color(0xFF6B7280),
              fontSize: 13)),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: const Text('Sign In',
            style: TextStyle(
                color: _purple,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}