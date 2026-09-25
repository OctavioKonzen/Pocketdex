// lib/services/user_data.dart
//
// Dados do usuário (favoritos, times, treinos, tema, recordes e jogo em
// andamento) no MESMO formato usado pelo site (web-site/src/lib/sync.js).
// Ficam salvos no aparelho e, com login, são sincronizados em tempo real com
// a conta (users/{uid}.data no Firestore) por AccountSync. Assim um time
// criado no celular aparece no site na hora, e vice-versa.
//
// Formato:
//   theme: 'dark' | 'light'
//   favorites: [id]                          ids de Pokémon (números)
//   teams: [{id, name, color: '#RRGGBB' | null, pokemon: [id | null] x6}]
//   training: [{id, pokemonId, name, sprite, box?, evs: {hp, attack, defense,
//              'special-attack', 'special-defense', speed}}]
//   quizRecord, rankedRecord: número
//   quizGame: jogo normal em andamento ou null
//   avatar: id do Pokémon usado como foto de perfil, ou null

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserData extends ChangeNotifier {
  UserData._();
  static final UserData instance = UserData._();

  static const keys = ['theme', 'favorites', 'teams', 'training', 'quizRecord', 'rankedRecord', 'quizGame', 'avatar'];
  static const _prefsKey = 'pocketdex_user_data';

  static Map<String, dynamic> get defaults => {
        'theme': 'dark',
        'favorites': <dynamic>[],
        'teams': <dynamic>[],
        'training': <dynamic>[],
        'quizRecord': 0,
        'rankedRecord': 0,
        'quizGame': null,
        'avatar': null,
      };

  Map<String, dynamic> _data = defaults;

  /// Avisado a cada mudança feita NO APARELHO (não nas que vêm da conta).
  void Function(Set<String> changedKeys)? onLocalChange;

  // ---------------------------------------------------------------- leitura

  String get theme => _data['theme'] as String? ?? 'dark';
  List<int> get favorites => _ints(_data['favorites']);
  List<Map<String, dynamic>> get teams => _maps(_data['teams']);
  List<Map<String, dynamic>> get training => _maps(_data['training']);
  int get quizRecord => (_data['quizRecord'] as num?)?.toInt() ?? 0;
  /// Foto de perfil: o id de um Pokémon (ou null).
  int? get avatar => (_data['avatar'] as num?)?.toInt();
  int get rankedRecord => (_data['rankedRecord'] as num?)?.toInt() ?? 0;
  Map<String, dynamic>? get quizGame =>
      _data['quizGame'] == null ? null : Map<String, dynamic>.from(_data['quizGame'] as Map);

  dynamic operator [](String key) => _data[key];
  Map<String, dynamic> snapshot([Iterable<String>? only]) =>
      {for (final k in only ?? keys) k: _jsonCopy(_data[k])};

  static List<int> _ints(dynamic v) =>
      (v as List? ?? []).whereType<num>().map((n) => n.toInt()).toList();
  static List<Map<String, dynamic>> _maps(dynamic v) =>
      (v as List? ?? []).whereType<Map>().map((m) => Map<String, dynamic>.from(_jsonCopy(m) as Map)).toList();
  static dynamic _jsonCopy(dynamic v) => v == null ? null : json.decode(json.encode(v));

  // ---------------------------------------------------------------- escrita

  /// Mudança feita no aparelho: salva e manda para a conta.
  void update(Map<String, dynamic> changes) {
    final changed = <String>{};
    changes.forEach((k, v) {
      if (!keys.contains(k)) return;
      if (json.encode(_data[k]) == json.encode(v)) return;
      _data[k] = _jsonCopy(v);
      changed.add(k);
    });
    if (changed.isEmpty) return;
    _persist();
    notifyListeners();
    onLocalChange?.call(changed);
  }

  /// Dados que chegaram da conta (não voltam para a conta).
  void applyRemote(Map<String, dynamic> remote, {Set<String> except = const {}}) {
    var changed = false;
    for (final k in keys) {
      if (!remote.containsKey(k) || except.contains(k)) continue;
      if (json.encode(_data[k]) == json.encode(remote[k])) continue;
      _data[k] = _jsonCopy(remote[k]);
      changed = true;
    }
    if (!changed) return;
    _persist();
    notifyListeners();
  }

  /// Ao sair da conta: os dados dela não ficam no aparelho.
  void clearAll() {
    final theme = this.theme;
    _data = {...defaults, 'theme': theme};
    _persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------- disco

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _data = {...defaults, ...Map<String, dynamic>.from(json.decode(raw) as Map)};
      } catch (_) {
        _data = defaults;
      }
    } else {
      _data = {...defaults, ..._legacy(prefs)};
      _persist();
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(_data));
  }

  /// Dados salvos pelas versões antigas do app (antes do login).
  Map<String, dynamic> _legacy(SharedPreferences prefs) {
    final out = <String, dynamic>{};
    final dark = prefs.getBool('theme_preference');
    if (dark != null) out['theme'] = dark ? 'dark' : 'light';
    final favs = prefs.getStringList('favorite_pokemon');
    if (favs != null) out['favorites'] = favs.map(int.tryParse).whereType<int>().toList();
    final record = prefs.getInt('quiz_highscore');
    if (record != null) out['quizRecord'] = record;
    try {
      final teams = prefs.getString('pokemon_teams');
      if (teams != null) out['legacyTeams'] = json.decode(teams);
      final training = prefs.getString('training_pokemon_list');
      if (training != null) out['legacyTraining'] = json.decode(training);
    } catch (_) {}
    return out;
  }

  /// Times e treinos antigos precisam do banco local para serem convertidos
  /// (ver AccountFormat.migrateLegacy); ficam guardados aqui até lá.
  List<dynamic>? takeLegacy(String key) {
    final value = _data.remove(key);
    if (value != null) _persist();
    return value as List<dynamic>?;
  }
}
