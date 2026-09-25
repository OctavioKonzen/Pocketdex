// lib/services/league.dart
//
// Desafio do dia e ranking da semana — as MESMAS contas do site
// (web-site/src/lib/league.js), para o desafio ser igual no app e no site.
//   • O dia e a semana seguem o horário de Brasília (UTC−3).
//   • A semana é identificada pela segunda-feira dela ("AAAA-MM-DD").
//   • Os 10 Pokémon do dia saem de um sorteio com semente = a data.

class League {
  League._();

  static const dailyRounds = 10;
  static const dailySeconds = 10;
  static const dailySpecies = 1025;

  static const _mask = 0xFFFFFFFF;

  static DateTime _brasilia([DateTime? now]) => (now ?? DateTime.now()).toUtc().subtract(const Duration(hours: 3));

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "2026-09-25" — o dia de hoje em Brasília.
  static String dayKey([DateTime? now]) => _iso(_brasilia(now));

  /// "2026-09-21" — a segunda-feira da semana de hoje em Brasília.
  static String weekKey([DateTime? now]) {
    final d = _brasilia(now);
    final monday = DateTime.utc(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));
    return _iso(monday);
  }

  // Multiplicação de 32 bits (como Math.imul do JavaScript).
  static int _imul(int a, int b) => (a * b) & _mask;

  /// Sorteio com semente (mulberry32): mesma semente, mesma sequência.
  static double Function() seededRandom(int seed) {
    var a = seed & _mask;
    return () {
      a = (a + 0x6D2B79F5) & _mask;
      var t = _imul(a ^ (a >> 15), 1 | a);
      t = ((t + _imul(t ^ (t >> 7), 61 | t)) & _mask) ^ t;
      return ((t ^ (t >> 14)) & _mask) / 4294967296;
    };
  }

  /// Semente a partir de um texto (ex.: a data). Igual ao site (inteiro de 32 bits com sinal).
  static int seedOf(String text) {
    var h = 0;
    for (final c in text.codeUnits) {
      h = (_imul(31, h) + c) & _mask;
    }
    return h >= 0x80000000 ? h - 0x100000000 : h;
  }

  /// Os ids dos 10 Pokémon do desafio de um dia (iguais para todo mundo).
  static List<int> dailyAnswers([String? day]) {
    final random = seededRandom(seedOf('pocketdex-${day ?? dayKey()}'));
    final ids = <int>[];
    while (ids.length < dailyRounds) {
      final id = 1 + (random() * dailySpecies).floor();
      if (!ids.contains(id)) ids.add(id);
    }
    return ids;
  }

  /// Pontos de uma resposta certa: 1000 + décimos de segundo que sobraram.
  static int dailyPoints(int msLeft) => 1000 + (msLeft ~/ 100).clamp(0, dailySeconds * 10);
}
