// Histórico e replay no app: refazer a batalha com a mesma semente e as
// mesmas jogadas dá exatamente a mesma batalha (igual ao site, battleLog.test.js).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/battle_log.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o replay refaz a batalha igual (mesma semente, mesmas jogadas)', () async {
    final hit = TurnBattleSetup.hitter(await DamageData.load());
    final mine = [(25, null), (130, null), (143, null)];
    final theirs = [(6, null), (3, null), (9, null)];
    Future<TurnBattle> make(int seed) async {
      final a = await TurnBattleSetup.mons(mine, (row) => '${row['name']}');
      final b = await TurnBattleSetup.mons(theirs, (row) => '${row['name']}');
      return TurnBattle(a, b, League.seededRandom(seed))..seed = seed;
    }

    String show(List<BattleEvent> events) => [for (final e in events) '${e.t}:${e.side}:${e.value}:${e.key}'].join('|');
    final original = await make(4242), replayed = await make(4242);
    addTearDown(original.dispose);
    addTearDown(replayed.dispose);
    final log = [show(original.start())];
    for (var n = 0; n < 200 && original.winner == null; n++) {
      if (original.needSwitch) {
        final next = [for (var i = 0; i < original.teams[0].length; i++) i].firstWhere((i) => original.teams[0][i].hp > 0 && i != original.activeIndex[0]);
        log.add(show(original.replace(next)));
      } else {
        final usable = TurnBattle.usableMoves(original.active(0));
        log.add(show(original.playTurn(hit, move: usable.isEmpty ? -1 : usable[n % usable.length], gimmick: 'none')));
      }
    }
    expect(original.winner, isNotNull);
    original.members = (mine: BattleLog.toRecord(mine), theirs: BattleLog.toRecord(theirs));
    // Como fica na conta: JSON.
    final record = jsonDecode(jsonEncode(BattleLog.record(original, foeName: 'Brock', foeTrainer: 'brock'))) as Map<String, dynamic>;
    expect(BattleLog.canReplay(record), isTrue);
    expect(BattleLog.members(record['mine'] as List).map((m) => m.$1), [25, 130, 143]);
    final again = [show(replayed.start())];
    for (final a in (record['actions'] as List).cast<Map<String, dynamic>>()) {
      again.add(show(a['replace'] != null
          ? replayed.replace((a['replace'] as num).toInt())
          : replayed.playTurn(hit, move: (a['move'] as num?)?.toInt(), gimmick: a['gimmick'] as String?)));
    }
    expect(again, log);
    expect(replayed.winner, original.winner);
    expect([for (final t in replayed.teams) [for (final m in t) m.hp]], [for (final t in original.teams) [for (final m in t) m.hp]]);
  });

  test('estatísticas: vitórias, aproveitamento e o MVP', () {
    Map<String, dynamic> r(String result, Map<String, int> kos) => {
          'result': result,
          'mine': [{'id': 25}, {'id': 6}],
          'kos': kos,
        };
    final s = BattleLog.stats([r('win', {'0': 2}), r('loss', {'1': 1}), r('win', {'0': 1, '1': 1})]);
    expect((s.battles, s.wins, s.rate), (3, 2, 67));
    expect(s.mons.first, (id: 25, battles: 3, wins: 2, kos: 3));
  });
}
