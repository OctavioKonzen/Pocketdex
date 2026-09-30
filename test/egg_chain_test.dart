import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/egg_chain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Charmander tem golpes de ovo e Dragon Dance tem pai direto', () async {
    final moves = await EggChains.eggMoves(4);
    expect(moves, contains('dragon-dance'));
    final chains = await EggChains.find(4, 'dragon-dance');
    expect(chains, isNotEmpty);
    // Todo primeiro pai aprende sozinho; os de depois recebem de ovo.
    for (final chain in chains) {
      expect(chain.first.method, isNot('egg'));
      for (final link in chain.skip(1)) {
        expect(link.method, 'egg');
      }
    }
  });

  test('todas as cadeias de todos os golpes de ovo do Riolu fazem sentido', () async {
    for (final move in await EggChains.eggMoves(447)) {
      for (final chain in await EggChains.find(447, move)) {
        expect(chain.first.method, isNot('egg'), reason: move);
        expect(chain.map((l) => l.id), isNot(contains(447)), reason: move);
      }
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
