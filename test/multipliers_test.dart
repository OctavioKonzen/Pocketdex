import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/turn_battle.dart';

// Igual ao site (web-site/src/lib/multipliers.test.js): mesmo atacante e mesmo
// alvo, mudando só os tipos, o dano segue os multiplicadores do jogo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('STAB 1.5x, 2x, 4x, 0.5x, 0.25x e imune', () async {
    final data = await DamageData.load();
    final hit = TurnBattleSetup.hitter(data);
    BattleMon mon(List<String> types) {
      final calc = CalcPokemon(data, 'Mew',
          baseStats: const {'hp': 80, 'atk': 100, 'def': 100, 'spa': 100, 'spd': 100, 'spe': 80},
          types: [for (final t in types) '${t[0].toUpperCase()}${t.substring(1)}'],
          weightkg: 4,
          level: 50,
          ability: 'No Ability',
          nature: 'Hardy');
      return BattleMon(151, 'Mew', 50, calc.maxHP(), 80, types, const [], calc: calc);
    }

    (int, double) max(BattleMon a, BattleMon d, String move) {
      final r = hit(a, d, move, false)!;
      return (r.rolls.first.last, r.eff);
    }

    final water = mon(['water']), normal = mon(['normal']);
    final base = max(normal, mon(['normal']), 'surf').$1;
    expect(max(water, mon(['normal']), 'surf').$1 / base, closeTo(1.5, 0.05));
    for (final (types, mult) in [
      (['fire'], 2.0),
      (['fire', 'rock'], 4.0),
      (['grass'], 0.5),
      (['grass', 'dragon'], 0.25),
    ]) {
      final r = max(normal, mon(types), 'surf');
      expect(r.$2, mult, reason: '$types');
      expect(r.$1 / base, closeTo(mult, 0.05), reason: '$types');
    }
    expect(max(water, mon(['fire', 'rock']), 'surf').$1 / base, closeTo(6, 0.1));
    final ghost = max(normal, mon(['ghost']), 'body-slam');
    expect(ghost.$2, 0);
    expect(ghost.$1, 0);
  });
}
