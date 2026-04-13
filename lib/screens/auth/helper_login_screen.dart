// lib/screens/auth/helper_login_screen.dart
// FIXED: Matches image 3 exactly — light theme, "Welcome back" hero text,
//        curved white card, decorative blob circles at bottom,
//        Google sign-in, email/password fields, "Register Now" link
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import 'helper_register_screen.dart';
import '../dashboard/helper_dashboard.dart';

// ── Design tokens (light-only) ────────────────────────────────────────────────
const _kPurple      = Color(0xFF5B21D4);
const _kPurpleLight = Color(0xFF7C3AED);
const _kBg          = Color(0xFFF0EEFF); // very light lavender bg
const _kCardBg      = Color(0xFFFFFFFF);
const _kText1       = Color(0xFF1A0A3C); // near-black heading
const _kText2       = Color(0xFF4B5563); // body
const _kText3       = Color(0xFF9CA3AF); // hint
const _kBorder      = Color(0xFFE8E3F8);
const _kInputBg     = Color(0xFFF3F0FD);
const _kGreen       = Color(0xFF16A34A);

class HelperLoginScreen extends StatefulWidget {
  const HelperLoginScreen({super.key});
  @override
  State<HelperLoginScreen> createState() => _HelperLoginScreenState();
}

class _HelperLoginScreenState extends State<HelperLoginScreen>
    with SingleTickerProviderStateMixin {

  final _formKey        = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl   = TextEditingController();
  bool  _obscure        = true;
  bool  _isLoading      = false;
  bool  _isGoogleLoading = false;

  late AnimationController _animCtrl;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Handlers ──────────────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final auth    = context.read<AuthProvider>();
    final success = await auth.login(
      identifier: _identifierCtrl.text.trim(),
      password:   _passwordCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      _pushDashboard();
    } else {
      _snack(auth.errorMessage ?? 'Login failed. Please try again.', isError: true);
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isGoogleLoading = true);
    final auth    = context.read<AuthProvider>();
    final success = await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    if (success) {
      _pushDashboard();
    } else if (auth.errorMessage != null) {
      _snack(auth.errorMessage!, isError: true);
    }
  }

  Future<void> _handleForgotPw() async {
    final text = _identifierCtrl.text.trim();
    if (!text.contains('@')) {
      _snack('Enter your email first, then tap Forgot?', isError: true);
      return;
    }
    final auth    = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(text);
    if (!mounted) return;
    _snack(success ? 'Reset link sent to $text' : (auth.errorMessage ?? 'Failed'),
        isError: !success);
  }

  void _pushDashboard() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, a, __) => const HelperDashboard(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: isError ? const Color(0xFFDC2626) : _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        // ── Decorative blobs at bottom (from image 3) ───────────────────
        Positioned(
          bottom: -30, left: -40,
          child: _Blob(size: 180, color: _kPurpleLight.withOpacity(0.22)),
        ),
        Positioned(
          bottom: 30, left: 60,
          child: _Blob(size: 120, color: _kPurple.withOpacity(0.12)),
        ),

        // ── Main scrollable content ─────────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.only(bottom: bottomInset + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Hero heading ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome\nback',
                        style: TextStyle(
                          color: _kText1,
                          fontSize: 44,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Enter your details to continue your journey with\nSarthi Kendra.',
                        style: TextStyle(
                          color: _kText2.withOpacity(0.75),
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── White card with fields ─────────────────────────────
                SlideTransition(
                  position: _slideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildCard(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _kPurple.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(children: [

          // ── Google button ─────────────────────────────────────────────
          _GoogleBtn(loading: _isGoogleLoading, onTap: _handleGoogle),

          const SizedBox(height: 22),

          // ── Divider ───────────────────────────────────────────────────
          Row(children: [
            const Expanded(child: Divider(color: Color(0xFFE5E0F5))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR WITH EMAIL',
                  style: TextStyle(
                      color: _kText3, fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ),
            const Expanded(child: Divider(color: Color(0xFFE5E0F5))),
          ]),

          const SizedBox(height: 22),

          // ── Email field ───────────────────────────────────────────────
          _FieldLabel(text: 'EMAIL ADDRESS'),
          const SizedBox(height: 8),
          _InputField(
            controller: _identifierCtrl,
            hint: 'name@example.com',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Email is required' : null,
          ),

          const SizedBox(height: 20),

          // ── Password field ─────────────────────────────────────────────
          Row(children: [
            const _FieldLabel(text: 'PASSWORD'),
            const Spacer(),
            GestureDetector(
              onTap: _handleForgotPw,
              child: const Text('FORGOT?',
                  style: TextStyle(
                      color: _kPurpleLight, fontSize: 11,
                      fontWeight: FontWeight.w800, letterSpacing: 0.8)),
            ),
          ]),
          const SizedBox(height: 8),
          _InputField(
            controller: _passwordCtrl,
            hint: '• • • • • • • • • •',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            onFieldSubmitted: (_) => _handleLogin(),
            suffix: IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: _kText3, size: 20,
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6)          return 'Minimum 6 characters';
              return null;
            },
          ),

          const SizedBox(height: 28),

          // ── Sign In button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPurple,
                disabledBackgroundColor: _kPurple.withOpacity(0.55),
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: _kPurple.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _isLoading
                    ? const SizedBox(
                  key: ValueKey('ld'),
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
                    : const Text(
                  'Sign In',
                  key: ValueKey('id'),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      letterSpacing: 0.2),
                ),
              ),
            ),
          ),

          const SizedBox(height: 22),

          // ── Register link ─────────────────────────────────────────────
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("Don't have an account? ",
                style: TextStyle(color: _kText2, fontSize: 14)),
            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Register Now',
                  style: TextStyle(
                      color: _kPurpleLight, fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Google button ─────────────────────────────────────────────────────────────
class _GoogleBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _GoogleBtn({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E3F8), width: 1.5),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _kPurple)))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Google logo pill
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Center(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                  children: [
                    TextSpan(text: 'G', style: TextStyle(color: Color(0xFF4285F4))),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('Continue with Google',
              style: TextStyle(
                  color: _kText1, fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ── Shared field label ────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text,
        style: const TextStyle(
            color: _kText2, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 1.1)),
  );
}

// ── Input field ───────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.suffix,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: onFieldSubmitted != null
          ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(
          color: _kText1, fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kText3, fontSize: 14),
        prefixIcon: Icon(icon, color: _kPurple.withOpacity(0.6), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kInputBg,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE8E3F8)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPurple, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
        ),
      ),
      validator: validator,
    );
  }
}

// ── Decorative blob ───────────────────────────────────────────────────────────
class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}