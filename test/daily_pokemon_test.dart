import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/daily_pokemon.dart';

void main() {
  test('Pokémon do dia: mesmo dia, mesmo Pokémon; dias diferentes variam', () {
    expect(DailyPokemon.idFor('2026-09-30'), DailyPokemon.idFor('2026-09-30'));
    final week = {for (var d = 1; d <= 7; d++) DailyPokemon.idFor('2026-10-0$d')};
    expect(week.length, greaterThan(4));
    for (var d = 1; d <= 28; d++) {
      final id = DailyPokemon.idFor('2026-02-${d.toString().padLeft(2, '0')}');
      expect(id, inInclusiveRange(1, DailyPokemon.count));
    }
    // ignore: avoid_print
    print('2026-09-30 → ${DailyPokemon.idFor('2026-09-30')}, 2026-10-01 → ${DailyPokemon.idFor('2026-10-01')}');
  });
}
