import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/challenge.dart';

void main() {
  test('mesma sequência do site (web-site/src/lib/challenge.js)', () {
    final all = [for (var i = 1; i <= 1025; i++) i];
    final rounds = challengeRoundsFor(all, 123456789);
    expect(rounds.first.$1, 265);
    expect(rounds.first.$2, [265, 212, 805, 996]);
    expect(rounds[1].$2, [166, 292, 376, 17]);
    expect(rounds.last.$2, [395, 444, 161, 156]);
    final kanto = challengeRoundsFor([for (var i = 1; i <= 151; i++) i], 2147480000);
    expect(kanto.map((r) => r.$1).toList(), [130, 119, 80, 38, 5, 108, 94, 21, 26, 3]);
    expect(kanto[4].$2, [121, 99, 5, 126]);
  });

  test('código do desafio: ida e volta, e o formato do site', () {
    const c = Challenge(seed: 42, gen: 1, hint: 'cry', name: 'Ásh', score: 7);
    final back = Challenge.decode(c.link)!;
    expect((back.seed, back.gen, back.hint, back.name, back.score), (42, 1, 'cry', 'Ásh', 7));
    // Código gerado pelo site (btoa de UTF-8, sem "=").
    final site = Challenge.decode('eyJzIjo0MiwiZyI6MSwiaCI6ImNyeSIsIm4iOiLDgXNoIiwicCI6N30')!;
    expect((site.seed, site.name, site.score), (42, 'Ásh', 7));
    expect(Challenge.decode('lixo'), isNull);
  });
}
