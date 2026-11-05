// lib/services/achievements.dart
//
// Conquistas (medalhas) — as mesmas do site (web-site/src/lib/achievements.js).
// São calculadas a partir dos dados da conta; `stats` guarda os contadores:
//   stats: {correct, bestStreak, rankedGames, dailyDone, dailyPerfect,
//           lastDaily: 'AAAA-MM-DD', days: [...], weeks: [...]}

class Achievement {
  final String id;
  final String icon;
  final String title;
  final String text;
  final bool unlocked;
  const Achievement(this.id, this.icon, this.title, this.text, this.unlocked);
}

class Achievements {
  Achievements._();

  static Map<String, dynamic> emptyStats() => {
        'correct': 0,
        'bestStreak': 0,
        'rankedGames': 0,
        'dailyDone': 0,
        'dailyPerfect': 0,
        'lastDaily': null,
        'days': <dynamic>[],
        'weeks': <dynamic>[],
      };

  static int _n(Map<String, dynamic> stats, String key) => (stats[key] as num?)?.toInt() ?? 0;

  static bool _full(Map<String, dynamic> team) =>
      ((team['pokemon'] as List?) ?? []).where((p) => p != null).length == 6;

  static List<Achievement> of({
    required Map<String, dynamic> stats,
    required int rankedRecord,
    required List<int> favorites,
    required List<Map<String, dynamic>> teams,
  }) {
    final s = {...emptyStats(), ...stats};
    final fullTeams = teams.where(_full).length;
    return [
      Achievement('first', '🎯', 'Primeiro acerto', 'Acerte um Pokémon no jogo.', _n(s, 'correct') >= 1),
      Achievement('trainer', '🎒', 'Treinador', 'Acerte 100 Pokémon no jogo.', _n(s, 'correct') >= 100),
      Achievement('master', '🎓', 'Mestre Pokémon', 'Acerte 1000 Pokémon no jogo.', _n(s, 'correct') >= 1000),
      Achievement('streak', '🔥', 'Em chamas', 'Faça uma sequência de 10 acertos.', _n(s, 'bestStreak') >= 10),
      Achievement('unstoppable', '☄️', 'Imparável', 'Faça uma sequência de 50 acertos.', _n(s, 'bestStreak') >= 50),
      Achievement('ranked', '🏆', 'Competidor', 'Faça 100 pontos no Ranked.', rankedRecord >= 100),
      Achievement('lightning', '⚡', 'Relâmpago', 'Chegue a 400 pontos no Ranked (2 s por Pokémon).', rankedRecord >= 400),
      Achievement('daily', '📅', 'Desafiante', 'Complete um desafio do dia.', _n(s, 'dailyDone') >= 1),
      Achievement('loyal', '🗓️', 'Fiel', 'Complete 7 desafios do dia.', _n(s, 'dailyDone') >= 7),
      Achievement('perfect', '💯', 'Perfeito', 'Acerte os 10 Pokémon de um desafio do dia.', _n(s, 'dailyPerfect') >= 1),
      Achievement('collector', '⭐', 'Colecionador', 'Tenha 10 Pokémon favoritos.', favorites.length >= 10),
      Achievement('team', '🛡️', 'Time completo', 'Monte um time com 6 Pokémon.', fullTeams >= 1),
      Achievement('strategist', '♟️', 'Estrategista', 'Tenha 5 times completos.', fullTeams >= 5),
    ];
  }
}
