import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/utils/profanity.dart';

void main() {
  test('bloqueia palavrões, mesmo disfarçados (igual ao site)', () {
    for (final bad in ['Porra', 'P0RR4', 'poooorra', 'p o r r a', 'Filho da Puta', 'FdP', 'fuck you', 'Time do Caralho', 'Vai tnc', 'f.d.p']) {
      expect(isOffensive(bad), isTrue, reason: bad);
    }
  });
  test('deixa nomes normais', () {
    for (final ok in ['Ash Ketchum', 'Computador', 'Time Rolagem', 'Raposa', 'Mestre Pokémon', 'Team Rocket', 'Rapel', 'Pintura', 'Dragões']) {
      expect(isOffensive(ok), isFalse, reason: ok);
    }
  });
}
