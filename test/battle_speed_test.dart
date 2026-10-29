// A velocidade da batalha: 2× corta as esperas pela metade, acelera as animações (timeDilation) só com a batalha
// aberta e fica guardada.
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_speed.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('2× corta as esperas, acelera as animações na batalha e fica guardada', () async {
    BattleSpeed.enter();
    await Future<void>.delayed(Duration.zero);
    expect(BattleSpeed.ms(1100), 1100);
    BattleSpeed.toggle();
    expect(BattleSpeed.ms(1100), 550);
    expect(timeDilation, 0.5);
    await Future<void>.delayed(Duration.zero);
    expect((await SharedPreferences.getInstance()).getInt('battleSpeed'), 2);
    // Saiu da batalha: o resto do app volta ao normal.
    BattleSpeed.leave();
    expect(timeDilation, 1.0);
    BattleSpeed.toggle();
    expect(BattleSpeed.ms(1100), 1100);
  });
}
