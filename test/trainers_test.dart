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

  test('treinador comum com nome e fala, sempre os mesmos para a mesma semente (igual ao site)', () async {
    await Trainers.load();
    final swimmer = Trainers.byId('sd-swimmerf')!;
    final p = Trainers.persona(swimmer, 123456);
    expect(p, Trainers.persona(swimmer, 123456));
    expect(p.name.startsWith('Swimmer '), isTrue);
    expect(Trainers.intros, contains(p.intro));
    final y = Trainers.persona(Trainers.byId('youngster')!, 987654321);
    expect(y.name, 'Youngster ${Trainers.namesM[(987654321 >> 3) % 20]}');
    expect(y.intro, Trainers.intros[(987654321 >> 7) % 8]);
    expect(y.beat, Trainers.beats[(987654321 >> 11) % 6]);
  });
}
