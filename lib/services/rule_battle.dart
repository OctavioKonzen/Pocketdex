// lib/services/rule_battle.dart
//
// Desafio com regra. Igual ao site (web-site/src/lib/ruleBattle.js): uma
// regra nova toda semana (só um tipo, só uma geração, só os pequenos...), a
// mesma para todo mundo. O seu time e o do adversário seguem a regra.
//
//   league['ruleBattle'] = {week, wins}: as vitórias na regra desta semana.

import 'league.dart';

class BattleRule {
  const BattleRule(this.key, this.label, this.arg, this.fits);
  final String key;
  final String label;
  final String? arg;

  /// Se o Pokémon (tipos, geração, altura em decímetros) segue a regra.
  final bool Function(List<String> types, int gen, int height) fits;
}

class RuleBattle {
  // Na mesma ordem do site (TYPE_COLORS em web-site/src/lib/pokemon.js).
  static const types = [
    'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground', //
    'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
  ];

  static final rules = [
    for (final type in types) BattleRule('type:$type', 'Só Pokémon do tipo {0}', type, (t, _, __) => t.contains(type)),
    for (var g = 1; g <= 9; g++) BattleRule('gen:$g', 'Só Pokémon da geração {0}', '$g', (_, gen, __) => gen == g),
    BattleRule('small', 'Só Pokémon de até 1 metro', null, (_, __, h) => h <= 10),
    BattleRule('mono', 'Só Pokémon de um tipo só', null, (t, _, __) => t.length == 1),
  ];

  /// A regra da semana (a mesma para todos).
  static BattleRule ofWeek([String? week]) =>
      rules[(League.seededRandom(League.seedOf('pocketdex-rule-${week ?? League.weekKey()}'))() * rules.length).floor()];

  /// As vitórias na regra desta semana.
  static int wins(Map league, [String? week]) {
    final r = league['ruleBattle'];
    return r is Map && r['week'] == (week ?? League.weekKey()) ? (r['wins'] as num?)?.toInt() ?? 0 : 0;
  }

  /// A liga com mais uma vitória na regra da semana.
  static Map<String, dynamic> win(Map<String, dynamic> league, [String? week]) {
    week ??= League.weekKey();
    return {...league, 'ruleBattle': {'week': week, 'wins': wins(league, week) + 1}};
  }

  /// O texto da regra (com o tipo ou a geração), já com o {0} trocado.
  static String text(BattleRule rule, String Function(String) tr) =>
      tr(rule.label).replaceAll('{0}', rule.arg == null ? '' : rule.key.startsWith('type:') ? rule.arg![0].toUpperCase() + rule.arg!.substring(1) : rule.arg!);
}
