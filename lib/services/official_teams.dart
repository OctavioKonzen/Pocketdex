// lib/services/official_teams.dart
//
// Times oficiais dos personagens (assets/database/official_teams.json, feito
// por tool/build_official_teams.py a partir das desmontagens do pret):
// separados por jogo, com todas as lutas de cada um. Igual ao site
// (web-site/src/lib/officialTeams.js).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

Map<String, int>? _stats(Object? value) =>
    value is Map ? {for (final e in value.entries) e.key as String: (e.value as num).toInt()} : null;

class OfficialMon {
  final int id, level;

  /// IVs e EVs: o mesmo valor em todos ([iv], [ev]) ou um por status ([ivs], [evs]).
  final int? iv, ev;
  final Map<String, int>? ivs, evs, dv;
  final String? item, nature, ability, ivNote, tera;
  final List<String>? abilityOptions;
  final bool shiny;
  final List<String> moves;
  const OfficialMon({
    required this.id,
    required this.level,
    required this.moves,
    this.item,
    this.iv,
    this.ivs,
    this.ivNote,
    this.ev = 0,
    this.evs,
    this.nature,
    this.ability,
    this.abilityOptions,
    this.tera,
    this.shiny = false,
    this.dv,
  });

  factory OfficialMon.fromJson(Map<String, dynamic> j) => OfficialMon(
        id: (j['id'] as num).toInt(),
        level: (j['level'] as num).toInt(),
        moves: [for (final m in j['moves'] as List) m as String],
        item: j['item'] as String?,
        iv: j['iv'] is num ? (j['iv'] as num).toInt() : null,
        ivs: _stats(j['iv']),
        ivNote: j['ivNote'] as String?,
        ev: j['ev'] is num ? (j['ev'] as num).toInt() : null,
        evs: _stats(j['ev']),
        nature: j['nature'] as String?,
        ability: j['ability'] as String?,
        abilityOptions: (j['abilityOptions'] as List?)?.cast<String>(),
        tera: j['tera'] as String?,
        shiny: j['shiny'] == true,
        dv: _stats(j['dv']),
      );

  static const _dvLabels = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spe': 'Spe', 'spc': 'Spc'};
  static const _statLabels = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spa': 'SpA', 'spd': 'SpD', 'spe': 'Spe'};

  /// "IVs: 30 em todos", um por status, sorteados (o jogo sorteia) ou os DVs da 1ª/2ª geração.
  String get ivText {
    if (dv != null) return 'DVs: ${_dvLabels.entries.map((e) => '${e.value} ${dv![e.key]}').join(' · ')}';
    if (ivNote != null) return 'IVs: $ivNote';
    if (ivs != null) return 'IVs: ${_statLabels.entries.map((e) => '${e.value} ${ivs![e.key]}').join(' · ')}';
    return 'IVs: $iv em todos';
  }

  /// Na 1ª/2ª geração os treinadores não têm stat exp; nas outras, os EVs (iguais ou um por status).
  String get evText {
    if (dv != null) return 'Stat Exp: 0';
    if (evs != null) return 'EVs: ${_statLabels.entries.where((e) => (evs![e.key] ?? 0) > 0).map((e) => '${evs![e.key]} ${e.value}').join(' / ')}';
    return 'EVs: $ev em todos';
  }

  /// A habilidade, ou as opções quando o jogo sorteia.
  String? abilityText(String Function(String) pretty) =>
      ability != null ? pretty(ability!) : abilityOptions == null ? null : '${abilityOptions!.map(pretty).join(' ou ')} (sorteada)';
}

class OfficialBattle {
  final String label;
  final List<OfficialMon> team;
  const OfficialBattle(this.label, this.team);
}

class OfficialTrainer {
  final String name, trainerClass;
  final String? trainer;
  final List<OfficialBattle> battles;
  const OfficialTrainer({required this.name, required this.trainerClass, required this.battles, this.trainer});
}

class OfficialGame {
  final String id, name, region, source;
  final int generation;
  final List<OfficialTrainer> trainers;
  const OfficialGame({required this.id, required this.name, required this.region, required this.source, required this.generation, required this.trainers});

  /// Dados da comunidade (calculadoras de Nuzlocke), não tirados do código do jogo.
  bool get community => source == 'community';

  /// Personagens que batem com a busca (nome ou classe).
  List<OfficialTrainer> filter(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return trainers;
    return [for (final t in trainers) if (t.name.toLowerCase().contains(q) || t.trainerClass.toLowerCase().contains(q)) t];
  }
}

class OfficialTeams {
  OfficialTeams._();

  static Future<List<OfficialGame>>? _loading;

  static Future<List<OfficialGame>> load() =>
      _loading ??= rootBundle.loadString('assets/database/official_teams.json').then((text) => parse(jsonDecode(text) as List));

  static List<OfficialGame> parse(List data) => [
        for (final g in data)
          OfficialGame(
            id: g['id'] as String,
            name: g['name'] as String,
            region: g['region'] as String,
            source: g['source'] as String,
            generation: (g['generation'] as num).toInt(),
            trainers: [
              for (final t in g['trainers'] as List)
                OfficialTrainer(
                  name: t['name'] as String,
                  trainerClass: t['class'] as String,
                  trainer: t['trainer'] as String?,
                  battles: [
                    for (final b in t['battles'] as List)
                      OfficialBattle(b['label'] as String, [for (final m in b['team'] as List) OfficialMon.fromJson(m as Map<String, dynamic>)]),
                  ],
                ),
            ],
          ),
      ];

  /// Todas as vezes que o personagem aparece (mesmo nome), em ordem de jogo.
  static List<({OfficialGame game, OfficialTrainer trainer})> appearances(List<OfficialGame> games, String name) => [
        for (final g in games)
          for (final t in g.trainers)
            if (t.name == name) (game: g, trainer: t),
      ];
}
