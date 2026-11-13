import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_simulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Native runtime preserves hidden abilities, Nature stats and recharge metadata', () async {
    await BattleSimulator.load();
    expect(BattleSimulator.call('ability', ['contrary'])['name'], 'Contrary');
    expect(BattleSimulator.call('nature', ['Adamant'])['plus'], 'atk');
    expect(BattleSimulator.call('nature', ['Adamant'])['minus'], 'spa');
    expect(BattleSimulator.call('move', ['recharge'])['category'], 'status');
    final game = BattleSimulator.call('create', [{
      'teams': [
        [{'set': {'species': 'Serperior', 'moves': ['leafstorm'], 'ability': 'Contrary', 'nature': 'Timid', 'level': 50}}],
        [{'set': {'species': 'Blissey', 'moves': ['splash'], 'level': 50}}],
      ],
      'seed': [1, 2, 3, 4],
    }]);
    final handle = game['handle'] as int;
    try {
      final next = BattleSimulator.call('choose', [handle, [
        {'kind': 'move', 'index': 0, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''},
      ]]);
      expect(next['state']['sides'][0]['team'][0]['boosts']['spa'], 2);
    } finally { BattleSimulator.release(handle); }
  });
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
  test('Outrage locks the next turn and the engine forces it', () async {
    await BattleSimulator.load();
    final game = BattleSimulator.call('create', [{
      'teams': [
        [{'set': {'species': 'Dragonite', 'moves': ['outrage', 'roost'], 'level': 50}}],
        [for (final s in ['Blissey', 'Chansey', 'Snorlax']) {'set': {'species': s, 'moves': ['softboiled'], 'level': 100, 'evs': {'hp': 252, 'def': 252}}}],
      ],
      'seed': [1, 2, 3, 4],
    }]);
    final handle = game['handle'] as int;
    try {
      final next = BattleSimulator.call('choose', [handle, [
        {'kind': 'move', 'index': 0, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''},
      ]]);
      expect(next['state']['sides'][0]['locked']['slug'], 'outrage');
      final after = BattleSimulator.call('choose', [handle, [
        {'kind': 'move', 'index': 1, 'gimmick': ''}, {'kind': 'move', 'index': 0, 'gimmick': ''},
      ]]);
      expect((after['log'] as List).any((line) => '$line'.contains('|Roost|')), false);
    } finally { BattleSimulator.release(handle); }
  });
}
