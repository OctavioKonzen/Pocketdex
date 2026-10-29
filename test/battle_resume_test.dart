// A Battle Factory guarda as jogadas da batalha do andar: saindo no meio, a
// batalha é refeita (mesma semente, mesmas jogadas) e volta exatamente de
// onde parou (TurnBattle.replayActions).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_dex/screens/turn_battle_screen.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  testWidgets('saindo no meio, a batalha volta exatamente de onde parou', (tester) async {
    await tester.runAsync(() async {
      final data = await DamageData.load();
      final hit = TurnBattleSetup.hitter(data);
      Future<List<BattleMon>> team(List<int> ids) => TurnBattleSetup.mons([
            for (final id in ids) (id, <String, dynamic>{'moves': id == 6 ? ['flamethrower', 'air-slash', 'dragon-claw', 'roost'] : ['surf', 'ice-beam', 'earthquake', 'protect']}),
          ], battleMonName);
      Future<TurnBattle> make() async => TurnBattle(await team([6, 9, 25]), await team([94, 18, 65]), League.seededRandom(42))..seed = 42;

      // A batalha de verdade: alguns turnos, guardando as jogadas (como a corrida faz).
      final first = await make();
      final saved = <Map<String, dynamic>>[];
      first.onLogged = () => saved
        ..clear()
        ..addAll(first.actions);
      first.start();
      for (var turn = 0; turn < 3 && first.winner == null; turn++) {
        if (first.needSwitch) {
          first.replace([for (var i = 0; i < first.teams[0].length; i++) i].firstWhere((i) => first.teams[0][i].hp > 0));
        } else {
          first.playTurn(hit, move: turn % 2);
        }
      }
      expect(saved, isNotEmpty);

      // Voltando: outra batalha com a mesma semente, refeita com as jogadas guardadas.
      final again = await make();
      again.start();
      again.replayActions(saved, hit);
      String state(TurnBattle b) => [
            for (final t in b.teams) [for (final m in t) '${m.id}:${m.hp}:${m.moves.map((mv) => mv.pp).join(',')}'].join(' '),
            b.activeIndex.join(','),
            b.turn,
          ].join(' | ');
      expect(state(again), state(first));
      expect(again.actions.length, first.actions.length);
      first.dispose();
      again.dispose();
    });
  });
}
