// lib/screens/auth/helper_login_screen.dart
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

  final _formKey         = GlobalKey<FormState>();
  final _identifierCtrl  = TextEditingController();
  final _passwordCtrl    = TextEditingController();

  bool  _obscurePass     = true;
  bool  _isLoading       = false;

  // Tracks what kind of identifier the user is typing
  _IdentifierType _identifierType = _IdentifierType.email;

  late final AnimationController _animCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 550),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();

    _identifierCtrl.addListener(_detectIdentifierType);
  }

  // Auto-detect whether user is entering email or phone
  void _detectIdentifierType() {
    final text = _identifierCtrl.text.trim();
    _IdentifierType newType;

    if (text.contains('@')) {
      newType = _IdentifierType.email;
    } else if (RegExp(r'^\d+$').hasMatch(text)) {
      newType = _IdentifierType.phone;
    } else {
      newType = _IdentifierType.email;
    }

    if (newType != _identifierType) {
      setState(() => _identifierType = newType);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _identifierCtrl.removeListener(_detectIdentifierType);
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

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
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder:        (_, a, __) => const HelperDashboard(),
          transitionDuration: const Duration(milliseconds: 400),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    } else {
      _showSnack(auth.errorMessage ?? 'Login failed. Try again.', isError: true);
    }
  }

  Future<void> _handleForgotPassword() async {
    final identifier = _identifierCtrl.text.trim();
    if (identifier.isEmpty) {
      _showSnack('Enter your email first, then tap Forgot Password.');
      return;
    }

    // Only send reset if it looks like an email
    if (!identifier.contains('@')) {
      _showSnack(
        'Password reset requires your email address.',
        isError: true,
      );
      return;
    }

    final auth    = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(identifier);
    if (!mounted) return;
    _showSnack(
      success
          ? 'Reset link sent to $identifier'
          : auth.errorMessage ?? 'Could not send reset email.',
      isError: !success,
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      ),
    );
  }

  // ── Validator ──────────────────────────────────────────────────
  String? _validateIdentifier(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email or phone is required';
    final t = v.trim();
    if (t.contains('@')) {
      if (!t.contains('.')) return 'Enter a valid email address';
    } else if (RegExp(r'^\d+$').hasMatch(t)) {
      if (t.length != 10) return 'Enter a valid 10-digit phone number';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    children: [
                      _buildLoginCard(isDark),
                      const SizedBox(height: 20),
                      _buildTrustBadges(isDark),
                      const SizedBox(height: 16),
                      Text(
                        '© 2024 Sarthi Kendra · Trouble Sarthi Platform',
                        style: TextStyle(
                          color:    isDark
                              ? AppColors.textSoftDark
                              : AppColors.textSoftLight,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────
  Widget _buildHeader() {
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
          colors: [
            AppColors.gradientStart,
            AppColors.gradientMid,
            AppColors.gradientEnd,
          ],
        ),
      ),
      child: Row(
        children: [
          // Logo icon
          Container(
            width:  46,
            height: 46,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.handshake_rounded,
              color: Colors.white,
              size:  24,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sarthi Kendra',
                style: TextStyle(
                  color:      Colors.white,
                  fontSize:   20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Helper Portal',
                style: TextStyle(
                  color:    Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Login card ─────────────────────────────────────────────────
  Widget _buildLoginCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : AppColors.brandPurple.withOpacity(0.05),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Title ──────────────────────────────────────
                  Text(
                    'Welcome back',
                    style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontSize:   26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign in to your Sarthi dashboard',
                    style: TextStyle(
                      color:    isDark
                          ? AppColors.textMidDark
                          : AppColors.textMidLight,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Identifier field (Email or Phone) ──────────
                  _FieldLabel(
                    icon:   _identifierType == _IdentifierType.phone
                        ? Icons.phone_android_rounded
                        : Icons.person_outline_rounded,
                    label:  'Email or Phone Number',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),

                  // Animated type pill
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _identifierType == _IdentifierType.phone
                        ? _LoginTypePill(
                      key:   const ValueKey('phone'),
                      label: 'Logging in with Phone',
                      icon:  Icons.phone_android_rounded,
                      color: AppColors.success,
                    )
                        : _LoginTypePill(
                      key:   const ValueKey('email'),
                      label: 'Logging in with Email',
                      icon:  Icons.email_outlined,
                      color: AppColors.brandPurple,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller:      _identifierCtrl,
                    keyboardType:    _identifierType == _IdentifierType.phone
                        ? TextInputType.phone
                        : TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect:     false,
                    style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontWeight: FontWeight.w500,
                      fontSize:   15,
                    ),
                    decoration: InputDecoration(
                      hintText:  _identifierType == _IdentifierType.phone
                          ? '9876543210'
                          : 'helper@email.com',
                      // ← Fixed: explicit hint style so it's clearly a placeholder
                      hintStyle: TextStyle(
                        color:      isDark
                            ? AppColors.textSoftDark
                            : AppColors.textSoftLight,
                        fontWeight: FontWeight.w400,
                        fontSize:   15,
                      ),
                      prefixIcon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _identifierType == _IdentifierType.phone
                              ? Icons.phone_android_rounded
                              : Icons.alternate_email_rounded,
                          key:   ValueKey(_identifierType),
                          color: AppColors.brandPurple,
                          size:  20,
                        ),
                      ),
                    ),
                    validator: _validateIdentifier,
                  ),

                  // Helper chips below the field
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _QuickHint(
                        label: 'Use Email',
                        icon:  Icons.email_outlined,
                        isDark: isDark,
                        onTap: () {
                          if (_identifierCtrl.text.isEmpty ||
                              RegExp(r'^\d+$').hasMatch(_identifierCtrl.text)) {
                            _identifierCtrl.clear();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _QuickHint(
                        label: 'Use Phone',
                        icon:  Icons.phone_android_rounded,
                        isDark: isDark,
                        onTap: () {
                          if (_identifierCtrl.text.isEmpty ||
                              _identifierCtrl.text.contains('@')) {
                            _identifierCtrl.clear();
                          }
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Password ───────────────────────────────────
                  Row(
                    children: [
                      _FieldLabel(
                        icon:   Icons.lock_outline_rounded,
                        label:  'Password',
                        isDark: isDark,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _handleForgotPassword,
                        child: const Text(
                          'Forgot password?',
                          style: TextStyle(
                            color:      AppColors.brandPurple,
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  TextFormField(
                    controller:       _passwordCtrl,
                    obscureText:      _obscurePass,
                    textInputAction:  TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontWeight: FontWeight.w500,
                      fontSize:   15,
                    ),
                    decoration: InputDecoration(
                      hintText:  'Enter your password',
                      hintStyle: TextStyle(
                        color:      isDark
                            ? AppColors.textSoftDark
                            : AppColors.textSoftLight,
                        fontWeight: FontWeight.w400,
                        fontSize:   15,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.brandPurple,
                        size:  20,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () =>
                            setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: isDark
                              ? AppColors.textMidDark
                              : AppColors.textSoftLight,
                          size: 20,
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

                  // ── Login button ───────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: _isLoading
                            ? const SizedBox(
                          key:    ValueKey('loading'),
                          width:  20,
                          height: 20,
                          child:  CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color:       Colors.white,
                          ),
                        )
                            : const Row(
                          key:             ValueKey('idle'),
                          mainAxisSize:    MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.login_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize:   16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Register link ──────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'New to the platform?',
                          style: TextStyle(
                            color:    isDark
                                ? AppColors.textMidDark
                                : AppColors.textMidLight,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 6),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelperRegisterScreen(),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Register as a New Sarthi',
                                style: TextStyle(
                                  color:      AppColors.gradientEnd,
                                  fontSize:   14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color:        AppColors.gradientEnd
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size:  14,
                                  color: AppColors.gradientEnd,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom gradient bar
          Container(
            height: 4,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                bottomLeft:  Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: [AppColors.brandPurple, AppColors.cyanAccent],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustBadges(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _TrustBadge(
            icon:   Icons.security_rounded,
            label:  'Secure Login',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TrustBadge(
            icon:   Icons.support_agent_rounded,
            label:  '24/7 Support',
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

// ── Identifier type enum ──────────────────────────────────────────────────────
enum _IdentifierType { email, phone }

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _LoginTypePill extends StatelessWidget {
  final String   label;
  final IconData icon;
  final Color    color;
  const _LoginTypePill({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color:      color,
              fontSize:   11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickHint extends StatelessWidget {
  final String   label;
  final IconData icon;
  final bool     isDark;
  final VoidCallback onTap;
  const _QuickHint({
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:        isDark
              ? AppColors.surfaceDark
              : AppColors.borderLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size:  12,
              color: isDark ? AppColors.textMidDark : AppColors.textMidLight,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color:      isDark
                    ? AppColors.textMidDark
                    : AppColors.textMidLight,
                fontSize:   11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDark;
  const _FieldLabel({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.brandPurple),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color:      isDark
                ? AppColors.textMidDark
                : AppColors.textDarkLight,
            fontSize:   13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     isDark;
  const _TrustBadge({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.brandPurple, size: 26),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color:      isDark
                  ? AppColors.textMidDark
                  : AppColors.textMidLight,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}