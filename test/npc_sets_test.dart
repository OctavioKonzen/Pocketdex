import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('normal NPC stats are random and legal; hard uses level 50 and max IVs', () async {
    final rng = Random(73);
    final normal = await TurnBattleSetup.randomTeam(rng.nextDouble);
    final hard = await TurnBattleSetup.randomTeam(rng.nextDouble, difficulty: 'hard');
    expect(normal.length, 6);
    expect(normal.map((m) => m.$1).toSet().length, 6);
    expect(normal.any((m) => (m.$2!['ivs'] as Map).values.any((v) => v != 31)), isTrue);
    for (final member in [...normal, ...hard]) {
      final set = member.$2!;
      expect(set['level'], 50);
      final evs = (set['evs'] as Map).values.cast<int>();
      expect(evs.every((v) => v >= 0 && v <= 252), isTrue);
      expect(evs.fold<int>(0, (a, b) => a + b), lessThanOrEqualTo(510));
      expect((set['moves'] as List).isNotEmpty, isTrue);
    }
    expect(hard.every((m) => (m.$2!['ivs'] as Map).values.every((v) => v == 31)), isTrue);
    expect(hard.where((m) => m.$2!['gimmick'] == 'mega').length, lessThanOrEqualTo(1));
    expect(hard.where((m) => m.$2!['gimmick'] == 'dmax').length, 1);
    expect(hard.where((m) => m.$2!['gimmick'] == 'z').length, 1);
    expect(hard.any((m) => m.$2!['gimmick'] == 'tera'), isTrue);
  });
}
