import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_simulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Android runtime executes pivot, status and field effects offline', () async {
    await BattleSimulator.load();
    final game = BattleSimulator.call('create', [{
      'teams': [
        [
          {'name': 'Scizor', 'set': {'species': 'Scizor', 'moves': ['uturn'], 'level': 50}},
          {'name': 'Pikachu', 'set': {'species': 'Pikachu', 'moves': ['electricterrain', 'nuzzle'], 'level': 50}},
        ],
        [{'name': 'Blissey', 'set': {'species': 'Blissey', 'moves': ['splash'], 'level': 50}}],
      ],
      'seed': [1, 2, 3, 4],
    }]);
    final handle = game['handle'] as int;
    try {
      final pivot = BattleSimulator.call('choose', [handle, [
        {'kind': 'move', 'index': 0, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''},
      ]]);
      expect(pivot['state']['sides'][0]['forceSwitch'], true);
      expect(pivot['state']['sides'][1]['wait'], true);
      final next = BattleSimulator.call('choose', [handle, [
        {'kind': 'switch', 'index': 1}, {'kind': 'wait'},
      ]]);
      expect(next['state']['sides'][0]['active'], 1);
      expect(next['state']['turn'], 2);
      final field = BattleSimulator.call('choose', [handle, [
        {'kind': 'move', 'index': 0, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''},
      ]]);
      expect((field['log'] as List).any((line) => '$line'.contains('Electric Terrain')), true);
      final status = BattleSimulator.call('choose', [handle, [
        {'kind': 'move', 'index': 1, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''},
      ]]);
      expect(status['state']['sides'][1]['team'][0]['status'], 'par');
    } finally { BattleSimulator.release(handle); }
  });
}
