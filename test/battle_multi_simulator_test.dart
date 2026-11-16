import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_simulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Dupla e tripla executam todas as posições no motor Android', () async {
    await BattleSimulator.load();
    for (final count in [2, 3]) {
      final mode = count == 2 ? 'doubles' : 'triples';
      final game = BattleSimulator.call('create', [{
        'mode': mode, 'seed': [1,2,3,4],
        'controllers': [List.filled(count, 'alice'), List.filled(count, 'bob')],
        'teams': [for (var side=0;side<2;side++) [for (var i=0;i<count+1;i++) {'set': {'species': 'Mew', 'moves': ['tackle','recover','helpinghand'], 'level': 50}}]],
      }]);
      final handle = game['handle'] as int;
      try {
        expect((game['state']['sides'][0]['slots'] as List).length, count);
        for (var turn=0;turn<5;turn++) {
          final actions = [for (var side=0;side<2;side++) BattleSimulator.call('recommend',[handle,side])['actions']];
          final next = BattleSimulator.call('choose',[handle,actions]);
          expect(next['state']['mode'], mode);
        }
      } finally {BattleSimulator.release(handle);}
    }
  });
}
