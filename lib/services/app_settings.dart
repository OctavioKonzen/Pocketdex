// lib/services/app_settings.dart
//
// Preferências deste aparelho (não vão para a conta): tema de Pokémon, tamanho do texto e
// animações da Pokébola (ao abrir um Pokémon e girando no fundo). As mesmas do site. O tema fica em
// UserData (vai para a conta) e o idioma em lib/i18n/i18n.dart.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'user_data.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _textKey = 'settings_text_size';
  static const _pokeballKey = 'settings_pokeball_animation';
  static const _backgroundKey = 'settings_background_pokeball';
  static const _animatedSpritesKey = 'settings_animated_sprites';
  static const _battleSoundsKey = 'settings_battle_sounds';
  static const _battleMusicKey = 'settings_battle_music';
  static const _battleStyleKey = 'settings_battle_style';

  /// Os sprites se mexem ou ficam parados: (chave, nome).
  static const spriteMotions = [('on', 'Animados'), ('off', 'Parados')];

  /// Tamanhos do texto: (chave, nome, escala).
  static const textSizes = [('normal', 'Normal', 1.0), ('large', 'Grande', 1.125), ('larger', 'Maior', 1.25)];

  String textSize = 'normal';
  bool pokeballAnimation = true;
  /// Pokébola girando no fundo das telas.
  bool backgroundAnimation = true;

  /// Sprites animados em todo o app (vêm dentro do app,
  /// lib/services/animated_sprites.dart).
  bool animatedSprites = true;

  /// Sons da batalha (golpes, Poké Ball...) e a música (battle_sounds.dart).
  bool battleSounds = true;
  bool battleMusic = true;

  /// Contra o computador: 'shift' (pergunta se quer trocar quando o do adversário
  /// desmaia) ou 'set' (como no competitivo, sem a pergunta). Igual ao site.
  String battleStyle = 'shift';

  /// Tema de Pokémon (0: o padrão). O app fica na cor dele e o desenho dele
  /// aparece no fundo no lugar da Pokébola (widgets/pokeball_background.dart).
  /// Fica na conta (UserData 'themePokemon'): vale no app e no site.
  int get themePokemon => (UserData.instance['themePokemon'] as num?)?.toInt() ?? 0;

  /// Cor do tema de cada Pokémon (assets/database/theme_colors.json, feito
  /// por tool/build_theme_colors.py).
  static Map<String, Color> _themeColors = const {};

  /// A versão shiny do tema: liberada ao capturar o Pokémon shiny no Pokelike.
  bool get themeShiny => UserData.instance['themeShiny'] == true && shinyUnlocked(themePokemon);
  static bool shinyUnlocked(int id) =>
      ((((UserData.instance['league'] as Map?)?['factory'] as Map?)?['shinies'] as List?) ?? const []).any((x) => (x as num).toInt() == id);
  void setThemeShiny(bool on) => UserData.instance.update({'themeShiny': on});

  /// O fundo de campeão: liberado ao entrar no Hall da Fama (traços e brilho dourados). Igual ao site.
  static bool get championUnlocked => (((UserData.instance['league'] as Map?)?['hall'] as List?) ?? const []).isNotEmpty;
  bool get themeChampion => UserData.instance['themeChampion'] == true && championUnlocked;
  void setThemeChampion(bool on) => UserData.instance.update({'themeChampion': on});
  static const championGold = Color(0xFFF5C518);

  /// A cor do Pokémon do tema; null no padrão.
  Color? get themeAccent => themePokemon == 0 ? null : themeColorOf(themePokemon, shiny: themeShiny);

  static Color? themeColorOf(int id, {bool shiny = false}) => (shiny ? _themeColors['s$id'] : null) ?? _themeColors['$id'];

  double get textScale => textSizes.firstWhere((t) => t.$1 == textSize, orElse: () => textSizes.first).$3;

  Future<void> load() async {
    // O tema de Pokémon vem da conta: quando ele muda (aqui ou no site), o app redesenha.
    var lastTheme = (themePokemon, themeShiny, themeChampion);
    UserData.instance.addListener(() {
      if ((themePokemon, themeShiny, themeChampion) == lastTheme) return;
      lastTheme = (themePokemon, themeShiny, themeChampion);
      notifyListeners();
    });
    try {
      final json = jsonDecode(await rootBundle.loadString('assets/database/theme_colors.json')) as Map<String, dynamic>;
      _themeColors = {for (final e in json.entries) e.key: Color(0xFF000000 | int.parse((e.value as String).substring(1), radix: 16))};
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      textSize = prefs.getString(_textKey) ?? 'normal';
      pokeballAnimation = prefs.getBool(_pokeballKey) ?? true;
      backgroundAnimation = prefs.getBool(_backgroundKey) ?? true;
      animatedSprites = prefs.getBool(_animatedSpritesKey) ?? true;
      battleSounds = prefs.getBool(_battleSoundsKey) ?? true;
      battleMusic = prefs.getBool(_battleMusicKey) ?? true;
      battleStyle = prefs.getString(_battleStyleKey) ?? 'shift';
    } catch (_) {}
  }

  void setThemePokemon(int id) => UserData.instance.update({'themePokemon': id, 'themeShiny': false});

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

  Future<void> setBattleSounds(bool value) async {
    battleSounds = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_battleSoundsKey, value);
    } catch (_) {}
  }

  Future<void> setBattleMusic(bool value) async {
    battleMusic = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool(_battleMusicKey, value);
    } catch (_) {}
  }

  Future<void> setBattleStyle(String value) async {
    battleStyle = value;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_battleStyleKey, value);
    } catch (_) {}
  }
}
