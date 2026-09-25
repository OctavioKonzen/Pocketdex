// lib/services/team_share.dart
//
// Compartilhar times — mesmo formato do site (web-site/src/lib/teamShare.js):
//   • código: "PDX1" + base64url do JSON {n: nome, c: cor, p: [ids x6]};
//   • link: <site>/#/times/importar/<código>;
//   • texto do Pokémon Showdown (um Pokémon por bloco).

import 'dart:convert';

class SharedTeam {
  final String name;
  final String? color; // '#RRGGBB'
  final List<int?> pokemon; // 6 posições
  const SharedTeam(this.name, this.color, this.pokemon);
}

class TeamShare {
  TeamShare._();

  static const _prefix = 'PDX1';
  static const siteUrl = 'https://octaviokonzen.github.io/Pocketdex/';

  /// Time → código curto.
  static String encode({required String name, String? color, required List<int?> pokemon}) {
    final slots = [for (var i = 0; i < 6; i++) i < pokemon.length ? pokemon[i] : null];
    final jsonText = json.encode({'n': name, 'c': color, 'p': slots});
    return _prefix + base64Url.encode(utf8.encode(jsonText)).replaceAll('=', '');
  }

  /// Link que abre o site já importando o time.
  static String link({required String name, String? color, required List<int?> pokemon}) =>
      '$siteUrl#/times/importar/${encode(name: name, color: color, pokemon: pokemon)}';

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
      return SharedTeam(name.isEmpty ? 'Time' : name, color, pokemon);
    } catch (_) {
      return null;
    }
  }

  /// "charizard-mega-x" → "Charizard-Mega-X" (nome no Showdown).
  static String showdownName(String name) =>
      name.split('-').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join('-');

  /// Time → texto para colar no Pokémon Showdown. `names`: id → nome no banco.
  static String toShowdown(String teamName, List<int?> pokemon, Map<int, String> names) {
    final sets = [
      for (final id in pokemon)
        if (id != null && names[id] != null) '${showdownName(names[id]!)}\n',
    ];
    return '${'=== $teamName ===\n\n${sets.join('\n')}'.trim()}\n';
  }

  static String _simple(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Texto do Showdown → time. `rows`: todos os Pokémon {id, name, is_default}.
  static SharedTeam? fromShowdown(String text, List<Map<String, dynamic>> rows) {
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
    for (final block in blocks) {
      var first = block.split('\n').first.split('@').first.trim();
      first = first.replaceAll(RegExp(r'\((M|F)\)'), '').trim();
      final inner = RegExp(r'\(([^()]+)\)\s*$').firstMatch(first);
      final species = inner != null ? inner.group(1)! : first;
      final id = byName[_simple(species)] ?? byName[_simple(species.split('-').first)];
      if (id != null) pokemon.add(id);
      if (pokemon.length == 6) break;
    }
    if (pokemon.isEmpty) return null;
    return SharedTeam(
      header?.group(1) ?? 'Time importado',
      null,
      [...pokemon, for (var i = pokemon.length; i < 6; i++) null],
    );
  }

  /// Qualquer coisa colada (código, link ou Showdown) → time ou null.
  static SharedTeam? parse(String text, List<Map<String, dynamic>> rows) => decode(text) ?? fromShowdown(text, rows);
}
