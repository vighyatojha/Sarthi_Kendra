// lib/screens/auth/helper_splash_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import 'helper_login_screen.dart';
import '../dashboard/helper_dashboard.dart';
import '../language/language_selection_screen.dart';

class HelperSplashScreen extends StatefulWidget {
  const HelperSplashScreen({super.key});
  @override
  State<HelperSplashScreen> createState() => _HelperSplashScreenState();
}

class _HelperSplashScreenState extends State<HelperSplashScreen>
    with TickerProviderStateMixin {

  late AnimationController _logoCtrl;
  late AnimationController _contentCtrl;
  late Animation<double>   _logoScale;
  late Animation<double>   _logoFade;
  late Animation<double>   _contentFade;
  late Animation<Offset>   _contentSlide;

  @override
  void initState() {
    super.initState();
    _logoCtrl    = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _contentCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _logoScale  = CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut);
    _logoFade   = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0, 0.4, curve: Curves.easeOut));
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    _run();
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 200));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 380));
    _contentCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 2200));
    _navigate();
  }

  void _navigate() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final lang = context.read<LanguageProvider>();

    Widget dest;
    if (auth.isLoggedIn)       dest = const HelperDashboard();
    else if (!lang.isSelected) dest = const LanguageSelectionScreen();
    else                       dest = const HelperLoginScreen();

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, a, __) => dest,
      transitionDuration: const Duration(milliseconds: 500),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              Color(0xFF3B0764), // deep violet
              Color(0xFF5B21B6), // vivid purple
              Color(0xFF7C3AED), // brand purple
              Color(0xFF0891B2), // teal base
            ],
            stops: [0.0, 0.33, 0.66, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo
              ScaleTransition(
                scale:   _logoScale,
                child:   FadeTransition(opacity: _logoFade, child: const _SplashLogo()),
              ),

              const SizedBox(height: 32),

              // Name + tagline + trust pills
              SlideTransition(
                position: _contentSlide,
                child: FadeTransition(
                  opacity: _contentFade,
                  child: Column(children: [
                    const Text('Sarthi Kendra',
                        style: TextStyle(
                            color: Colors.white, fontSize: 36,
                            fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                      decoration: BoxDecoration(
                        color:        Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(24),
                        border:       Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: const Text('APNA SARTHI, APNA ROZGAR',
                          style: TextStyle(color: Color(0xFF14FFEC),
                              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
                    ),
                    const SizedBox(height: 24),
                    // Trust signals
                    Wrap(spacing: 10, runSpacing: 8, alignment: WrapAlignment.center,
                      children: const [
                        _TrustPill(icon: Icons.verified_rounded,   label: 'Govt. Verified'),
                        _TrustPill(icon: Icons.lock_rounded,        label: 'Secure & Safe'),
                        _TrustPill(icon: Icons.people_rounded,      label: '10K+ Helpers'),
                      ],
                    ),
                  ]),
                ),
              ),

              const Spacer(flex: 4),

              FadeTransition(opacity: _contentFade, child: const _DotLoader()),
              const SizedBox(height: 12),
              FadeTransition(
                opacity: _contentFade,
                child: Text('Trouble Sarthi Platform · v1.0.0',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 134, height: 134,
      child: Stack(alignment: Alignment.center, children: [
        // Glow ring
        Container(
          width: 130, height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.07),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
        ),
        // White disc
        Container(
          width: 102, height: 102,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.55),
                  blurRadius: 32, spreadRadius: 4),
              BoxShadow(color: const Color(0xFF14FFEC).withOpacity(0.22),
                  blurRadius: 20),
            ],
          ),
          child: const Icon(Icons.handyman_rounded, size: 50, color: Color(0xFF4C1D95)),
        ),
        // Cyan badge
        Positioned(
          top: 4, right: 8,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF14FFEC),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: const Color(0xFF14FFEC).withOpacity(0.55), blurRadius: 12)],
            ),
            child: const Icon(Icons.navigation_rounded, size: 17, color: Color(0xFF0F2027)),
          ),
        ),
      ]),
    );
  }
}

class _TrustPill extends StatelessWidget {
  final IconData icon; final String label;
  const _TrustPill({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.11),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: const Color(0xFF14FFEC)),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(
            color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _DotLoader extends StatefulWidget {
  const _DotLoader();
  @override
  State<_DotLoader> createState() => _DotLoaderState();
}
class _DotLoaderState extends State<_DotLoader> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() { super.initState(); _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(); }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _c, builder: (_, __) {
      return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
        final t = ((_c.value * 3) - i).clamp(0.0, 1.0);
        final op = (0.2 + 0.8 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.2, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 7, height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF14FFEC).withOpacity(op),
          ),
        );
      }));
    });
  }
}