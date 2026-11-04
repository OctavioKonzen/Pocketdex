// lib/i18n/i18n.dart
//
// Idiomas do app: português (original), inglês, francês e espanhol — os
// mesmos do site, com o mesmo dicionário (assets/i18n/ui.json, gerado de
// tool/i18n/ui.json por tool/i18n_build.py).
//
// O app é escrito em português. Todo Text passa por [tr] (lib/i18n/text.dart),
// que troca o texto pela tradução — inclusive os com partes variáveis, como
// "123 Pokémon" — e os nomes dos Pokémon pelos oficiais do idioma
// (Bulbasaur → Bulbizarre em francês). Nomes de golpes, habilidades e itens
// continuam os originais.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  final String code;
  final String label;
  final String flag;
  const AppLanguage(this.code, this.label, this.flag);
}

const appLanguages = [
  AppLanguage('pt', 'Português', '🇧🇷'),
  AppLanguage('en', 'English', '🇺🇸'),
  AppLanguage('fr', 'Français', '🇫🇷'),
  AppLanguage('es', 'Español', '🇪🇸'),
];

class _Pattern {
  final RegExp re;
  final List<int> order;
  final String text;
  final int fixed;
  _Pattern(this.re, this.order, this.text, this.fixed);
}

class I18n {
  I18n._();

  static const _prefKey = 'pocketdex-language';
  static const _index = {'en': 0, 'fr': 1, 'es': 2, 'pt': 3};

  /// Idioma atual ('pt', 'en', 'fr' ou 'es'). Muda com [setLanguage].
  static final ValueNotifier<String> current = ValueNotifier('pt');
  static String get language => current.value;

  static Map<String, dynamic> _ui = const {};
  static final Map<String, String> _exact = {};
  static final List<_Pattern> _patterns = [];
  static final Map<String, String> _names = {};
  static final Map<String, String> _cache = {};
  // Textos que o próprio tradutor gerou: não são traduzidos de novo.
  static final Set<String> _produced = {};

  /// Carrega o idioma salvo (ou o do aparelho) e o dicionário.
  static Future<void> load() async {
    String? saved;
    try {
      saved = (await SharedPreferences.getInstance()).getString(_prefKey);
    } catch (_) {}
    final device = PlatformDispatcher.instance.locale.languageCode;
    final code = saved ?? device;
    try {
      _ui = json.decode(await rootBundle.loadString('assets/i18n/ui.json')) as Map<String, dynamic>;
    } catch (_) {
      _ui = const {};
    }
    await _apply(_index.containsKey(code) ? code : 'pt');
  }

  /// Troca o idioma (o app inteiro é redesenhado no idioma novo).
  static Future<void> setLanguage(String code) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_prefKey, code);
    } catch (_) {}
    await _apply(code);
  }

  static Future<void> _apply(String code) async {
    _exact.clear();
    _patterns.clear();
    _names.clear();
    _cache.clear();
    _produced.clear();
    final i = _index[code]!;
    for (final entry in _ui.entries) {
      final tr = entry.value as List;
      final text = i < tr.length ? tr[i] as String : null;
      // Espaços e quebras de linha contam como um espaço só (como em [tr]).
      final pt = entry.key.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (text == null || text == pt) continue;
      if (RegExp(r'\{\d+\}').hasMatch(pt)) {
        final order = <int>[];
        final source = StringBuffer();
        pt.splitMapJoin(RegExp(r'\{(\d+)\}'), onMatch: (m) {
          order.add(int.parse(m.group(1)!));
          source.write('(.+?)');
          return '';
        }, onNonMatch: (s) {
          source.write(RegExp.escape(s));
          return '';
        });
        _patterns.add(_Pattern(RegExp('^$source\$', dotAll: true), order, text, pt.replaceAll(RegExp(r'\{\d+\}'), '').length));
      } else {
        _exact[pt] = text;
      }
    }
    // Os modelos mais específicos (mais texto fixo) primeiro.
    _patterns.sort((a, b) => b.fixed - a.fixed);
    if (code == 'fr' || code == 'es') await _loadPokemonNames(code);
    current.value = code;
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Nomes oficiais dos Pokémon no idioma, do jeito que o app os mostra.
  static Future<void> _loadPokemonNames(String code) async {
    try {
      final species = json.decode(await rootBundle.loadString('assets/database/species.json')) as List;
      final seen = <String, String?>{};
      for (final s in species.cast<Map<String, dynamic>>()) {
        final names = (s['names'] as Map?)?.cast<String, dynamic>() ?? const {};
        final local = (names[code] ?? names['en']) as String?;
        if (local == null) continue;
        final name = s['name'] as String;
        for (final key in [_cap(name), _cap(name.replaceAll('-', ' ')), _cap(name.split('-').first), names['en'] as String?]) {
          if (key == null) continue;
          if (seen.containsKey(key) && seen[key] != local) {
            seen[key] = null; // ambíguo: não troca
          } else {
            seen[key] = local;
          }
        }
      }
      for (final e in seen.entries) {
        if (e.value != null && e.value != e.key) _names[e.key] = e.value!;
      }
    } catch (_) {}
  }

  /// Nome oficial da espécie no idioma, a partir do nome como o app mostra.
  static String pokemonName(String name) => _names[name] ?? name;

  /// O Pokémon (nome como no banco, ex.: "mr-mime") bate com a busca, no nome
  /// original ou no nome do idioma.
  static bool nameMatches(String name, String query) {
    final q = query.toLowerCase();
    if (name.toLowerCase().contains(q)) return true;
    final local = _names[_cap(name)] ?? _names[_cap(name.replaceAll('-', ' '))];
    return local != null && local.toLowerCase().contains(q);
  }

  /// Tradução de um texto (sem tradução: o próprio texto).
  static String tr(String text) {
    if (_exact.isEmpty && _patterns.isEmpty && _names.isEmpty) return text;
    final trimmed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (trimmed.isEmpty || _produced.contains(trimmed)) return text;
    var out = _cache[trimmed];
    if (out == null) {
      String? found = _exact[trimmed] ?? _names[trimmed];
      if (found == null) {
        for (final p in _patterns) {
          final m = p.re.firstMatch(trimmed);
          if (m == null) continue;
          found = p.text.replaceAllMapped(RegExp(r'\{(\d+)\}'), (g) {
            final at = p.order.indexOf(int.parse(g.group(1)!));
            final value = at < 0 ? '' : (m.group(at + 1) ?? '');
            return _names[value] ?? _exact[value] ?? value;
          });
          break;
        }
      }
      out = found ?? trimmed;
      _cache[trimmed] = out;
      if (out != trimmed) _produced.add(out);
    }
    if (out == trimmed) return text;
    // Mantém os espaços das pontas (texto grudado em outro).
    final start = text.startsWith(RegExp(r'\s')) ? ' ' : '';
    final end = RegExp(r'\s$').hasMatch(text) ? ' ' : '';
    return '$start$out$end';
  }

  /// Texto no idioma a partir de {en, fr, es} (português: [pt]).
  static String? pick(String? pt, Object? others) {
    if (language == 'pt' || others is! Map) return pt;
    final v = others[language];
    return v is String && v.isNotEmpty ? v : pt;
  }
}

/// Atalho para [I18n.tr].
String tr(String text) => I18n.tr(text);
