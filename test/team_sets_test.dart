import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/team_sets.dart';
import 'package:pocket_dex/services/team_share.dart';

void main() {
  final garchomp = {
    ...newSet('rough-skin'),
    'nickname': 'Chompy',
    'gender': 'M',
    'shiny': true,
    'item': 'choice-scarf',
    'nature': 'Jolly',
    'tera': 'steel',
    'level': 100,
    'moves': ['earthquake', 'outrage', 'u-turn', 'stone-edge'],
    'evs': {'hp': 0, 'atk': 252, 'def': 0, 'spa': 0, 'spd': 4, 'spe': 252},
    'ivs': {'hp': 31, 'atk': 31, 'def': 31, 'spa': 0, 'spd': 31, 'spe': 31},
  };
  final pokemon = <int?>[445, 6, null, null, null, null];
  final sets = <Map<String, dynamic>?>[garchomp, newSet('blaze'), null, null, null, null];

  test('código leva todos os dados (igual ao site)', () {
    final back = TeamShare.decode(TeamShare.encode(name: 'Areia', color: '#FF5252', pokemon: pokemon, sets: sets))!;
    expect(back.pokemon, pokemon);
    expect(back.sets[0], normalizeSet(garchomp));
    expect(back.sets[2], isNull);
  });

  test('texto de simulador ida e volta', () {
    final text = TeamShare.toShowdown('Areia', pokemon, {445: 'garchomp', 6: 'charizard'}, sets);
    expect(text, contains('Chompy (Garchomp) (M) @ Choice Scarf'));
    expect(text, contains('EVs: 252 Atk / 4 SpD / 252 Spe'));
    expect(text, contains('Jolly Nature'));
    expect(text, contains('IVs: 0 SpA'));
    expect(text, contains('- U-turn'));
    final back = TeamShare.fromShowdown(
      text,
      [
        {'id': 445, 'name': 'garchomp', 'is_default': true},
        {'id': 6, 'name': 'charizard', 'is_default': true},
      ],
      moves: lookupOf(['earthquake', 'outrage', 'u-turn', 'stone-edge']),
      abilities: lookupOf(['rough-skin', 'blaze']),
      items: lookupOf(['choice-scarf']),
    )!;
    expect(back.pokemon.take(2), [445, 6]);
    expect(back.sets[0], normalizeSet(garchomp));
  });

  test('status final igual ao dos jogos', () {
    final base = [108, 130, 95, 80, 85, 102];
    final set = normalizeSet(garchomp)!;
    expect(statValue(base, 1, set), 359);
    expect(statValue(base, 5, set), 333);
    expect(statValue(base, 0, set), 357);
  });

  test('set inválido vira válido', () {
    final s = normalizeSet({'level': 500, 'evs': {'atk': 999}, 'nature': 'X', 'moves': ['a']})!;
    expect(s['level'], 100);
    expect(s['evs']['atk'], 252);
    expect(s['nature'], 'Hardy');
    expect(s['moves'], ['a', '', '', '']);
  });
}
