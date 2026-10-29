import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_analysis.dart';

const names = [
  ['A', 'B', 'C'],
  ['X', 'Y', 'Z'],
];
BattleKo ko(int turn, int side, [int? by]) => (turn: turn, side: side, by: by == null ? null : (1 - side, by));

void main() {
  test('Análise: derrota com quem varreu e o turno da virada (igual ao site)', () {
    final out = BattleAnalysis.of([ko(2, 1, 0), ko(4, 0, 2), ko(5, 0, 2), ko(7, 0, 2)], [3, 3], names, 1);
    expect([for (final o in out) o.$1], ['🌪️', '📉', '🎯']);
    expect(out[0].$2, contains('Z'));
    expect(out[1].$2, contains('5'));
  });

  test('Análise: vitória de virada', () {
    final out = BattleAnalysis.of([ko(1, 0, 0), ko(3, 1, 1), ko(4, 1, 1), ko(6, 1, 1)], [3, 3], names, 0);
    expect([for (final o in out) o.$1], ['📈']);
    expect(out[0].$2, contains('4'));
  });
}
