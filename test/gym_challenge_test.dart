import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/gym_challenge.dart';
import 'package:pocket_dex/services/gym_leaders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('jornada: insígnias liberam a Liga; Hall da Fama, sequências e música (igual ao site)', () async {
    final regions = await GymLeaders.load();
    Region byName(String name) => regions.firstWhere((r) => r.region == name);
    final kanto = byName('Kanto');
    var league = GymChallenge.empty();
    expect(GymChallenge.leagueOpen(league, kanto), isFalse);
    for (final gym in GymChallenge.regionGyms(kanto)) {
      league = GymChallenge.winBadge(league, regions, gym);
    }
    league = GymChallenge.winBadge(league, regions, GymChallenge.regionGyms(kanto).first);
    league = GymChallenge.winBadge(league, regions, GymChallenge.leagueOrder(kanto).first);
    expect(GymChallenge.badgesOf(league, kanto).length, 8);
    expect(GymChallenge.leagueOpen(league, kanto), isTrue);
    expect(GymChallenge.badgesNeeded(byName('Alola')), 4);
    expect(GymChallenge.badgesNeeded(byName('Unova')), 8);
    expect([for (final l in GymChallenge.leagueOrder(kanto)) l.name], ['Lorelei', 'Bruno', 'Agatha', 'Lance', 'Blue']);
    expect(GymChallenge.leagueOrder(byName('Unova')).last.name, 'Iris');
    expect([for (final l in GymChallenge.leagueOrder(byName('Alola'))) l.name], ['Kukui']);

    final hall = GymChallenge.addHallOfFame(GymChallenge.empty(), byName('Johto'), [6, 9], 'red', 5);
    expect(hall['hall'], [
      {'region': 'Johto', 'at': 5, 'team': [6, 9], 'trainer': 'red'}
    ]);
    var l = GymChallenge.streakResult(hall, 'tower', true);
    l = GymChallenge.streakResult(l, 'tower', true);
    l = GymChallenge.streakResult(l, 'tower', false);
    expect(l['tower'], {'best': 2, 'streak': 0});
    expect(GymChallenge.musicOf(null), 'battle_music');
    expect(GymChallenge.musicOf(GymChallenge.leagueOrder(kanto).last), 'champion_music');
    expect(GymChallenge.musicOf(GymChallenge.regionGyms(kanto).first), 'gym_music');
  });
}
