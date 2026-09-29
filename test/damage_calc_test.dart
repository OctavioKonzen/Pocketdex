// Confere a calculadora de dano do app (lib/services/damage_calc.dart) contra
// a calculadora oficial do Pokémon Showdown: test/fixtures/damage_cases.json.gz
// tem milhares de situações aleatórias (habilidades, itens, campo, golpes
// especiais...) com o resultado do original, geradas por
// web-site/scripts/build-damage-data.mjs.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/damage_calc.dart';

Map<String, int> _stats(Map<String, dynamic> m) => m.map((k, v) => MapEntry(k, (v as num).toInt()));

CalcPokemon _pokemon(DamageData data, Map<String, dynamic> s) {
  final ability = s['ability'] as String;
  final p = CalcPokemon(
    data,
    s['species'] as String,
    baseStats: _stats(s['baseStats'] as Map<String, dynamic>),
    types: (s['types'] as List).cast<String>(),
    weightkg: (s['weightkg'] as num).toDouble(),
    level: (s['level'] as num).toInt(),
    ability: ability,
    abilityOn: s['abilityOn'] as bool,
    alliesFainted: (s['alliesFainted'] as num).toInt(),
    boostedStat: (ability == 'Protosynthesis' || ability == 'Quark Drive') && s['abilityOn'] == true ? 'auto' : '',
    item: s['item'] as String,
    teraType: s['teraType'] as String,
    nature: s['nature'] as String,
    ivs: _stats(s['ivs'] as Map<String, dynamic>),
    evs: _stats(s['evs'] as Map<String, dynamic>),
    boosts: _stats(s['boosts'] as Map<String, dynamic>),
    status: s['status'] as String,
    toxicCounter: (s['toxicCounter'] as num).toInt(),
  );
  final hp = (p.maxHP() * (s['hpPct'] as num) / 100).floor();
  p.originalCurHP = hp < 1 ? 1 : hp;
  return p;
}

void main() {
  final data = DamageData(jsonDecode(File('assets/database/damage_data.json').readAsStringSync()) as Map<String, dynamic>);
  final cases = (jsonDecode(utf8.decode(gzip.decode(File('test/fixtures/damage_cases.json.gz').readAsBytesSync()))) as List)
      .cast<Map<String, dynamic>>();

  test('igual ao Pokémon Showdown em ${cases.length} situações', () {
    final failures = <String>[];
    for (var i = 0; i < cases.length; i++) {
      final c = cases[i];
      final m = c['m'] as Map<String, dynamic>;
      final a = _pokemon(data, c['a'] as Map<String, dynamic>);
      final d = _pokemon(data, c['d'] as Map<String, dynamic>);
      final move = CalcMove(
        data,
        m['name'] as String,
        ability: a.ability,
        item: a.item,
        isCrit: m['isCrit'] == true,
        isStellarFirstUse: m['isStellarFirstUse'] == true,
        hits: (m['hits'] as num?)?.toInt() ?? 0,
        timesUsed: (m['timesUsed'] as num?)?.toInt() ?? 0,
        timesUsedWithMetronome: (m['timesUsedWithMetronome'] as num?)?.toInt() ?? 0,
      );
      final field = CalcField.fromJson(c['f'] as Map<String, dynamic>);
      final out = c['out'] as Map<String, dynamic>;
      final expected = (out['damage'] as List).map((h) => (h as List).map((x) => (x as num).toInt()).toList()).toList();
      String? problem;
      try {
        final r = calculateDamage(a, d, move, field);
        if (jsonEncode(r.damage) != jsonEncode(expected)) {
          problem = 'dano ${jsonEncode(r.damage)} ≠ ${jsonEncode(expected)}';
        } else if (r.move.hits != out['hits']) {
          problem = 'acertos ${r.move.hits} ≠ ${out['hits']}';
        } else {
          final ko = out['ko'] as List?;
          final (_, max) = r.range();
          if (ko != null && max > 0) {
            final got = r.kochance();
            final chance = (ko[0] as num).toDouble();
            final n = (ko[1] as num).toInt();
            final gotChance = got.chance ?? -1;
            if (got.n != n || (gotChance - chance).abs() > 1e-9) {
              problem = 'KO ${got.chance}/${got.n} ≠ $chance/$n (${ko[2]})';
            }
          }
        }
      } catch (e, st) {
        problem = 'erro: $e\n$st';
      }
      if (problem != null) {
        failures.add('#$i ${c['a']['species']} (${c['a']['ability']}, ${c['a']['item']}) → '
            '${c['d']['species']} (${c['d']['ability']}, ${c['d']['item']}) com ${m['name']}: $problem');
      }
    }
    if (failures.isNotEmpty) {
      fail('${failures.length} de ${cases.length} diferentes:\n${failures.take(15).join('\n')}');
    }
  });
}
