import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/utils/encounters.dart';
import 'package:pocket_dex/utils/ivs.dart';
import 'package:pocket_dex/utils/shiny.dart';

void main() {
  test('IVs: mesmas contas do site (web-site/src/lib/features.test.js)', () {
    expect(statValue(5, 102, 31, 252, 50, 'Jolly'), 169);
    expect(possibleIvs(5, 102, 169, 252, 50, 'Jolly'), [31]);
    expect(possibleIvs(0, 108, 183, 0, 50, 'Jolly'), [30, 31]);
    expect(possibleIvs(1, 130, 999, 0, 50, 'Jolly'), isEmpty);
  });

  test('shiny e métodos de encontro', () {
    expect(shinyChanceSoFar(0, 4096), 0);
    expect((shinyChanceSoFar(4096, 4096) * 100).round(), 63);
    expect(shinyMethod('nada').key, 'full');
    expect(encounterMethodLabel('walk'), 'Andando na grama');
    expect(encounterMethodLabel('new-method'), 'New method');
  });
}
