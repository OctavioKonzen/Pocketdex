// lib/services/app_settings.dart
//
// Preferências deste aparelho (não vão para a conta): tamanho do texto e
// animações da Pokébola (ao abrir um Pokémon e girando no fundo). As mesmas do site. O tema fica em
// UserData (vai para a conta) e o idioma em lib/i18n/i18n.dart.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _textKey = 'settings_text_size';
  static const _pokeballKey = 'settings_pokeball_animation';
  static const _backgroundKey = 'settings_background_pokeball';
  static const _animatedSpritesKey = 'settings_animated_sprites';

  /// Tamanhos do texto: (chave, nome, escala).
  static const textSizes = [('normal', 'Normal', 1.0), ('large', 'Grande', 1.125), ('larger', 'Maior', 1.25)];

  String textSize = 'normal';
  bool pokeballAnimation = true;
  /// Pokébola girando no fundo das telas.
  bool backgroundAnimation = true;

  /// Sprites animados (estilo Black & White) em todo o app; baixados do site
  /// da primeira vez e guardados no celular (lib/services/animated_sprites.dart).
  bool animatedSprites = true;

  double get textScale => textSizes.firstWhere((t) => t.$1 == textSize, orElse: () => textSizes.first).$3;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      textSize = prefs.getString(_textKey) ?? 'normal';
      pokeballAnimation = prefs.getBool(_pokeballKey) ?? true;
      backgroundAnimation = prefs.getBool(_backgroundKey) ?? true;
      animatedSprites = prefs.getBool(_animatedSpritesKey) ?? true;
    } catch (_) {}
  }

  Future<void> setTextSize(String value) async {
    textSize = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_textKey, value);
    } catch (_) {}
  }

  Future<void> setPokeballAnimation(bool value) async {
    pokeballAnimation = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_pokeballKey, value);
    } catch (_) {}
  }

  Future<void> setBackgroundAnimation(bool value) async {
    backgroundAnimation = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_backgroundKey, value);
    } catch (_) {}
  }

  Future<void> setAnimatedSprites(bool value) async {
    animatedSprites = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_animatedSpritesKey, value);
    } catch (_) {}
  }
}
