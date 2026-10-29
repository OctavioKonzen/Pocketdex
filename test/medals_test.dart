import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/medals.dart';

void main() {
  test('Medalhas: libera pelos marcos da conta (igual ao site)', () {
    List<String> on(Map league, [Map collection = const {}]) => [for (final (m, ok) in Medals.of(league, collection)) if (ok) m.id];
    expect(on({}), isEmpty);
    expect(
        on({
          'factory': {'shinies': [1], 'best': 30},
          'hall': [{'region': 'Kanto'}],
          'tower': {'best': 12},
        }),
        ['shiny1', 'floor25', 'champion', 'tower10']);
    expect(on({}, {'red': {'c': List.generate(151, (i) => i + 1)}}), ['kanto']);
  });
}
