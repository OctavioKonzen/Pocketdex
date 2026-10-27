// lib/services/team_share.dart
//
// Compartilhar times — mesmo formato do site (web-site/src/lib/teamShare.js):
//   • código: "PDX1" + base64url do JSON {n: nome, c: cor, p: [ids x6], s: [sets x6]};
//   • link: <site>/#/times/importar/<código>;
//   • texto de times dos simuladores (um Pokémon por bloco, com item,
//     habilidade, EVs, Nature, golpes...).

import 'dart:convert';

import 'team_sets.dart';

class SharedTeam {
  final String name;
  final String? color; // '#RRGGBB'
  final List<int?> pokemon; // 6 posições
  final List<Map<String, dynamic>?> sets; // 6 posições (lib/services/team_sets.dart)
  SharedTeam(this.name, this.color, this.pokemon, [List<Map<String, dynamic>?>? sets])
      : sets = sets ?? List.filled(6, null);
}

class TeamShare {
  TeamShare._();

  static const _prefix = 'PDX1';
  static const siteUrl = 'https://octaviokonzen.github.io/Pocketdex/';

  /// Time → código curto.
  static String encode({required String name, String? color, required List<int?> pokemon, List<Map<String, dynamic>?>? sets}) {
    final slots = [for (var i = 0; i < 6; i++) i < pokemon.length ? pokemon[i] : null];
    final full = teamSets(slots, sets);
    final jsonText = json.encode({'n': name, 'c': color, 'p': slots, if (full.any((x) => x != null)) 's': full});
    return _prefix + base64Url.encode(utf8.encode(jsonText)).replaceAll('=', '');
  }

  /// Link que abre o site já importando o time.
  static String link({required String name, String? color, required List<int?> pokemon, List<Map<String, dynamic>?>? sets}) =>
      '$siteUrl#/times/importar/${encode(name: name, color: color, pokemon: pokemon, sets: sets)}';

  /// Código (ou link com o código) → time, ou null.
  static SharedTeam? decode(String text) {
    final match = RegExp(r'PDX1([A-Za-z0-9_-]+)').firstMatch(text);
    if (match == null) return null;
    try {
      var code = match.group(1)!;
      code += '=' * ((4 - code.length % 4) % 4);
      final data = json.decode(utf8.decode(base64Url.decode(code))) as Map<String, dynamic>;
      final p = data['p'] as List? ?? [];
      final pokemon = [for (var i = 0; i < 6; i++) i < p.length && p[i] is int ? p[i] as int : null];
      final c = data['c'];
      final color = c is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c) ? c : null;
      var name = '${data['n'] ?? 'Time'}';
      if (name.length > 40) name = name.substring(0, 40);
      return SharedTeam(name.isEmpty ? 'Time' : name, color, pokemon, teamSets(pokemon, data['s']));
    } catch (_) {
      return null;
    }
  }

  /// "charizard-mega-x" → "Charizard-Mega-X" (nome no Showdown).
  static String showdownName(String name) =>
      name.split('-').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join('-');

  /// Time → texto para colar em simuladores (Pokémon Showdown e outros).
  /// `names`: id → nome no banco.
  static String toShowdown(String teamName, List<int?> pokemon, Map<int, String> names, [List<Map<String, dynamic>?>? sets]) {
    final full = teamSets(pokemon, sets);
    final blocks = [
      for (var i = 0; i < pokemon.length; i++)
        if (pokemon[i] != null && names[pokemon[i]] != null) setToText(showdownName(names[pokemon[i]]!), i < 6 ? full[i] : null),
    ];
    return '${'=== $teamName ===\n\n${blocks.join('\n')}'.trim()}\n';
  }

  static String _simple(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Texto do Showdown → time. `rows`: todos os Pokémon {id, name, is_default}.
  static SharedTeam? fromShowdown(String text, List<Map<String, dynamic>> rows,
      {Map<String, String>? moves, Map<String, String>? abilities, Map<String, String>? items}) {
    final byName = <String, int>{};
    for (final p in rows) {
      byName[_simple(p['name'] as String)] = p['id'] as int;
    }
    // "Landorus" → "landorus-incarnate", "Deoxys" → "deoxys-normal"...
    for (final p in rows) {
      final base = _simple((p['name'] as String).split('-').first);
      if (p['is_default'] == true) byName.putIfAbsent(base, () => p['id'] as int);
    }
    final header = RegExp(r'===\s*(?:\[[^\]]*\]\s*)?(.+?)\s*===').firstMatch(text);
    final blocks = text
        .replaceAll(RegExp(r'===.*?==='), '')
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty);
    final pokemon = <int>[];
    final sets = <Map<String, dynamic>>[];
    for (final block in blocks) {
      final parsed = textToSet(block, moves: moves, abilities: abilities, items: items);
      if (parsed == null) continue;
      final (species, set) = parsed;
      final id = byName[_simple(species)] ?? byName[_simple(species.split('-').first)];
      if (id == null) continue;
      pokemon.add(id);
      sets.add(set);
      if (pokemon.length == 6) break;
    }
    if (pokemon.isEmpty) return null;
    return SharedTeam(
      header?.group(1) ?? 'Time importado',
      null,
      [...pokemon, for (var i = pokemon.length; i < 6; i++) null],
      [...sets, for (var i = sets.length; i < 6; i++) null],
    );
  }

  /// Qualquer coisa colada (código, link ou Showdown) → time ou null.
  static SharedTeam? parse(String text, List<Map<String, dynamic>> rows,
          {Map<String, String>? moves, Map<String, String>? abilities, Map<String, String>? items}) =>
      decode(text) ?? fromShowdown(text, rows, moves: moves, abilities: abilities, items: items);
}
