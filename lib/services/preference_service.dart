import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _currencyKey = 'currency';
  static const String _budgetKey = 'monthly_budget';
  static const String _themeKey = 'is_dark_mode';

  final SharedPreferences _prefs;

  PreferenceService(this._prefs);

  // Currency
  String get currency => _prefs.getString(_currencyKey) ?? 'IDR';
  Future<void> setCurrency(String currency) async {
    await _prefs.setString(_currencyKey, currency);
  }

  // Monthly Budget
  int get monthlyBudget => _prefs.getInt(_budgetKey) ?? 5000000;
  Future<void> setMonthlyBudget(int budget) async {
    await _prefs.setInt(_budgetKey, budget);
  }

  // Theme Mode
  bool get isDarkMode => _prefs.getBool(_themeKey) ?? false;
  Future<void> setDarkMode(bool isDark) async {
    await _prefs.setBool(_themeKey, isDark);
  }
}
