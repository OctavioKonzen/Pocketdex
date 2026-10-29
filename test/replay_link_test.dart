import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/replay_link.dart';

void main() {
  test('replay por link: codifica e decodifica, igual ao site (web-site/src/lib/replayLink.test.js)', () {
    final record = {
      'id': 'x', 'seed': 42, 'ai': 'normal', 'foe': 'Brock', 'foeTrainer': 'brock',
      'mine': [{'id': 6, 'set': {'level': 50}}], 'theirs': [{'id': 95, 'set': null}],
      'actions': [{'move': 0, 'gimmick': 'none'}], 'result': 'win', 'turns': 3, 'at': 5, 'kos': {'0': 1},
    };
    final code = ReplayLink.encode(record);
    expect(RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(code), isTrue);
    final back = ReplayLink.decode(code)!;
    expect(back['id'], 'link');
    expect(back['foe'], 'Brock');
    expect(back.containsKey('kos'), isFalse);
    expect(ReplayLink.decode('estragado'), isNull);
    expect(ReplayLink.url(code), 'https://octaviokonzen.github.io/Pocketdex/#/batalha/replay?d=$code');
    // O código que o teste do site decodifica.
    expect(ReplayLink.encode({'seed': 1, 'mine': [{'id': 25}], 'theirs': [{'id': 1}], 'actions': []}), siteCode);
    expect(ReplayLink.decode(siteCode)!['mine'], [{'id': 25}]);
  });
}

// Gerado aqui; o teste do site decodifica o mesmo.
const siteCode = 'q1YqTk1NUbIy1FHKzcxLVbKKrlbKTFGyMjKtjdVRKslIzSwqhgsagsQSk0sy8_NAgrG1AA';
