// lib/screens/language/language_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme.dart';
import '../../providers/language_provider.dart';
import '../auth/helper_login_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});
  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with SingleTickerProviderStateMixin {

  String? _selected;
  late final AnimationController _ctrl;
  late final Animation<double>   _fade;
  late final Animation<Offset>   _slide;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _proceed() async {
    if (_selected == null) return;
    await context.read<LanguageProvider>().setLanguage(_selected!);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder:        (_, a, __) => const HelperLoginScreen(),
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF3B0764), Color(0xFF5B21B6), Color(0xFF7C3AED), Color(0xFF0891B2)],
            stops: [0.0, 0.33, 0.66, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(children: [
                const Spacer(flex: 2),

                // ── Logo ──────────────────────────────────────
                SlideTransition(
                  position: _slide,
                  child: Column(children: [
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.5),
                            blurRadius: 24, spreadRadius: 2)],
                      ),
                      child: const Icon(Icons.handyman_rounded,
                          color: Color(0xFF4C1D95), size: 36),
                    ),
                    const SizedBox(height: 18),
                    const Text('Sarthi Kendra', style: TextStyle(
                        color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text('Select your preferred language',
                        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('अपनी पसंदीदा भाषा चुनें',
                        style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 13)),
                  ]),
                ),

                const Spacer(flex: 1),

                // ── Cards ─────────────────────────────────────
                Row(children: [
                  Expanded(child: _LangCard(
                    code: 'en', name: 'English', native: 'English',
                    flag: '🇬🇧', subtitle: 'Continue in English',
                    selected: _selected == 'en',
                    onTap: () => setState(() => _selected = 'en'),
                  )),
                  const SizedBox(width: 14),
                  Expanded(child: _LangCard(
                    code: 'hi', name: 'Hindi', native: 'हिन्दी',
                    flag: '🇮🇳', subtitle: 'हिन्दी में जारी रखें',
                    selected: _selected == 'hi',
                    onTap: () => setState(() => _selected = 'hi'),
                  )),
                ]),

                const Spacer(flex: 2),

                // ── Continue button ───────────────────────────
                AnimatedOpacity(
                  opacity:  _selected != null ? 1.0 : 0.38,
                  duration: const Duration(milliseconds: 250),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected != null ? _proceed : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF5B21B6),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(
                            _selected == 'hi' ? 'आगे बढ़ें' : 'Continue',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ]),
                    ),
                  ),
                ),

                const SizedBox(height: 12),
                Text('You can change this later in Settings',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12)),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String code, name, native, flag, subtitle;
  final bool   selected;
  final VoidCallback onTap;
  const _LangCard({
    required this.code, required this.name, required this.native,
    required this.flag, required this.subtitle,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding:  const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:        selected
              ? Colors.white
              : Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withOpacity(0.2),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? [BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20, offset: const Offset(0, 8))] : null,
        ),
        child: Column(children: [
          Text(flag, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          Text(native,
              style: TextStyle(
                  color:      selected ? const Color(0xFF4C1D95) : Colors.white,
                  fontSize:   18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                  color:    selected
                      ? const Color(0xFF6D28D9)
                      : Colors.white.withOpacity(0.6),
                  fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          if (selected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        const Color(0xFF5B21B6).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF5B21B6), size: 13),
                const SizedBox(width: 4),
                Text('Selected',
                    style: const TextStyle(
                        color: Color(0xFF5B21B6),
                        fontSize: 11, fontWeight: FontWeight.w600)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.6), fontSize: 10)),
            ),
        ]),
      ),
    );
  }
}