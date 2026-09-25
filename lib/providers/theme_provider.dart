// lib/providers/theme_provider.dart
//
// Tema claro/escuro fica em UserData (sincronizado com a conta, igual ao site).

import 'package:flutter/material.dart';
import '../services/user_data.dart';

class ThemeProvider extends ChangeNotifier {
  final UserData _data = UserData.instance;

  ThemeProvider() {
    _data.addListener(_onData);
    _onData();
  }

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  void _onData() {
    final mode = _data.theme == 'light' ? ThemeMode.light : ThemeMode.dark;
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme(bool isDarkMode) => _data.update({'theme': isDarkMode ? 'dark' : 'light'});

  @override
  void dispose() {
    _data.removeListener(_onData);
    super.dispose();
  }
}
