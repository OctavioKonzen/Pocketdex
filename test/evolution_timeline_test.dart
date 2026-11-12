import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/models/evolution_chain_entry.dart';
import 'package:pocket_dex/utils/evolution_timeline.dart';

EvolutionChainEntry e(String from, String to, String trigger) =>
    EvolutionChainEntry(fromPokemonName: 'p$from', toPokemonName: 'p$to', fromPokemonId: from, toPokemonId: to, trigger: trigger);

void main() {
  test('Evolução: as condições (igual ao site)', () {
    expect(EvolutionTimeline.condition('(Level 16)').level, 16);
    expect(EvolutionTimeline.condition('(water stone)').item, 'water-stone');
    expect(EvolutionTimeline.condition('(water stone)').text, 'Water Stone');
    expect(EvolutionTimeline.condition('(trade)').icon, '🔄');
  });

  test('Evolução: as etapas, com galhos', () {
    final stages = EvolutionTimeline.stages([e('133', '134', '(water stone)'), e('133', '135', '(thunder stone)')]);
    expect([for (final s in stages) [for (final x in s) x.id]], [['133'], ['134', '135']]);
    final line = EvolutionTimeline.stages([e('1', '2', '(Level 16)'), e('2', '3', '(Level 32)')]);
    expect([for (final s in line) [for (final x in s) x.id]], [['1'], ['2'], ['3']]);
  });
}
