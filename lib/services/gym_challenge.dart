// lib/services/gym_challenge.dart
//
// Desafio dos Líderes como jornada (dados da conta: 'league'). Igual ao site
// (web-site/src/lib/gymChallenge.js):
//   badges: {região: [id do líder]}   insígnias (líderes de ginásio e kahunas vencidos)
//   hall: [{region, at, team: [id do Pokémon], trainer}]   Hall da Fama (Liga vencida)
//   tower: {best, streak}   Torre de Batalha
//   factory: {best, coins, owned, run}   Battle Factory (factory_run.dart)
// A Liga (Elite dos Quatro e o Campeão em sequência) fica liberada com 8 insígnias
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
        'factory': {'best': 0, 'coins': 0, 'owned': <int>[], 'run': null},
      };

  static Map<String, dynamic> _base(Map<String, dynamic>? league) =>
      {...empty(), ...?(league == null ? null : jsonDecode(jsonEncode(league)) as Map<String, dynamic>)};

  /// Quem dá insígnia na região (líderes de ginásio e kahunas).
  static List<GymLeader> regionGyms(Region region) => [for (final l in region.leaders) if (l.kind == 'gym' || l.kind == 'kahuna') l];

  /// A Liga: a Elite dos Quatro e, no fim, o Campeão (o último da região).
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
  /// Os campeões com tema próprio (champion_<nome>), conforme vão sendo refeitos; os outros
  /// tocam o tema da região deles. Igual ao site.
  /// Os rivais com tema próprio (rival_<nome>, "Brendan/May" vira brendan-may), conforme vão sendo feitos;
  /// os outros tocam o tema da região. Igual ao site.
  static const rivalThemes = ['blue', 'silver', 'brendan-may', 'wally', 'barry', 'cheren', 'bianca', 'hugh', 'n', 'serena-calem', 'shauna', 'tierno', 'trevor', 'hau', 'gladion', 'hop', 'bede', 'marnie', 'nemona', 'arven', 'red', 'lillie', 'az', 'anabel', 'dexio', 'sina', 'benga', 'eusine', 'ryuki', 'sordward-e-shielbert', 'akari', 'adaman', 'irida', 'wes', 'solana', 'keith', 'summer', 'carmine', 'perrin'];

  /// Os vilões: os personagens importantes com tema próprio (villain_<nome>) e as equipes (villain_team_<equipe>),
  /// que os comandantes dividem, conforme vão sendo feitos; os outros tocam o tema da região. Igual ao site.
  static const villainThemes = ['giovanni', 'maxie', 'archie', 'cyrus', 'colress', 'lysandre', 'guzma', 'lusamine', 'ghetsis', 'giacomo', 'ortega', 'penny', 'rose', 'jessie-e-james'];
  /// As regiões com tema de ginásio e com tema da Elite dos Quatro (os outros: o tema da região). Igual ao site.
  static const gymThemes = ['kanto', 'johto', 'hoenn', 'sinnoh', 'unova', 'kalos', 'alola', 'galar', 'paldea', 'hisui', 'orre', 'fiore', 'almia', 'oblivia', 'kitakami', 'blueberry', 'sevii', 'armor', 'crown', 'orange'];
  /// Galar não tem Elite dos Quatro (os líderes lutam de novo na Copa).
  static const eliteThemes = ['kanto', 'johto', 'hoenn', 'sinnoh', 'unova', 'kalos', 'alola', 'paldea'];
  static const teamThemes = ['rocket', 'magma', 'aqua', 'galactic', 'plasma', 'flare', 'skull', 'aether', 'ultra', 'star', 'macro', 'yell'];
  static const villainTeams = {
    'giovanni': 'rocket', 'proton': 'rocket', 'ariana': 'rocket', 'archer': 'rocket', 'petrel': 'rocket', 'executiva': 'rocket',
    'executivo': 'rocket', 'maxie': 'magma', 'tabitha': 'magma', 'courtney': 'magma', 'archie': 'aqua', 'shelly': 'aqua',
    'matt': 'aqua', 'cyrus': 'galactic', 'mars': 'galactic', 'jupiter': 'galactic', 'saturn': 'galactic', 'kamado': 'galactic', 'n': 'plasma',
    'zinzolin': 'plasma', 'colress': 'plasma', 'ghetsis': 'plasma', 'lysandre': 'flare', 'bryony': 'flare', 'mable': 'flare',
    'aliana': 'flare', 'celosia': 'flare', 'xerosic': 'flare', 'guzma': 'skull', 'plumeria': 'skull', 'faba': 'aether',
    'lusamine': 'aether', 'soliera': 'ultra', 'dulse': 'ultra', 'giacomo': 'star', 'ortega': 'star', 'mela': 'star',
    'atticus': 'star', 'eri': 'star', 'penny': 'star', 'rose': 'macro', 'oleana': 'macro', 'equipe-yell': 'yell',
  };

  /// Rivais que dividem o tema (o mesmo papel, conforme o personagem escolhido no jogo).
  static const rivalAlias = {'brendan': 'brendan-may', 'may': 'brendan-may', 'serena': 'serena-calem', 'calem': 'serena-calem'};

  static const championThemes = ['blue', 'lance', 'steven', 'wallace', 'cynthia', 'alder', 'iris', 'diantha', 'kukui', 'leon', 'geeta', 'volo', 'evice', 'gordor', 'blake-hall', 'ice', 'kieran', 'mustard', 'peony', 'drake'];

  /// A música da batalha (temas originais, nenhum copiado dos jogos): o tema do
  /// campeão, o da região para líderes, Elite dos Quatro e kahunas, ou a normal.
  /// A música da batalha: o tema da região do líder/campeão; sem líder, o tema da região do primeiro Pokémon
  /// do adversário [foe] (como num ginásio daquela região). Igual ao site.
  static String musicOf(GymLeader? leader, {int foe = 0, int seed = 0}) =>
      leader == null ? regionTheme(foe, seed) : musicFor(leader.name, leader.kind, leader.region);

  /// O último número da Pokédex de cada região.
  static const dexRegions = [(151, 'kanto'), (251, 'johto'), (386, 'hoenn'), (493, 'sinnoh'), (649, 'unova'), (721, 'kalos'), (809, 'alola'), (905, 'galar'), (1025, 'paldea')];

  /// O tema da região do Pokémon [id] (o mesmo do mapa do Pokelike); as formas (Mega, regionais: o número não diz a região)
  /// ficam com uma região sorteada pela semente da batalha (sempre a mesma na mesma batalha).
  static String regionTheme(int id, [int seed = 0]) {
    for (final (last, region) in dexRegions) {
      if (id >= 1 && id <= last) return 'map_$region';
    }
    return 'map_${dexRegions[seed.abs() % dexRegions.length].$2}';
  }

  /// A música de um chefe pelo nome, tipo e região (também os da Battle Factory: rival e vilões).
  static String musicFor(String name, String kind, String region) {
    final champion = name.toLowerCase();
    final slug = champion.replaceAll('/', '-').replaceAll(' ', '-');
    if (kind == 'champion' && championThemes.contains(slug)) return 'champion_$slug';
    final rival = rivalAlias[slug] ?? slug;
    // Jessie e James (aparecem como a dupla de rivais da rota): o tema deles.
    if (slug == 'jessie-e-james' && villainThemes.contains(slug)) return 'villain_$slug';
    // O rival que vira Campeão (o Hau em Ultra Sun/Ultra Moon): o tema dele de rival.
    if ((kind == 'rival' || kind == 'champion') && rivalThemes.contains(rival)) return 'rival_$rival';
    // Um campeão que você enfrenta fora da Liga (a Cynthia em Unova, o Alder depois da Liga): o tema dele.
    if (kind == 'rival' && championThemes.contains(champion)) return 'champion_$champion';
    if (kind == 'villain') {
      if (villainThemes.contains(slug)) return 'villain_$slug';
      if (slug == 'n' && rivalThemes.contains('n')) return 'rival_n'; // N, rei da Equipe Plasma: o tema dele
      final team = villainTeams[slug];
      if (team != null && teamThemes.contains(team)) return 'villain_team_$team';
    }
    // Líderes de ginásio (capitães e kahunas) e a Elite dos Quatro: o tema de ginásio e o da Elite dos Quatro da região.
    final r = region.toLowerCase();
    if ((kind == 'gym' || kind == 'kahuna') && gymThemes.contains(r)) return 'gym_$r';
    if (kind == 'elite' && eliteThemes.contains(r)) return 'elite_$r';
    return 'map_$r'; // o tema da região (o mesmo do mapa do Pokelike)
  }
}
