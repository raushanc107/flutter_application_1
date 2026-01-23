import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';
  Locale _locale = const Locale('en');

  LanguageProvider() {
    _loadLanguage();
  }

  Locale get locale => _locale;

  String get languageName {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'Hindi';
      case 'hinglish':
        return 'Hinglish';
      default:
        return 'English';
    }
  }

  String get languageNativeName {
    switch (_locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      case 'hinglish':
        return 'Hinglish';
      default:
        return 'English';
    }
  }

  Future<void> setLanguage(Locale locale) async {
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_languageKey);
    if (savedCode != null) {
      _locale = Locale(savedCode);
      notifyListeners();
    }
  }
}
