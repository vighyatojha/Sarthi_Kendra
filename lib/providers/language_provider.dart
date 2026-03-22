// lib/providers/language_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _key = 'sarthi_lang';

  Locale _locale   = const Locale('en');
  bool   _selected = false;

  Locale get locale     => _locale;
  bool   get isSelected => _selected;
  bool   get isHindi    => _locale.languageCode == 'hi';

  LanguageProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _locale   = Locale(saved);
      _selected = true;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String code) async {
    _locale   = Locale(code);
    _selected = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
  }

  // Convenience: translate a key
  String t(String key) =>
      _strings[_locale.languageCode]?[key] ?? _strings['en']![key] ?? key;

  // ── String table ──────────────────────────────────────────────
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'app_name':   'Sarthi Kendra',
      'tagline':    'APNA SARTHI, APNA ROZGAR',
      'login':      'Sign In',
      'logout':     'Logout',
      'register':   'Register',
      'home':       'Home',
      'jobs':       'Jobs',
      'earnings':   'Earnings',
      'trust':      'Trust',
      'profile':    'Profile',
      'online':     'Online',
      'offline':    'Offline',
      'accept':     'Accept',
      'decline':    'Decline',
      'navigate':   'Navigate',
      'start_job':  'Start Job',
      'done':       'Mark Complete',
      'save':       'Save Changes',
      'cancel':     'Cancel',
      'support':    'Help & Support',
    },
    'hi': {
      'app_name':   'सार्थी केंद्र',
      'tagline':    'अपना सार्थी, अपना रोज़गार',
      'login':      'साइन इन',
      'logout':     'लॉगआउट',
      'register':   'रजिस्टर',
      'home':       'होम',
      'jobs':       'काम',
      'earnings':   'कमाई',
      'trust':      'विश्वास',
      'profile':    'प्रोफ़ाइल',
      'online':     'ऑनलाइन',
      'offline':    'ऑफलाइन',
      'accept':     'स्वीकार',
      'decline':    'अस्वीकार',
      'navigate':   'नेविगेट',
      'start_job':  'काम शुरू',
      'done':       'पूरा हुआ',
      'save':       'बदलाव सहेजें',
      'cancel':     'रद्द करें',
      'support':    'सहायता',
    },
  };
}