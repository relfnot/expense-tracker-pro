import 'package:flutter/material.dart';
import '../services/preference_service.dart';

class ThemeProvider with ChangeNotifier {
  final PreferenceService _preferenceService;
  late bool _isDarkMode;

  ThemeProvider(this._preferenceService) {
    _isDarkMode = _preferenceService.isDarkMode;
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> toggleTheme(bool isDark) async {
    _isDarkMode = isDark;
    await _preferenceService.setDarkMode(isDark);
    notifyListeners();
  }
}
