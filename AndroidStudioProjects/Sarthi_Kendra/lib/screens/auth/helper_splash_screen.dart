// lib/screens/auth/helper_splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'helper_login_screen.dart';
import '../dashboard/helper_dashboard.dart';

class HelperSplashScreen extends StatefulWidget {
  const HelperSplashScreen({super.key});

  @override
  State<HelperSplashScreen> createState() => _HelperSplashScreenState();
}

class _HelperSplashScreenState extends State<HelperSplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _progressCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _pulseCtrl;

  late Animation<double> _progressAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _logoScaleAnim;
  late Animation<double> _pulseAnim;

  String _loadingText = 'Initializing...';
  final List<String> _loadingMessages = [
    'Initializing...',
    'Loading your profile...',
    'Starting your journey...',
    'Almost ready...',
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  void _setupAnimations() {
    // Progress bar: 0 → 1 over 3 seconds
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _progressAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressCtrl, curve: Curves.easeInOutCubic),
    );

    // Fade-in for whole content
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Logo entrance scale
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScaleAnim = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);

    // Cyan badge pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Update loading text at intervals
    _progressAnim.addListener(() {
      final pct = _progressAnim.value;
      String newText;
      if (pct < 0.25)      newText = _loadingMessages[0];
      else if (pct < 0.55) newText = _loadingMessages[1];
      else if (pct < 0.85) newText = _loadingMessages[2];
      else                 newText = _loadingMessages[3];
      if (newText != _loadingText) setState(() => _loadingText = newText);
    });
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 300));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _progressCtrl.forward();

    // Wait until progress done + small buffer
    await Future.delayed(const Duration(milliseconds: 3800));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final route = authProvider.isLoggedIn
        ? const HelperDashboard()
        : const HelperLoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => route,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _fadeCtrl.dispose();
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width:  double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              AppColors.gradientStart,
              AppColors.gradientMid,
              AppColors.gradientEnd,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // ── Background scattered icons ──────────────────────
            ..._buildBackgroundIcons(size),

            // ── Main content ─────────────────────────────────────
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // ── Logo area ─────────────────────────────────
                    ScaleTransition(
                      scale: _logoScaleAnim,
                      child: _buildLogo(),
                    ),

                    const SizedBox(height: 32),

                    // ── App name ──────────────────────────────────
                    const Text(
                      'Sarthi Kendra',
                      style: TextStyle(
                        color:      Colors.white,
                        fontSize:   38,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Tagline ───────────────────────────────────
                    Text(
                      'APNA SARTHI, APNA ROZGAR',
                      style: TextStyle(
                        color:      AppColors.cyanAccent,
                        fontSize:   13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3.0,
                      ),
                    ),

                    const Spacer(flex: 3),

                    // ── Loading section ───────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: _buildLoadingSection(),
                    ),

                    const SizedBox(height: 24),

                    // ── Bottom tagline ────────────────────────────
                    Text(
                      'PROFESSIONAL & AUTHORITATIVE',
                      style: TextStyle(
                        color:      Colors.white.withOpacity(0.35),
                        fontSize:   10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.5,
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return SizedBox(
      width:  120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // White circle background
          Container(
            width:  110,
            height: 110,
            decoration: BoxDecoration(
              color:  Colors.white,
              shape:  BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:       AppColors.cyanAccent.withOpacity(0.3),
                  blurRadius:  40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),

          // Tools icon
          const Icon(
            Icons.handyman_rounded,
            size:  58,
            color: AppColors.gradientStart,
          ),

          // Cyan navigation badge (top-right)
          Positioned(
            top:   0,
            right: 0,
            child: ScaleTransition(
              scale: _pulseAnim,
              child: Container(
                width:  38,
                height: 38,
                decoration: BoxDecoration(
                  color:  AppColors.cyanAccent,
                  shape:  BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:       AppColors.cyanAccent.withOpacity(0.5),
                      blurRadius:  12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  size:  20,
                  color: AppColors.gradientStart,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSection() {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder: (context, _) {
        final pct = (_progressAnim.value * 100).round();
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _loadingText,
                  style: TextStyle(
                    color:      Colors.white.withOpacity(0.75),
                    fontSize:   13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$pct%',
                  style: TextStyle(
                    color:      AppColors.cyanAccent,
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            Container(
              height:       4,
              width:        double.infinity,
              decoration:   BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _progressAnim.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [AppColors.cyanAccent, AppColors.brandPurple],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:       AppColors.cyanAccent.withOpacity(0.6),
                          blurRadius:  8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildBackgroundIcons(Size size) {
    final icons = [
      (Icons.electrical_services_rounded, 0.08, 0.12, 0.06),
      (Icons.plumbing_rounded,            0.85, 0.08, 0.05),
      (Icons.cleaning_services_rounded,   0.05, 0.40, 0.04),
      (Icons.ac_unit_rounded,             0.90, 0.38, 0.05),
      (Icons.local_fire_department_rounded, 0.15, 0.70, 0.05),
      (Icons.build_circle_rounded,        0.80, 0.72, 0.06),
      (Icons.person_pin_rounded,          0.50, 0.82, 0.04),
      (Icons.star_rounded,                0.70, 0.18, 0.04),
    ];

    return icons.map((e) {
      final (icon, x, y, opacity) = e;
      return Positioned(
        left: size.width  * x,
        top:  size.height * y,
        child: Icon(
          icon,
          size:  32,
          color: Colors.white.withOpacity(opacity),
        ),
      );
    }).toList();
  }
}