import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_simulator.dart';

dynamic canonical(dynamic value) {
  if (value is List) return value.map(canonical).toList();
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return {for (final key in keys) key: canonical(value[key])};
  }
  return value;
}

Map<String, dynamic> comparable(Map state) => {
  for (final key in ['turn', 'winner', 'weather', 'terrain']) key: state[key],
  'sides': [for (final side in state['sides']) {
    for (final key in ['active', 'forceSwitch', 'wait']) key: side[key],
    'team': [for (final mon in side['team']) {
      for (final key in ['hp', 'maxHp', 'status', 'boosts', 'species', 'types', 'ability', 'item', 'tera', 'dmax']) key: mon[key],
      'moves': [for (final move in mon['moves']) {
        for (final key in ['slug', 'pp', 'maxPp']) key: move[key],
        'disabled': move['disabled'] == true,
      }],
    }],
  }],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('All 919 move records match standalone reference in the native runtime', () async {
    await BattleSimulator.load();
    final fixtures = jsonDecode(File('test/fixtures/battle_move_reference.json').readAsStringSync()) as List;
    expect(fixtures.length, 919);
    for (final fixture in fixtures) {
      final game = BattleSimulator.call('create', [fixture['input']]);
      final handle = game['handle'] as int;
      try {
        for (final step in fixture['steps']) {
          final next = BattleSimulator.call('choose', [handle, step['actions']]);
          expect(jsonEncode(canonical(comparable(next['state'] as Map))), step['expected'], reason: fixture['slug']);
        }
      } finally { BattleSimulator.release(handle); }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
