// lib/utils/team_analysis.dart
//
// Análise de um time — a mesma do site (analyzeTeam em web-site/src/lib/pokemon.js).
// Para cada tipo de ataque conta quantos membros são fracos, resistem ou são
// imunes; o time é fraco a um tipo quando tem mais fracos do que quem aguenta.
// No ataque, conta quantos membros acertam cada tipo com dano super efetivo
// usando golpes do próprio tipo (STAB).

import '../services/battle.dart';

const allTypes = [
  'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison', 'ground',
  'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
];

class TypeRow {
  int weak = 0;
  int x4 = 0;
  int resist = 0;
  int immune = 0;

  int get covered => resist + immune;
  int get severity => weak + x4 - resist - immune;

  /// "3 fracos · 1 resiste"
  String get summary {
    final parts = <String>[
      if (weak > 0) '$weak ${weak == 1 ? 'fraco' : 'fracos'}${x4 > 0 ? ' ($x4 ×4)' : ''}',
      if (resist > 0) '$resist ${resist == 1 ? 'resiste' : 'resistem'}',
      if (immune > 0) '$immune ${immune == 1 ? 'imune' : 'imunes'}',
    ];
    return parts.join(' · ');
  }
}

class TeamAnalysis {
  final int size;
  final Map<String, TypeRow> rows;
  final List<String> weaknesses; // do pior para o menos pior
  final List<String> strengths;
  final List<String> immunities;
  final Map<String, int> advantages;
  final List<String> missing;

  const TeamAnalysis._(this.size, this.rows, this.weaknesses, this.strengths, this.immunities, this.advantages, this.missing);

  /// `chart[tipo]` = relações do tipo (double_damage_from, half_damage_from,
  /// no_damage_from, double_damage_to...), como em LocalDatabase.typeChart().
  static TeamAnalysis? of(List<List<String>> membersTypes, Map<String, Map<String, List<String>>> chart) {
    if (membersTypes.isEmpty) return null;
    final rows = {for (final t in allTypes) t: TypeRow()};
    final advantages = <String, int>{};
    for (final types in membersTypes) {
      for (final attacking in allTypes) {
        final mult = Battle.effectiveness(attacking, types, chart);
        final row = rows[attacking]!;
        if (mult == 0) {
          row.immune++;
        } else if (mult > 1) {
          row.weak++;
          if (mult >= 4) row.x4++;
        } else if (mult < 1) {
          row.resist++;
        }
      }
      for (final type in types.toSet()) {
        for (final t in chart[type]?['double_damage_to'] ?? const <String>[]) {
          advantages[t] = (advantages[t] ?? 0) + 1;
        }
      }
    }
    final weaknesses = allTypes.where((t) => rows[t]!.weak > rows[t]!.covered).toList()
      ..sort((a, b) => rows[b]!.severity.compareTo(rows[a]!.severity));
    final strengths = allTypes.where((t) => rows[t]!.covered >= 2 && rows[t]!.covered > rows[t]!.weak).toList()
      ..sort((a, b) => rows[a]!.severity.compareTo(rows[b]!.severity));
    return TeamAnalysis._(
      membersTypes.length,
      rows,
      weaknesses,
      strengths,
      allTypes.where((t) => rows[t]!.immune > 0).toList(),
      advantages,
      allTypes.where((t) => !advantages.containsKey(t)).toList(),
    );
  }

  /// Frases do que o time faz bem e mal (true = bom).
  List<(bool, String)> get tips {
    final out = <(bool, String)>[];
    if (weaknesses.isNotEmpty) {
      final type = weaknesses.first;
      final row = rows[type]!;
      final cover = row.covered;
      out.add((
        false,
        '${row.weak} de $size Pokémon ${row.weak == 1 ? 'é fraco' : 'são fracos'} a $type e '
            '${cover == 0 ? 'ninguém aguenta' : 'só $cover ${cover == 1 ? 'aguenta' : 'aguentam'}'}.',
      ));
    }
    if (missing.length > 6) out.add((false, 'O time não tem golpes super efetivos (STAB) contra ${missing.length} tipos.'));
    if (weaknesses.isEmpty) out.add((true, 'Nenhum tipo deixa o time em desvantagem. Ótima defesa!'));
    if (strengths.length >= 6) out.add((true, 'Boa defesa: aguenta bem ${strengths.length} tipos.'));
    if (missing.length <= 3) out.add((true, 'Ótima cobertura: acerta quase todos os tipos com dano super efetivo.'));
    return out;
  }
}
