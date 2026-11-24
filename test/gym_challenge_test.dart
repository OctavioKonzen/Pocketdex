import 'dart:io';

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
    // Sem líder: o tema da região do primeiro Pokémon do adversário (formas: sorteada pela semente).
    expect(GymChallenge.musicOf(null, foe: 25), 'map_kanto');
    expect(GymChallenge.musicOf(null, foe: 448), 'map_sinnoh');
    expect(GymChallenge.musicOf(null, foe: 1000), 'map_paldea');
    expect(GymChallenge.musicOf(null, foe: 10034, seed: 7), GymChallenge.musicOf(null, foe: 10034, seed: 7));
    expect(GymChallenge.musicOf(null, foe: 10034, seed: 7), startsWith('map_'));
    // O campeão, por enquanto, com o tema da região (os temas de campeão estão sendo refeitos).
    expect(GymChallenge.musicOf(GymChallenge.leagueOrder(kanto).last), 'champion_blue');
    // O Blue como rival tem o tema dele (o "normal"); rival sem tema: o da região.
    expect(GymChallenge.musicFor('Blue', 'rival', 'Kanto'), 'rival_blue');
    expect(GymChallenge.musicFor('Silver', 'rival', 'Johto'), 'rival_silver');
    expect(GymChallenge.musicFor('Barry', 'rival', 'Sinnoh'), 'rival_barry');
    expect(GymChallenge.musicFor('Cheren', 'rival', 'Unova'), 'rival_cheren');
    expect(GymChallenge.musicFor('Hugh', 'rival', 'Unova'), 'rival_hugh');
    expect(GymChallenge.musicFor('N', 'rival', 'Unova'), 'rival_n');
    expect(GymChallenge.musicFor('Benga', 'rival', 'Unova'), 'rival_benga');
    expect(GymChallenge.musicFor('Ninguém', 'rival', 'Unova'), 'map_unova'); // sem tema próprio: o da região
    for (final (name, track) in [('Serena', 'serena-calem'), ('Calem', 'serena-calem'), ('Shauna', 'shauna'), ('Tierno', 'tierno'), ('Trevor', 'trevor')]) {
      expect(GymChallenge.musicFor(name, 'rival', 'Kalos'), 'rival_$track');
    }
    expect(GymChallenge.musicFor('Hau', 'rival', 'Alola'), 'rival_hau');
    expect(GymChallenge.musicFor('Gladion', 'rival', 'Alola'), 'rival_gladion');
    for (final name in ['Hop', 'Bede', 'Marnie']) {
      expect(GymChallenge.musicFor(name, 'rival', 'Galar'), 'rival_${name.toLowerCase()}');
    }
    expect(GymChallenge.musicFor('Nemona', 'rival', 'Paldea'), 'rival_nemona');
    expect(GymChallenge.musicFor('Arven', 'rival', 'Paldea'), 'rival_arven');
    // Os especiais (Red, Anabel, Lillie...): o tema da região.
    expect(GymChallenge.musicFor('Anabel', 'rival', 'Alola'), 'rival_anabel');
    // Vilões: o chefe com o tema dele, os comandantes com o da equipe, N com o dele; sem tema: a região.
    expect(GymChallenge.musicFor('Giovanni', 'villain', 'Kanto'), 'villain_giovanni');
    expect(GymChallenge.musicFor('Archer', 'villain', 'Johto'), 'villain_team_rocket');
    expect(GymChallenge.musicFor('Executiva', 'villain', 'Johto'), 'villain_team_rocket');
    expect(GymChallenge.musicFor('N', 'villain', 'Unova'), 'rival_n');
    expect(GymChallenge.musicFor('Maxie', 'villain', 'Hoenn'), 'villain_maxie');
    expect(GymChallenge.musicFor('Tabitha', 'villain', 'Hoenn'), 'villain_team_magma');
    expect(GymChallenge.musicFor('Archie', 'villain', 'Hoenn'), 'villain_archie');
    expect(GymChallenge.musicFor('Shelly', 'villain', 'Hoenn'), 'villain_team_aqua');
    expect(GymChallenge.musicFor('Cyrus', 'villain', 'Sinnoh'), 'villain_cyrus');
    expect(GymChallenge.musicFor('Mars', 'villain', 'Sinnoh'), 'villain_team_galactic');
    expect(GymChallenge.musicFor('Zinzolin', 'villain', 'Unova'), 'villain_team_plasma');
    expect(GymChallenge.musicFor('Colress', 'villain', 'Unova'), 'villain_colress');
    expect(GymChallenge.musicFor('Lysandre', 'villain', 'Kalos'), 'villain_lysandre');
    expect(GymChallenge.musicFor('Bryony', 'villain', 'Kalos'), 'villain_team_flare');
    expect(GymChallenge.musicFor('Plumeria', 'villain', 'Alola'), 'villain_team_skull');
    expect(GymChallenge.musicFor('Guzma', 'villain', 'Alola'), 'villain_guzma');
    expect(GymChallenge.musicFor('Faba', 'villain', 'Alola'), 'villain_team_aether');
    expect(GymChallenge.musicFor('Lusamine', 'villain', 'Alola'), 'villain_lusamine');
    expect(GymChallenge.musicFor('Dulse', 'villain', 'Alola'), 'villain_team_ultra');
    expect(GymChallenge.musicFor('Giacomo', 'villain', 'Paldea'), 'villain_giacomo');
    expect(GymChallenge.musicFor('Ortega', 'villain', 'Paldea'), 'villain_ortega');
    expect(GymChallenge.musicFor('Mela', 'villain', 'Paldea'), 'villain_team_star');
    expect(GymChallenge.musicFor('Ghetsis', 'villain', 'Unova'), 'villain_ghetsis');
    expect(GymChallenge.musicFor('Penny', 'villain', 'Paldea'), 'villain_penny');
    expect(GymChallenge.musicFor('Rose', 'villain', 'Galar'), 'villain_rose');
    expect(GymChallenge.musicFor('Hau', 'champion', 'Alola'), 'rival_hau');
    expect(GymChallenge.musicFor('Jessie e James', 'rival', 'Kanto'), 'villain_jessie-e-james');
    expect(GymChallenge.musicFor('Equipe Yell', 'villain', 'Galar'), 'villain_team_yell');
    expect(GymChallenge.musicFor('Sordward e Shielbert', 'rival', 'Galar'), 'rival_sordward-e-shielbert');
    expect(GymChallenge.musicFor('Oleana', 'villain', 'Galar'), 'villain_team_macro');
    // Campeão enfrentado fora da Liga (Cynthia em Unova): o tema dele; o Red: o tema dele.
    expect(GymChallenge.musicFor('Cynthia', 'rival', 'Unova'), 'champion_cynthia');
    expect(GymChallenge.musicFor('Red', 'rival', 'Johto'), 'rival_red');
    expect(GymChallenge.musicFor('Lillie', 'rival', 'Alola'), 'rival_lillie');
    expect(GymChallenge.musicFor('AZ', 'rival', 'Kalos'), 'rival_az');
    expect(GymChallenge.musicFor('Anabel', 'rival', 'Alola'), 'rival_anabel');
    expect(GymChallenge.musicFor('Dexio', 'rival', 'Alola'), 'rival_dexio');
    expect(GymChallenge.musicFor('Sina', 'rival', 'Alola'), 'rival_sina');
    expect(GymChallenge.musicFor('Benga', 'rival', 'Unova'), 'rival_benga');
    expect(GymChallenge.musicFor('Eusine', 'rival', 'Johto'), 'rival_eusine');
    expect(GymChallenge.musicFor('Ryuki', 'rival', 'Alola'), 'rival_ryuki');
    for (final name in ['Brendan', 'May', 'Brendan/May']) {
      expect(GymChallenge.musicFor(name, 'rival', 'Hoenn'), 'rival_brendan-may');
    }
    expect(GymChallenge.musicFor('Wally', 'rival', 'Hoenn'), 'rival_wally');
    // Líder de Kanto: o tema de ginásio de Kanto; a Elite dos Quatro, o dela.
    expect(GymChallenge.musicOf(GymChallenge.regionGyms(kanto).first), 'gym_kanto');
    expect(GymChallenge.musicFor('Lorelei', 'elite', 'Kanto'), 'elite_kanto');
    expect(GymChallenge.musicFor('Hala', 'kahuna', 'Alola'), 'gym_alola');
    expect(GymChallenge.musicFor('Raihan', 'gym', 'Galar'), 'gym_galar');
    // Todo líder tem a música no banco (igual ao site).
    for (final leader in regions.expand((r) => r.leaders)) {
      expect(File('assets/database/sounds/music/${GymChallenge.musicOf(leader)}.ogg').existsSync(), isTrue, reason: leader.id);
    }
  });
}
