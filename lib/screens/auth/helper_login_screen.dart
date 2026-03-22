// lib/screens/auth/helper_login_screen.dart
// Drop-in replacement – email OR username login + Google Sign-In
// Requires: google_sign_in: ^6.2.1 in pubspec.yaml
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'helper_register_screen.dart';
import '../dashboard/helper_dashboard.dart';

class HelperLoginScreen extends StatefulWidget {
  const HelperLoginScreen({super.key});
  @override
  State<HelperLoginScreen> createState() => _HelperLoginScreenState();
}

class _HelperLoginScreenState extends State<HelperLoginScreen>
    with SingleTickerProviderStateMixin {

  final _formKey        = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController(); // email OR username
  final _passwordCtrl   = TextEditingController();
  bool  _obscure        = true;
  bool  _isLoading      = false;
  bool  _isGoogleLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Email / Password sign in ──────────────────────────────────
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
      _snack(auth.errorMessage ?? 'Login failed. Please try again.', error: true);
    }
  }

  // ── Google Sign In ────────────────────────────────────────────
  Future<void> _handleGoogle() async {
    setState(() => _isGoogleLoading = true);
    final auth    = context.read<AuthProvider>();
    final success = await auth.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (success) {
      _pushDashboard();
    } else {
      if (auth.errorMessage != null) {
        _snack(auth.errorMessage!, error: true);
      }
      // If null error → user cancelled Google picker, no snack needed
    }
  }

  // ── Forgot password ───────────────────────────────────────────
  Future<void> _handleForgotPw() async {
    final text = _identifierCtrl.text.trim();
    if (!text.contains('@')) {
      _snack('Enter your email address first, then tap Forgot Password.', error: true);
      return;
    }
    final auth    = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(text);
    if (!mounted) return;
    _snack(success ? 'Reset link sent to $text' : (auth.errorMessage ?? 'Failed'),
        error: !success);
  }

  void _pushDashboard() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, a, __) => const HelperDashboard(),
      transitionDuration: const Duration(milliseconds: 400),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:         Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
      backgroundColor: error ? AppColors.danger : AppColors.success,
      behavior:        SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
    ));
  }

  // ── Validator ─────────────────────────────────────────────────
  String? _validateId(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email or username is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(children: [
                  _buildCard(isDark),
                  const SizedBox(height: 20),
                  _buildBottomLinks(isDark),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Gradient header ───────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 18,
        bottom: 22, left: 20, right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF3B0764), Color(0xFF5B21B6), Color(0xFF7C3AED)],
        ),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color:        Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Sarthi Kendra',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
          Text('Helper Portal',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
        ]),
      ]),
    );
  }

  // ── Main card ─────────────────────────────────────────────────
  Widget _buildCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight),
        boxShadow: [BoxShadow(
          color: isDark
              ? Colors.black.withOpacity(0.35)
              : const Color(0xFF7C3AED).withOpacity(0.07),
          blurRadius: 28, offset: const Offset(0, 8),
        )],
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // Title
              Text('Welcome back',
                  style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontSize:   26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 4),
              Text('Sign in to your Sarthi dashboard',
                  style: TextStyle(
                      color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                      fontSize: 14)),

              const SizedBox(height: 28),

              // ── Google Sign In Button ─────────────────────────
              _GoogleButton(loading: _isGoogleLoading, onTap: _handleGoogle, isDark: isDark),

              const SizedBox(height: 20),

              // ── Divider ───────────────────────────────────────
              Row(children: [
                Expanded(child: Divider(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or sign in with email',
                      style: TextStyle(
                          color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                          fontSize: 12)),
                ),
                Expanded(child: Divider(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight)),
              ]),

              const SizedBox(height: 20),

              // ── Email / Username ──────────────────────────────
              _Label(icon: Icons.alternate_email_rounded, text: 'Email or Username', isDark: isDark),
              const SizedBox(height: 8),
              TextFormField(
                controller:      _identifierCtrl,
                keyboardType:    TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect:     false,
                style: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText:  'Enter email or username',
                  // ← Critical fix: explicit light hint style
                  hintStyle: TextStyle(
                      color:      isDark
                          ? const Color(0xFF484F58)   // dark mode: very muted
                          : const Color(0xFFADB5BD),  // light mode: light grey
                      fontSize:   15, fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(Icons.person_outline_rounded,
                      color: AppColors.brandPurple, size: 20),
                ),
                validator: _validateId,
              ),

              const SizedBox(height: 18),

              // ── Password ──────────────────────────────────────
              Row(children: [
                _Label(icon: Icons.lock_outline_rounded, text: 'Password', isDark: isDark),
                const Spacer(),
                GestureDetector(
                  onTap: _handleForgotPw,
                  child: const Text('Forgot password?',
                      style: TextStyle(
                          color: AppColors.brandPurple, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              TextFormField(
                controller:       _passwordCtrl,
                obscureText:      _obscure,
                textInputAction:  TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                style: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText:  'Enter your password',
                  hintStyle: TextStyle(
                      color:    isDark ? const Color(0xFF484F58) : const Color(0xFFADB5BD),
                      fontSize: 15, fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(Icons.lock_outline_rounded,
                      color: AppColors.brandPurple, size: 20),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: isDark ? AppColors.textMidDark : AppColors.textSoftLight,
                      size:  20,
                    ),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Password is required';
                  if (v.length < 6)           return 'Minimum 6 characters';
                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ── Sign In Button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isLoading
                        ? const SizedBox(
                        key: ValueKey('ld'),
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                        : const Row(
                      key: ValueKey('id'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login_rounded, size: 19),
                        SizedBox(width: 8),
                        Text('Sign In',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),

        // Bottom gradient bar
        Container(
          height: 4,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(22), bottomRight: Radius.circular(22)),
            gradient: LinearGradient(
                colors: [AppColors.brandPurple, AppColors.cyanAccent]),
          ),
        ),
      ]),
    );
  }

  // ── Register + platform info ──────────────────────────────────
  Widget _buildBottomLinks(bool isDark) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Don't have an account? ",
            style: TextStyle(
                color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                fontSize: 13)),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const HelperRegisterScreen())),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('Register as Sarthi',
                style: TextStyle(
                    color: AppColors.brandPurple, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 3),
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  color:        AppColors.brandPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(5)),
              child: const Icon(Icons.arrow_forward_rounded,
                  size: 13, color: AppColors.brandPurple),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 16),
      // Trust row (replacing "Secure Login" badge)
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.lock_rounded, size: 12,
            color: isDark ? AppColors.textSoftDark : AppColors.textSoftLight),
        const SizedBox(width: 5),
        Text('Secured by Firebase · 256-bit encryption',
            style: TextStyle(
                color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                fontSize: 11)),
      ]),
      const SizedBox(height: 6),
      Text('© 2024 Sarthi Kendra · Trouble Sarthi Platform',
          style: TextStyle(
              color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
              fontSize: 11)),
    ]);
  }
}

// ── Google button ─────────────────────────────────────────────────────────────
class _GoogleButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  final bool isDark;
  const _GoogleButton({
    required this.loading, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width:   double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color:        isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFDEE2E6),
              width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          // Google 'G' logo
          if (!loading) ...[
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.1), blurRadius: 4)],
              ),
              child: CustomPaint(painter: _GoogleGPainter()),
            ),
            const SizedBox(width: 10),
            Text('Continue with Google',
                style: TextStyle(
                    color:      isDark ? Colors.white : AppColors.textDarkLight,
                    fontSize:   15, fontWeight: FontWeight.w600)),
          ] else ...[
            SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: isDark ? AppColors.textMidDark : AppColors.textMidLight)),
            const SizedBox(width: 10),
            Text('Signing in...',
                style: TextStyle(
                    color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                    fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ]),
      ),
    );
  }
}

/// Draws the Google 'G' icon using Canvas
class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width * 0.42;

    // Blue arc
    final blue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -0.5, 3.8, false, blue);

    // Red arc
    final red = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.3, 1.2, false, red);

    // Yellow arc
    final yellow = Paint()
      ..color = const Color(0xFFFBBC04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        2.4, 0.9, false, yellow);

    // Green arc
    final green = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18;
    canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        1.55, 0.85, false, green);

    // White horizontal bar (the crossbar of G)
    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + r, cy),
        bar);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Shared label widget ───────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final IconData icon; final String text; final bool isDark;
  const _Label({required this.icon, required this.text, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: AppColors.brandPurple),
      const SizedBox(width: 6),
      Text(text, style: TextStyle(
          color:      isDark ? AppColors.textMidDark : AppColors.textDarkLight,
          fontSize:   13, fontWeight: FontWeight.w600)),
    ]);
  }
}