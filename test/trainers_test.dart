import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/trainers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('treinador comum do lugar: nadador na água, esquiador na neve; um contra um só com quem está sozinho (igual ao site)', () async {
    await Trainers.load();
    for (var seed = 0; seed < 30; seed++) {
      expect(Trainers.biomeTrainers['water'], contains(Trainers.trainerClass(Trainers.generic(seed, 'water')!)));
      expect(Trainers.biomeTrainers['snow'], contains(Trainers.trainerClass(Trainers.generic(seed, 'snow')!)));
      expect(Trainers.isPair(Trainers.generic(seed, 'city')!), isFalse);
      expect(Trainers.isPair(Trainers.pair(seed)!), isTrue);
    }
    // Lugar sem lista (ou nenhum): qualquer treinador comum.
    expect(Trainers.generic(3, 'base-rocket'), isNotNull);
    expect(Trainers.generic(3), isNotNull);
  });
}
