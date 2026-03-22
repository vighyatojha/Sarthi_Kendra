// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'sarthi_theme';
  ThemeMode _mode   = ThemeMode.dark; // default dark

  ThemeMode get themeMode => _mode;
  bool      get isDark    => _mode == ThemeMode.dark;

  ThemeProvider() { _load(); }

  Future<void> _load() async {
    final p    = await SharedPreferences.getInstance();
    final dark = p.getBool(_key) ?? true;
    _mode      = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _mode = isDark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, isDark);
  }

  Future<void> setTheme(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_key, mode == ThemeMode.dark);
  }
}