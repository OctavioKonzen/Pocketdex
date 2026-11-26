// lib/utils/hud_colors.dart
//
// A moldura do "DS" (o campo, a faixa e a tela de baixo da batalha e do
// Pokelike) no tema: com um tema de Pokémon, na cor dele (escura); com o fundo
// de campeão, a borda dourada. Os painéis BW (time, bolsa, dados) puxam um
// pouco para a cor do tema. Igual ao site (--hud, --hud-edge e --hud-accent).

import 'package:flutter/material.dart';
import '../services/app_settings.dart';

class Hud {
  static const _default = Color(0xFF1E293B);

  /// O fundo da moldura (a tela de baixo).
  static Color get base {
    final s = AppSettings.instance;
    final accent = s.themeAccent;
    if (accent != null) return HSLColor.fromAHSL(1, HSLColor.fromColor(accent).hue, 0.32, 0.17).toColor();
    if (s.themeChampion) return const HSLColor.fromAHSL(1, 45, 0.4, 0.15).toColor();
    return _default;
  }

  /// A borda da moldura: dourada no fundo de campeão.
  static Color get edge => AppSettings.instance.themeChampion ? AppSettings.championGold : base;

  /// Um painel BW (ou a faixa e a caixa de texto, com [amount] menor) puxado um pouco para a cor do tema.
  static Color tint(Color color, [double amount = 0.22]) {
    final accent = AppSettings.instance.themeAccent;
    return accent == null ? color : Color.lerp(color, accent, amount)!;
  }
}
