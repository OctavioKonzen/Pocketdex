import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/achievements.dart';
import 'package:pocket_dex/services/battle.dart';

void main() {
  test('dano igual ao do site (web-site/src/lib/league.test.js)', () {
    expect(Battle.statAt(78, 0), 153);
    expect(Battle.statAt(109, 3, 252), 161);
    final chart = {
      'fire': {'double_damage_from': ['water'], 'half_damage_from': ['fire', 'grass'], 'no_damage_from': <String>[]},
      'grass': {'double_damage_from': ['fire'], 'half_damage_from': ['water', 'grass'], 'no_damage_from': <String>[]},
    };
    final r = Battle.damage(
      attackerTypes: ['fire'],
      attackerStats: [78, 84, 78, 109, 85, 100],
      defenderTypes: ['grass'],
      defenderStats: [80, 82, 83, 100, 100, 80],
      moveType: 'fire',
      physical: false,
      power: 90,
      typeData: chart,
      attackEv: 252,
    );
    expect([r.min, r.max, r.hp], [138, 164, 155]);
    expect(r.mult, 2);
    expect(r.stab, isTrue);
    expect(r.hits, 1);
  });

  test('conquistas iguais às do site', () {
    final list = Achievements.of(
      stats: {'correct': 120, 'bestStreak': 12},
      rankedRecord: 150,
      favorites: const [],
      teams: const [],
    );
    expect(list.where((a) => a.unlocked).map((a) => a.id), ['first', 'trainer', 'streak', 'ranked']);
  });
}
