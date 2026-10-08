// lib/services/gym_challenge.dart
//
// Desafio dos Líderes como jornada (dados da conta: 'league'). Igual ao site
// (web-site/src/lib/gymChallenge.js):
//   badges: {região: [id do líder]}   insígnias (líderes de ginásio e kahunas vencidos)
//   hall: [{region, at, team: [id do Pokémon], trainer}]   Hall da Fama (Liga vencida)
//   tower, factory: {best, streak}   Torre de Batalha e Battle Factory
// A Liga (Elite Four e o Campeão em sequência) fica liberada com 8 insígnias
// da região (ou todas, se a região tem menos de 8, como os 4 kahunas de Alola).

import 'dart:convert';

import 'gym_leaders.dart';

typedef Region = ({String region, List<GymLeader> leaders});

class GymChallenge {
  GymChallenge._();

  static Map<String, dynamic> empty() => {
        'badges': <String, dynamic>{},
        'hall': <dynamic>[],
        'tower': {'best': 0, 'streak': 0},
        'factory': {'best': 0, 'streak': 0},
      };

  static Map<String, dynamic> _base(Map<String, dynamic>? league) =>
      {...empty(), ...?(league == null ? null : jsonDecode(jsonEncode(league)) as Map<String, dynamic>)};

  /// Quem dá insígnia na região (líderes de ginásio e kahunas).
  static List<GymLeader> regionGyms(Region region) => [for (final l in region.leaders) if (l.kind == 'gym' || l.kind == 'kahuna') l];

  /// A Liga: a Elite Four e, no fim, o Campeão (o último da região).
  static List<GymLeader> leagueOrder(Region region) {
    final champions = [for (final l in region.leaders) if (l.kind == 'champion') l];
    return [for (final l in region.leaders) if (l.kind == 'elite') l, if (champions.isNotEmpty) champions.last];
  }

  static List<String> badgesOf(Map<String, dynamic>? league, Region region) =>
      [for (final id in ((league?['badges'] as Map?)?[region.region] as List?) ?? const []) '$id'];
  static int badgesNeeded(Region region) => regionGyms(region).length < 8 ? regionGyms(region).length : 8;
  static bool leagueOpen(Map<String, dynamic>? league, Region region) => badgesOf(league, region).length >= badgesNeeded(region);

  static Region? regionOf(List<Region> regions, String leaderId) =>
      regions.where((r) => r.leaders.any((l) => l.id == leaderId)).firstOrNull;

  /// Venceu um líder: ganha a insígnia (se for de ginásio ou kahuna).
  static Map<String, dynamic> winBadge(Map<String, dynamic>? league, List<Region> regions, GymLeader leader) {
    final base = _base(league);
    final region = regionOf(regions, leader.id);
    if (region == null || !(leader.kind == 'gym' || leader.kind == 'kahuna')) return base;
    final have = badgesOf(base, region);
    if (have.contains(leader.id)) return base;
    return {...base, 'badges': {...base['badges'] as Map, region.region: [...have, leader.id]}};
  }

  /// Venceu a Liga: entra no Hall da Fama (as entradas mais novas primeiro, até 30).
  static Map<String, dynamic> addHallOfFame(Map<String, dynamic>? league, Region region, List<int> team, String trainer, int now) {
    final base = _base(league);
    return {...base, 'hall': [{'region': region.region, 'at': now, 'team': team, 'trainer': trainer}, ...base['hall'] as List].take(30).toList()};
  }

  /// Resultado numa sequência (Torre/Factory): vitória soma, derrota zera; guarda o recorde.
  static Map<String, dynamic> streakResult(Map<String, dynamic>? league, String kind, bool won) {
    final base = _base(league);
    final now = Map<String, dynamic>.from(base[kind] as Map? ?? {'best': 0, 'streak': 0});
    final streak = won ? (now['streak'] as num).toInt() + 1 : 0;
    final best = (now['best'] as num).toInt();
    return {...base, kind: {'best': streak > best ? streak : best, 'streak': streak}};
  }

  /// Campeões com tema próprio (tool/build_battle_sounds.py).
  static const championThemes = ['blue', 'lance', 'steven', 'cynthia', 'alder', 'iris', 'diantha', 'kukui', 'leon', 'geeta'];

  /// A música da batalha (temas originais, nenhum copiado dos jogos): o tema do
  /// campeão, o da região para líderes, Elite Four e kahunas, ou a normal.
  static String musicOf(GymLeader? leader) {
    if (leader == null) return 'battle_music';
    final champion = leader.name.toLowerCase();
    if (leader.kind == 'champion' && championThemes.contains(champion)) return 'champion_$champion';
    return 'gym_${leader.region.toLowerCase()}';
  }
}
