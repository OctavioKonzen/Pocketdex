import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o campo e o que o adversário já mostrou; dano estimado em % (igual ao site)', () async {
    final hit = TurnBattleSetup.hitter(await DamageData.load());
    Map<String, dynamic> set(List<String> moves, String item) => {'level': 50, 'moves': moves, 'item': item};
    final a = await TurnBattleSetup.mons([(227, set(['stealth-rock', 'roost'], 'leftovers')), (242, set(['soft-boiled'], 'leftovers'))], (row) => '${row['name']}');
    final b = await TurnBattleSetup.mons([(707, set(['reflect'], 'leftovers'))], (row) => '${row['name']}');
    final battle = TurnBattle(a, b, League.seededRandom(3))..seed = 3;
    addTearDown(battle.dispose);
    battle.start();
    expect(battle.monDetails(1)!.moves, isEmpty);
    expect(battle.monDetails(1)!.item, isNull);
    expect(battle.monDetails(0)!.item, 'Leftovers');
    battle.playTurn(hit, move: 0, gimmick: 'none');
    final [mine, theirs, _] = battle.fieldConditions();
    expect(theirs, contains('Stealth Rock'));
    expect(mine, isNot(contains('Stealth Rock')));
    expect(battle.monDetails(1)!.moves.length, 1);

    HitResult fake(BattleMon att, BattleMon def, String slug, bool crit, [int? power, String weather = '']) =>
        (rolls: slug == 'double' ? [[10, 12], [10, 12]] : [[30, 36]], eff: 1.0);
    final target = battle.active(1);
    final range = TurnBattle.damageRange(fake, battle.active(0), target, battle.active(0).moves.first);
    expect(range, isNull); // Stealth Rock é golpe de status.
    final tackle = BattleMove('tackle', 'Tackle', 'normal', 40, 100, 35, 35, 0);
    expect(TurnBattle.damageRange(fake, battle.active(0), target, tackle), (low: 30 * 100 ~/ target.maxHp, high: 36 * 100 ~/ target.maxHp));
  });
}
