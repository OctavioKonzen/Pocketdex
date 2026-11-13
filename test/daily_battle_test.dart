import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/daily_battle.dart';

void main() {
  test('desafio do Pokémon do dia: vencer dá as moedas uma vez por dia (igual ao site)', () {
    final f = DailyBattle.win({'coins': 10}, '2026-01-01');
    expect(f, {'coins': 10 + DailyBattle.coins, 'dailyBattle': '2026-01-01'});
    expect(identical(DailyBattle.win(f, '2026-01-01'), f), isTrue);
    expect(DailyBattle.doneToday(f, '2026-01-01'), isTrue);
    expect(DailyBattle.doneToday(f, '2026-01-02'), isFalse);
    expect(DailyBattle.win(f, '2026-01-02')['coins'], 10 + 2 * DailyBattle.coins);
  });
}
