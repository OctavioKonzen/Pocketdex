import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/gym_leaders.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/trainers.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Desafio dos Líderes: os times originais, evoluídos, no nível 50, entram na batalha (igual ao site)', () async {
    final regions = await GymLeaders.load();
    await Trainers.load();
    expect([for (final r in regions) r.region], ['Kanto', 'Johto', 'Hoenn', 'Sinnoh', 'Unova', 'Kalos', 'Alola', 'Galar', 'Paldea']);
    final hit = TurnBattleSetup.hitter(await DamageData.load());
    for (final leader in regions.expand((r) => r.leaders)) {
      expect(Trainers.byId(leader.trainer), isNotNull, reason: leader.id);
      final members = await leader.members(League.seededRandom(7));
      expect([for (final m in members) m.$1], leader.team, reason: leader.id);
      expect(members.every((m) => m.$2!['level'] == 50), isTrue, reason: leader.id);
      final team = await TurnBattleSetup.mons(members, (row) => '${row['name']}');
      expect(team.length, leader.team.length, reason: leader.id);
      final battle = TurnBattle(team, await TurnBattleSetup.mons(members, (row) => '${row['name']}'), League.seededRandom(1))..seed = 1;
      try {
        battle.start();
        battle.playTurn(hit, move: 0, gimmick: 'none');
        expect(battle.turn, greaterThanOrEqualTo(1), reason: leader.id);
      } finally {
        battle.dispose();
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}
