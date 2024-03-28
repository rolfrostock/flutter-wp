// lib/providers/theme_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeData currentTheme = ThemeData.light(); // Tema padrão

  ThemeProvider() {
    loadTheme();
  }

  void toggleTheme(bool isDark) {
    currentTheme = isDark ? ThemeData.dark() : ThemeData.light();
    notifyListeners();
    saveThemePreference(isDark);
  }

  void loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDarkTheme') ?? false; // Padrão é false
    currentTheme = isDark ? ThemeData.dark() : ThemeData.light();
    notifyListeners();
  }

  void saveThemePreference(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', isDark);
  }
}
