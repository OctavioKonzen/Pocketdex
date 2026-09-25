import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/achievements.dart';
import 'package:pocket_dex/services/battle.dart';
import 'package:pocket_dex/services/pix.dart';

void main() {
  test('dano igual ao do site (web-site/src/lib/league.test.js)', () {
    expect(Battle.statAt(78, 0), 153);
    expect(Battle.statAt(109, 3, 252), 161);
    expect(Battle.statAt(109, 3, 252, 50, 31, 'Modest'), 177);
    expect(Battle.statAt(109, 3, 252, 50, 31, 'Adamant'), 144);
    final chart = {
      'fire': {'double_damage_from': ['water'], 'half_damage_from': ['fire', 'grass'], 'no_damage_from': <String>[]},
      'grass': {'double_damage_from': ['fire'], 'half_damage_from': ['water', 'grass'], 'no_damage_from': <String>[]},
    };
    const attacker = BattleSide(types: ['fire'], stats: [78, 84, 78, 109, 85, 100], evs: {'spa': 252});
    const defender = BattleSide(types: ['grass'], stats: [80, 82, 83, 100, 100, 80]);
    DamageResult calc({BattleSide a = attacker, String weather = 'none', bool crit = false, bool screen = false}) =>
        Battle.damage(
          attacker: a,
          defender: defender,
          moveType: 'fire',
          physical: false,
          power: 90,
          typeData: chart,
          weather: weather,
          crit: crit,
          screen: screen,
        );
    final r = calc();
    expect([r.min, r.max, r.hp], [138, 164, 155]);
    expect(r.mult, 2);
    expect(r.stab, isTrue);
    expect(r.rolls, hasLength(16));
    expect(r.hits, 1);
    expect(r.chance, 0.375);
    expect(r.koText, '37,5% de chance de derrotar com 1 golpe.');
    expect(calc(crit: true).max, greaterThan(r.max));
    expect(calc(weather: 'rain').max, lessThan(r.max));
    expect(calc(screen: true).max, lessThan(r.max));
    expect(
      calc(a: const BattleSide(types: ['fire'], stats: [78, 84, 78, 109, 85, 100], evs: {'spa': 252}, tera: 'fire')).stabMult,
      2,
    );
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

  test('Pix igual ao exemplo do Banco Central (e ao site)', () {
    expect(
      Pix.code(key: '123e4567-e12b-12d1-a456-426655440000', name: 'Fulano de Tal', city: 'BRASILIA'),
      '00020126580014br.gov.bcb.pix0136123e4567-e12b-12d1-a456-4266554400005204000053039865802BR5913Fulano de Tal6008BRASILIA62070503***63041D3D',
    );
  });
}
