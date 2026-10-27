import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/achievements.dart';
import 'package:pocket_dex/services/battle.dart';
import 'package:pocket_dex/services/pix.dart';

void main() {
  test('efetividade de tipos', () {
    final chart = {
      'fire': {'double_damage_from': ['water'], 'half_damage_from': ['fire', 'grass'], 'no_damage_from': <String>[]},
      'grass': {'double_damage_from': ['fire'], 'half_damage_from': ['water', 'grass'], 'no_damage_from': <String>[]},
    };
    expect(Battle.effectiveness('water', ['fire'], chart), 2);
    expect(Battle.effectiveness('fire', ['grass'], chart), 2);
    expect(Battle.effectiveness('grass', ['fire', 'grass'], chart), 0.25);
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
