// lib/services/official_teams.dart
//
// Times oficiais dos personagens (assets/database/official_teams.json, feito
// por tool/build_official_teams.py a partir das desmontagens do pret):
// separados por jogo, com todas as lutas de cada um. Igual ao site
// (web-site/src/lib/officialTeams.js).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class OfficialMon {
  final int id, level, ev;
  final int? iv;
  final String? item, nature, ability;
  final List<String> moves;
  final Map<String, int>? dv;
  const OfficialMon({required this.id, required this.level, required this.moves, this.item, this.iv, this.ev = 0, this.nature, this.ability, this.dv});

  factory OfficialMon.fromJson(Map<String, dynamic> j) => OfficialMon(
        id: (j['id'] as num).toInt(),
        level: (j['level'] as num).toInt(),
        moves: [for (final m in j['moves'] as List) m as String],
        item: j['item'] as String?,
        iv: (j['iv'] as num?)?.toInt(),
        ev: (j['ev'] as num?)?.toInt() ?? 0,
        nature: j['nature'] as String?,
        ability: j['ability'] as String?,
        dv: j['dv'] == null ? null : {for (final e in (j['dv'] as Map).entries) e.key as String: (e.value as num).toInt()},
      );

  static const _dvLabels = {'hp': 'HP', 'atk': 'Atk', 'def': 'Def', 'spe': 'Spe', 'spc': 'Spc'};

  /// "IVs: 30 em todos" (3ª/4ª geração) ou os DVs da 1ª/2ª geração.
  String get ivText => dv != null ? 'DVs: ${_dvLabels.entries.map((e) => '${e.value} ${dv![e.key]}').join(' · ')}' : 'IVs: $iv em todos';

  /// Na 1ª/2ª geração os treinadores não têm stat exp; nas outras, EVs 0.
  String get evText => dv != null ? 'Stat Exp: 0' : 'EVs: $ev em todos';
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
