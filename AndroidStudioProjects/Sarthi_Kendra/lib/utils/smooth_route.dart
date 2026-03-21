// lib/utils/smooth_route.dart
// Use this everywhere instead of MaterialPageRoute for smooth transitions

import 'package:flutter/material.dart';

/// Fade + subtle slide — works on ALL screen sizes / themes
class SmoothRoute<T> extends PageRouteBuilder<T> {
  SmoothRoute({required Widget page, RouteSettings? settings})
      : super(
    settings: settings,
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (_, anim, __, child) {
      final fade = CurvedAnimation(parent: anim, curve: Curves.easeOut);
      final slide = Tween<Offset>(
        begin: const Offset(0.04, 0),
        end:   Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return FadeTransition(
        opacity:  fade,
        child:    SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// Bottom-sheet style push (slides up)
class BottomSlideRoute<T> extends PageRouteBuilder<T> {
  BottomSlideRoute({required Widget page})
      : super(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 260),
    transitionsBuilder: (_, anim, __, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0, 1),
        end:   Offset.zero,
      ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
      return SlideTransition(position: slide, child: child);
    },
  );
}