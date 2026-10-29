// lib/services/gym_leaders.dart
//
// Desafio dos Líderes (assets/database/gym_leaders.json, feito por
// tool/build_gym_leaders.py): líderes de ginásio, Elite Four e campeões de
// cada região com o time original, já evoluído, todos no nível 50. Igual ao
// site (getGymLeaders em web-site/src/lib/data.js).

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'team_battle.dart';
import 'turn_battle.dart';

class GymLeader {
  final String id, name, kind, type, trainer, region;
  final List<int> team;
  const GymLeader({required this.id, required this.name, required this.kind, required this.type, required this.trainer, required this.region, required this.team});

  static const kindLabels = {'gym': 'Líder de Ginásio', 'elite': 'Elite Four', 'champion': 'Campeão', 'kahuna': 'Kahuna'};
  String get kindLabel => kindLabels[kind] ?? kind;

  /// O time no nível 50 com os sets do computador.
  Future<List<Member>> members(double Function() random, {String difficulty = 'normal'}) =>
      TurnBattleSetup.npcMembers(team, random, difficulty: difficulty);
}

class GymLeaders {
  GymLeaders._();

  static Future<List<({String region, List<GymLeader> leaders})>>? _loading;

  static Future<List<({String region, List<GymLeader> leaders})>> load() =>
      _loading ??= rootBundle.loadString('assets/database/gym_leaders.json').then((text) => [
            for (final r in jsonDecode(text) as List)
              (
                region: r['region'] as String,
                leaders: [
                  for (final l in r['leaders'] as List)
                    GymLeader(
                      id: l['id'] as String,
                      name: l['name'] as String,
                      kind: l['kind'] as String,
                      type: l['type'] as String,
                      trainer: l['trainer'] as String,
                      region: r['region'] as String,
                      team: [for (final id in l['team'] as List) (id as num).toInt()],
                    ),
                ],
              ),
          ]);
}
