import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/rule_battle.dart';

void main() {
  test('Regra da semana: a mesma do site', () {
    expect(RuleBattle.ofWeek('2026-10-26').key, 'type:fire');
    expect(RuleBattle.ofWeek('2026-11-02').key, 'type:ghost');
    expect(RuleBattle.ofWeek('2026-11-09').key, 'type:flying');
    expect(RuleBattle.rules.length, 29);
  });

  test('Regra da semana: as vitórias', () {
    final l = RuleBattle.win(RuleBattle.win({}, '2026-10-26'), '2026-10-26');
    expect(RuleBattle.wins(l, '2026-10-26'), 2);
    expect(RuleBattle.wins(l, '2026-11-02'), 0);
  });
}
