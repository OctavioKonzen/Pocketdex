// lib/providers/theme_provider.dart
//
// Tema claro, escuro ou automático (segue o aparelho) fica em UserData
// (sincronizado com a conta, igual ao site).

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
    final mode = switch (_data.theme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
  }

  void toggleTheme(bool isDarkMode) => setTheme(isDarkMode ? 'dark' : 'light');

  /// 'light' | 'dark' | 'system'
  String get theme => switch (_themeMode) { ThemeMode.light => 'light', ThemeMode.system => 'system', _ => 'dark' };
  void setTheme(String theme) => _data.update({'theme': theme});

  @override
  void dispose() {
    _data.removeListener(_onData);
    super.dispose();
  }
}
