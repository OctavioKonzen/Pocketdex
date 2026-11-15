import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_sounds.dart';
import 'package:pocket_dex/services/battle_speed.dart';

void main() {
  test('fanfarra da Mega/Dynamax: em 2x e 4x começa adiantada, o estouro cai no clarão (igual ao site)', () {
    for (final speed in BattleSpeed.steps) {
      final flash = Duration(milliseconds: (700 / speed).round()); // a espera de 700 ms na velocidade
      expect((BattleSounds.hitAt - BattleSounds.syncedStart(speed)).inMilliseconds, closeTo(flash.inMilliseconds, 1));
    }
    expect(BattleSounds.syncedStart(1), Duration.zero);
  });
}
