import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_simulator.dart';
import 'package:pocket_dex/services/online_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ranking: Elo igual ao site, temporada e Pokémon repetido', () {
    expect(OnlineBattles.eloAfter(1000, 1000, true), 1016);
    expect(OnlineBattles.eloAfter(1000, 1000, false), 984);
    expect(OnlineBattles.eloAfter(1000, 1400, true), 1029);
    expect(OnlineBattles.eloAfter(1400, 1000, false), 1371);
    expect(OnlineBattles.eloAfter(1000, 5000, true) - 1000, lessThanOrEqualTo(40));
    expect(OnlineBattles.currentSeason(DateTime(2026, 10, 8)), '2026-10');
    expect(OnlineBattles.currentSeason(DateTime(2027, 1, 1)), '2027-01');
    expect(OnlineBattles.repeatedSpecies({'pokemon': [6, 9, 6]}), isTrue);
    expect(OnlineBattles.repeatedSpecies({'pokemon': [6, 9, null, null]}), isFalse);
  });

  test('Sleep Clause no motor do app (igual ao site)', () async {
    await BattleSimulator.load();
    List<String> play(List<String> rules) {
      final game = BattleSimulator.call('create', [{
        'teams': [
          [{'set': {'species': 'Breloom', 'moves': ['spore'], 'level': 50, 'ability': 'Technician'}}],
          [{'set': {'species': 'Snorlax', 'moves': ['splash'], 'level': 50}}, {'set': {'species': 'Chansey', 'moves': ['splash'], 'level': 50}}],
        ],
        'seed': [1, 2, 3, 4], 'rules': rules,
      }]);
      final handle = game['handle'] as int;
      try {
        BattleSimulator.call('choose', [handle, [{'kind': 'move', 'index': 0, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''}]]);
        final next = BattleSimulator.call('choose', [handle, [{'kind': 'move', 'index': 0, 'gimmick': ''}, {'kind': 'switch', 'index': 1}]]);
        return [for (final m in next['state']['sides'][1]['team'] as List) '${m['status']}'];
      } finally {
        BattleSimulator.release(handle);
      }
    }
    expect(play([]), ['slp', 'slp']);
    expect(play(['sleep']), ['slp', '']);
  });
}
