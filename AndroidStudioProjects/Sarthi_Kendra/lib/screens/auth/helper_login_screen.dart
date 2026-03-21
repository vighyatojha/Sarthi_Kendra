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

  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool  _obscurePass  = true;
  bool  _isLoading    = false;

  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut);
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() => _isLoading = true);

    final auth    = context.read<AuthProvider>();
    final success = await auth.login(
      email:    _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HelperDashboard()),
      );
    } else {
      _showError(auth.errorMessage ?? 'Login failed. Try again.');
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email first, then tap Forgot Password.');
      return;
    }
    final auth    = context.read<AuthProvider>();
    final success = await auth.sendPasswordReset(email);
    if (!mounted) return;
    _showSnack(
      success
          ? 'Reset link sent to $email'
          : 'Could not send reset email.',
      isError: !success,
    );
  }

  void _showError(String msg) => _showSnack(msg, isError: true);

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:         Text(msg),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
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
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    children: [
                      _buildLoginCard(isDark),
                      const SizedBox(height: 20),
                      _buildTrustBadges(isDark),
                      const SizedBox(height: 16),
                      Text(
                        '© 2024 Sarthi Kendra Foundation.',
                        style: TextStyle(
                          color:    isDark ? AppColors.textSoftDark : AppColors.textSoftLight,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 20),
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

  Widget _buildHeader() {
    return Container(
      width:   double.infinity,
      padding: EdgeInsets.only(
        top:    MediaQuery.of(context).padding.top + 16,
        bottom: 18,
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
      child: const Row(
        children: [
          _LogoIcon(),
          SizedBox(width: 14),
          Text(
            'Sarthi Kendra',
            style: TextStyle(
              color:      Colors.white,
              fontSize:   22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

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
                : AppColors.brandPurple.withOpacity(0.06),
            blurRadius: 24,
            offset:     const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Helper Login',
                    style: TextStyle(
                      color:      isDark ? Colors.white : AppColors.textDarkLight,
                      fontSize:   26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Access your Sarthi dashboard',
                    style: TextStyle(
                      color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Email
                  _FieldLabel(
                    icon: Icons.person_outline_rounded,
                    label: 'Email or Username',
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller:         _emailCtrl,
                    keyboardType:       TextInputType.emailAddress,
                    textInputAction:    TextInputAction.next,
                    autocorrect:        false,
                    style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textDarkLight),
                    decoration: const InputDecoration(
                      hintText: 'helper@sarthikendra.in',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!v.contains('@'))        return 'Enter a valid email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // Password row
                  Row(
                    children: [
                      _FieldLabel(
                        icon:   Icons.lock_outline_rounded,
                        label:  'Password',
                        isDark: isDark,
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _handleForgotPassword,
                        style: TextButton.styleFrom(
                          padding:        EdgeInsets.zero,
                          tapTargetSize:  MaterialTapTargetSize.shrinkWrap,
                          minimumSize:    Size.zero,
                        ),
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
                    controller:      _passwordCtrl,
                    obscureText:     _obscurePass,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _handleLogin(),
                    style: TextStyle(
                        color: isDark ? Colors.white : AppColors.textDarkLight),
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        icon: Icon(
                          _obscurePass
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
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

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                          : const Icon(Icons.login_rounded, size: 20),
                      label: Text(
                        _isLoading ? 'Signing in...' : 'Login',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Register link
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'New to the platform?',
                          style: TextStyle(
                            color:    isDark ? AppColors.textMidDark : AppColors.textMidLight,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HelperRegisterScreen()),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Register as a New Sarthi',
                                style: TextStyle(
                                  color:      AppColors.gradientEnd,
                                  fontSize:   14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: AppColors.gradientEnd),
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
        Expanded(child: _TrustBadge(icon: Icons.security_rounded,
            label: 'Secure Login', isDark: isDark)),
        const SizedBox(width: 12),
        Expanded(child: _TrustBadge(icon: Icons.support_agent_rounded,
            label: '24/7 Support', isDark: isDark)),
      ],
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

/// Extracted as const-compatible widget for logo
class _LogoIcon extends StatelessWidget {
  const _LogoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  46,
      height: 46,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: const Icon(Icons.handshake_rounded, color: Colors.white, size: 26),
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
        Icon(icon, size: 16, color: AppColors.brandPurple),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color:      isDark ? AppColors.textMidDark : AppColors.textDarkLight,
            fontSize:   14,
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.brandPurple, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color:      isDark ? AppColors.textMidDark : AppColors.textMidLight,
              fontSize:   12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}