import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/league.dart';

void main() {
  test('usa o dia e a semana de Brasília (igual ao site)', () {
    // 25/09/2026 01:00 UTC ainda é 24/09 em Brasília (quinta-feira).
    final t = DateTime.utc(2026, 9, 25, 1);
    expect(League.dayKey(t), '2026-09-24');
    expect(League.weekKey(t), '2026-09-21');
    expect(League.weekKey(DateTime.utc(2026, 9, 27, 15)), '2026-09-21');
    expect(League.weekKey(DateTime.utc(2026, 9, 28, 15)), '2026-09-28');
  });

  test('sorteio do desafio igual ao do site (web-site/src/lib/league.test.js)', () {
    final seed = League.seedOf('pocketdex-2026-09-25');
    expect(seed, 1444911752);
    expect((League.seededRandom(seed)() * 1e9).floor(), 956775411);
    expect(League.dailyAnswers('2026-09-25'), [981, 470, 966, 342, 245, 178, 721, 937, 647, 563]);
  });

  test('pontos por rapidez', () {
    expect(League.dailyPoints(10000), 1100);
    expect(League.dailyPoints(0), 1000);
    expect(League.dailyPoints(4550), 1045);
  });
}
