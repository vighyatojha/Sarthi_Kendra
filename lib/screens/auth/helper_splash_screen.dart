// lib/screens/auth/helper_splash_screen.dart
import 'dart:math' as math;
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

  // ── Controllers ───────────────────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _logoCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _orbitCtrl;

  // ── Animations ────────────────────────────────────────────────
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _taglineFade;
  late Animation<double> _orbit;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
  }

  void _setupAnimations() {
    // Background fade in
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bgFade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    // Logo elastic pop
    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _logoScale = CurvedAnimation(
      parent: _logoCtrl,
      curve: Curves.elasticOut,
    );
    _logoFade = CurvedAnimation(
      parent: _logoCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );

    // Title + tagline stagger
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end:   Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentCtrl,
      curve:  const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
    ));
    _titleFade = CurvedAnimation(
      parent: _contentCtrl,
      curve:  const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _taglineFade = CurvedAnimation(
      parent: _contentCtrl,
      curve:  const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    // Continuous orbit for background particles
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _orbit = CurvedAnimation(parent: _orbitCtrl, curve: Curves.linear);
  }

  Future<void> _runSequence() async {
    _fadeCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _contentCtrl.forward();

    // Wait for auth to resolve + small UX buffer
    await Future.delayed(const Duration(milliseconds: 2000));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    final auth  = context.read<AuthProvider>();
    final route = auth.isLoggedIn
        ? const HelperDashboard()
        : const HelperLoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder:        (_, a, __) => route,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _bgFade,
        child: Container(
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
              // ── Rotating background orbs ──────────────────────
              AnimatedBuilder(
                animation: _orbit,
                builder: (_, __) => _OrbitingParticles(
                  size:     size,
                  progress: _orbit.value,
                ),
              ),

              // ── Scattered static icons ────────────────────────
              ..._buildBgIcons(size),

              // ── Main content ──────────────────────────────────
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Logo
                    ScaleTransition(
                      scale: _logoScale,
                      child: FadeTransition(
                        opacity: _logoFade,
                        child:   _LogoBadge(),
                      ),
                    ),

                    const SizedBox(height: 36),

                    // App name
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: const Text(
                          'Sarthi Kendra',
                          style: TextStyle(
                            color:         Colors.white,
                            fontSize:      38,
                            fontWeight:    FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Tagline
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.cyanAccent.withOpacity(0.4),
                          ),
                          borderRadius: BorderRadius.circular(20),
                          color: AppColors.cyanAccent.withOpacity(0.08),
                        ),
                        child: const Text(
                          'APNA SARTHI, APNA ROZGAR',
                          style: TextStyle(
                            color:         AppColors.cyanAccent,
                            fontSize:      12,
                            fontWeight:    FontWeight.w700,
                            letterSpacing: 2.5,
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 3),

                    // Bottom area
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Column(
                        children: [
                          // Minimal 3-dot pulse (no percentage, no timer)
                          _PulsingDots(),
                          const SizedBox(height: 20),
                          Text(
                            'PROFESSIONAL & AUTHORITATIVE',
                            style: TextStyle(
                              color:         Colors.white.withOpacity(0.25),
                              fontSize:      9,
                              fontWeight:    FontWeight.w600,
                              letterSpacing: 2.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBgIcons(Size size) {
    final items = [
      (Icons.electrical_services_rounded, 0.08, 0.10, 0.05),
      (Icons.plumbing_rounded,            0.82, 0.07, 0.04),
      (Icons.cleaning_services_rounded,   0.04, 0.38, 0.04),
      (Icons.ac_unit_rounded,             0.88, 0.35, 0.04),
      (Icons.build_circle_rounded,        0.78, 0.70, 0.05),
      (Icons.star_rounded,                0.68, 0.16, 0.03),
    ];
    return items.map((e) {
      final (icon, x, y, op) = e;
      return Positioned(
        left: size.width  * x,
        top:  size.height * y,
        child: Icon(icon, size: 28, color: Colors.white.withOpacity(op)),
      );
    }).toList();
  }
}

// ── Orbiting particles ────────────────────────────────────────────────────────
class _OrbitingParticles extends StatelessWidget {
  final Size   size;
  final double progress;
  const _OrbitingParticles({required this.size, required this.progress});

  @override
  Widget build(BuildContext context) {
    final cx = size.width  / 2;
    final cy = size.height * 0.38;

    return CustomPaint(
      size: size,
      painter: _OrbitPainter(cx: cx, cy: cy, progress: progress),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final double cx, cy, progress;
  const _OrbitPainter({
    required this.cx,
    required this.cy,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final orbits = [
      (160.0, 5.0, AppColors.cyanAccent, 0.12),
      (220.0, 4.0, Colors.white,          0.07),
      (290.0, 6.0, AppColors.brandPurple, 0.10),
    ];

    for (var i = 0; i < orbits.length; i++) {
      final (radius, dotSize, color, opacity) = orbits[i];
      final angle = (progress + i / 3) * 2 * math.pi;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      paint.color = color.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), dotSize, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.progress != progress;
}

// ── Logo badge ────────────────────────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width:  130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glow ring
          Container(
            width:  124,
            height: 124,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color:        AppColors.cyanAccent.withOpacity(0.25),
                  blurRadius:   40,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          // White disc
          Container(
            width:  110,
            height: 110,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handyman_rounded,
              size:  56,
              color: AppColors.gradientStart,
            ),
          ),
          // Cyan badge
          Positioned(
            top:   6,
            right: 6,
            child: Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.cyanAccent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color:        AppColors.cyanAccent.withOpacity(0.5),
                    blurRadius:   10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.navigation_rounded,
                size:  18,
                color: AppColors.gradientStart,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing dots loader (no progress %, no timer) ─────────────────────────────
class _PulsingDots extends StatefulWidget {
  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder:   (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot is offset in phase
            final phase     = (i / 3);
            final t         = (_ctrl.value - phase).abs() % 1.0;
            final scale     = 0.6 + 0.4 * math.sin(t * math.pi);
            final opacity   = 0.3 + 0.7 * math.sin(t * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width:  8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.cyanAccent.withOpacity(
                  opacity.clamp(0.3, 1.0),
                ),
              ),
              transform: Matrix4.identity()
                ..scale(scale.clamp(0.6, 1.0)),
            );
          }),
        );
      },
    );
  }
}