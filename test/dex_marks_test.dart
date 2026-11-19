import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/dex_marks.dart';
import 'package:pocket_dex/services/factory_run.dart';

void main() {
  test('a corrida guarda os vistos (adversários) e os capturados (time e Pokédex da corrida) (igual ao site)', () {
    final factory = {
      'coins': 0,
      'run': {'starter': 1, 'dex': [1, 16], 'team': [{'id': 2}], 'encounter': {'foes': [{'id': 19}, {'id': 21}]}},
    };
    final out = FactoryRun.withSeen(factory);
    expect(out['seen'], [19, 21]);
    expect(out['caught'], [1, 2, 16]);
    expect(identical(FactoryRun.withSeen(out), out), isTrue);
  });

  test('capturado: Coleção e Pokelike; visto: os capturados e os vistos (igual ao site)', () {
    final collection = {'red': {'c': [25], 's': [133]}};
    final league = {'factory': {'owned': [4], 'shinies': [7], 'caught': [16], 'seen': [19]}};
    expect(DexMarks.caught(collection, league).toList()..sort(), [4, 7, 16, 25, 133]);
    expect(DexMarks.seen(collection, league).contains(19), isTrue);
    expect(DexMarks.caught(collection, league).contains(19), isFalse);
    expect(DexMarks.caught(null, null), isEmpty);
  });
}
