// lib/services/weekly_battle.dart
//
// Desafio semanal da Batalha. Igual ao site (web-site/src/lib/weeklyBattle.js):
// todo mundo enfrenta o mesmo time na semana (sorteado pela segunda-feira de
// Brasília, com sets competitivos e a mesma semente de batalha) e o ranking
// mostra quem venceu em menos turnos.
//
//   battleWeek/{semana}/scores/{uid} → {name, score, avatar}: score = 1000 − turnos (só sobe).

import 'league.dart';

class WeeklyBattle {
  static const maxTurns = 999;

  /// O sorteador da semana: o mesmo time e a mesma batalha para todos.
  static double Function() random([String? week]) => League.seededRandom(League.seedOf('pocketdex-weekly-battle-${week ?? League.weekKey()}'));

  /// Turnos → pontuação do ranking (menos turnos, mais pontos).
  static int turnsToScore(int turns) {
    final score = maxTurns + 1 - (turns < 1 ? 1 : turns);
    return score < 1 ? 1 : score;
  }

  /// Pontuação do ranking → turnos.
  static int scoreToTurns(int score) => maxTurns + 1 - score;

  /// O recorde (menos turnos) da semana: league['weeklyBattle'] = {week, best}.
  static int? best(Map league, [String? week]) {
    final w = league['weeklyBattle'];
    return w is Map && w['week'] == (week ?? League.weekKey()) ? (w['best'] as num?)?.toInt() : null;
  }

  /// A liga com a vitória em [turns] turnos (guarda o menor da semana).
  static Map<String, dynamic> win(Map<String, dynamic> league, int turns, [String? week]) {
    week ??= League.weekKey();
    final old = best(league, week);
    return old != null && old <= turns ? league : {...league, 'weeklyBattle': {'week': week, 'best': turns}};
  }
}
