import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/weekly_battle.dart';

void main() {
  test('Desafio semanal: menos turnos, mais pontos', () {
    expect(WeeklyBattle.turnsToScore(10), greaterThan(WeeklyBattle.turnsToScore(11)));
    expect(WeeklyBattle.scoreToTurns(WeeklyBattle.turnsToScore(23)), 23);
    expect(WeeklyBattle.turnsToScore(5000), 1);
  });

  test('Desafio semanal: o mesmo sorteio do site', () {
    final a = WeeklyBattle.random('2026-10-26'), b = WeeklyBattle.random('2026-10-26');
    expect([a(), a()], [b(), b()]);
  });

  test('Desafio semanal: guarda o menor número de turnos da semana', () {
    var league = WeeklyBattle.win({}, 20, '2026-10-26');
    league = WeeklyBattle.win(league, 25, '2026-10-26');
    expect(WeeklyBattle.best(league, '2026-10-26'), 20);
    expect(WeeklyBattle.best(WeeklyBattle.win(league, 12, '2026-10-26'), '2026-10-26'), 12);
    expect(WeeklyBattle.best(league, '2026-11-02'), null);
  });
}
