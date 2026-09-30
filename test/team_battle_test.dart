import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/team_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fogo ganha de planta, água ganha de fogo', () async {
    final r = await TeamBattle.run([(6, null), (9, null)], [(3, null), (6, null)]);
    expect(r[0][0]!.result, 1, reason: 'Charizard x Venusaur');
    expect(r[1][1]!.result, 1, reason: 'Blastoise x Charizard');
    expect(r[0][0]!.mine.hits, lessThan(r[0][0]!.theirs.hits));
  });

  test('usa os golpes do set', () async {
    final set = {
      'level': 50,
      'nature': 'Timid',
      'moves': ['flamethrower', '', '', ''],
      'evs': {'spa': 252, 'spe': 252},
    };
    final r = await TeamBattle.run([(6, set)], [(3, null)]);
    expect(r[0][0]!.mine.move, 'Flamethrower');
  });

  test('quem vence o Charizard: água e pedra aparecem, planta não', () async {
    final watch = Stopwatch()..start();
    final list = await TeamBattle.counters(6);
    final ids = [for (final (id, _) in list) id];
    // ignore: avoid_print
    print('counters do Charizard: ${ids.length} em ${watch.elapsedMilliseconds} ms; top: ${ids.take(8).toList()}');
    expect(ids, isNotEmpty);
    expect(ids.contains(3), isFalse, reason: 'Venusaur não ganha do Charizard');
    expect(ids.take(40).any((id) => [9, 76, 248, 130, 134, 142].contains(id)), isTrue);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
