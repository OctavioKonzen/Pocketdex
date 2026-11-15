// lib/services/challenge.dart
//
// Desafio entre amigos (o mesmo do site, web-site/src/lib/challenge.js): um
// código com a semente da sequência de Pokémon, a geração, o modo e a
// pontuação de quem desafiou. Quem recebe joga os mesmos 10 Pokémon e compara.
// Não precisa de banco: tudo vai no próprio código.

import 'dart:convert';

const challengeRounds = 10;
const _siteUrl = 'https://octaviokonzen.github.io/Pocketdex/';

/// Modos de pista do jogo normal e do desafio.
const hints = [
  ('silhouette', 'Silhueta', '👤'),
  ('cry', 'Grito', '🔊'),
  ('description', 'Descrição', '📖'),
  ('types', 'Tipos', '🔥'),
];

int _imul(int a, int b) {
  final ah = (a >> 16) & 0xffff, al = a & 0xffff;
  final bh = (b >> 16) & 0xffff, bl = b & 0xffff;
  return (al * bl + (((ah * bl + al * bh) << 16) & 0xffffffff)) & 0xffffffff;
}

/// Gerador de números com semente (mesma sequência do site: mulberry32).
double Function() seeded(int seed) {
  var a = seed & 0xffffffff;
  return () {
    a = (a + 0x6d2b79f5) & 0xffffffff;
    var t = a;
    t = _imul(t ^ (t >> 15), t | 1);
    t = t ^ ((t + _imul(t ^ (t >> 7), t | 61)) & 0xffffffff);
    return ((t ^ (t >> 14)) & 0xffffffff) / 4294967296;
  };
}

/// As rodadas do desafio: [(resposta, opções)] a partir da semente.
List<(int, List<int>)> challengeRoundsFor(List<int> pool, int seed) {
  final rng = seeded(seed);
  final ids = [...pool]..sort();
  final rounds = <(int, List<int>)>[];
  final used = <int>{};
  final total = ids.length < challengeRounds ? ids.length : challengeRounds;
  final choices = ids.length < 4 ? ids.length : 4;
  while (rounds.length < total) {
    final answer = ids[(rng() * ids.length).floor()];
    if (!used.add(answer)) continue;
    final options = [answer];
    while (options.length < choices) {
      final id = ids[(rng() * ids.length).floor()];
      if (!options.contains(id)) options.add(id);
    }
    for (var i = options.length - 1; i > 0; i--) {
      final j = (rng() * (i + 1)).floor();
      final tmp = options[i];
      options[i] = options[j];
      options[j] = tmp;
    }
    rounds.add((answer, options));
  }
  return rounds;
}

class Challenge {
  final int seed;
  final int gen;
  final String hint;
  final String name;
  final int score;
  const Challenge({required this.seed, required this.gen, required this.hint, this.name = '', this.score = 0});

  /// Código do desafio (base64 do JSON, como no site).
  String get code => base64Url
      .encode(utf8.encode(json.encode({'s': seed, 'g': gen, 'h': hint, 'n': name, 'p': score})))
      .replaceAll('=', '');

  String get link => '$_siteUrl#/jogo?desafio=$code';

  /// Lê um código (ou link) de desafio; null se não for válido.
  static Challenge? decode(String text) {
    try {
      final code = (RegExp(r'desafio=([\w-]+)').firstMatch(text)?.group(1) ?? text).trim();
      final padded = code.padRight((code.length + 3) ~/ 4 * 4, '=');
      final d = json.decode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;
      final seed = d['s'];
      if (seed is! int) return null;
      final name = '${d['n'] ?? ''}';
      return Challenge(
        seed: seed,
        gen: (d['g'] as num?)?.toInt() ?? 0,
        hint: d['h'] as String? ?? 'silhouette',
        name: name.length > 20 ? name.substring(0, 20) : name,
        score: (d['p'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}
