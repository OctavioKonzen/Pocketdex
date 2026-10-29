import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/screens/tools/speed_tiers_screen.dart';

void main() {
  test('Speed como no jogo', () {
    // Garchomp (base 102): nível 50, 31 IV, 252 EV, Jolly = 169; Scarf = 253.
    expect(speedStat(102, 50, 31, 252, 1.1), 169);
    expect(speedStat(102, 50, 31, 252, 1.1, scarf: true), 253);
    // Nível 100 neutro 252 EV: 303; mínimo (0 IV, Nature contra): 188.
    expect(speedStat(102, 100, 31, 252, 1.0), 303);
    expect(speedStat(102, 100, 0, 0, 0.9), 188);
    // Tailwind dobra.
    expect(speedStat(102, 50, 31, 252, 1.0, tailwind: true), 308);
  });
}
