import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/factory_run.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/turn_battle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final data = FactoryData.parse(jsonDecode(File('assets/database/factory.json').readAsStringSync()) as Map<String, dynamic>);
  final moves = {
    for (final m in jsonDecode(File('assets/database/moves.json').readAsStringSync()) as List) '${m['name']}': Map<String, dynamic>.from(m as Map)
  };
  final pokemon = {for (final p in jsonDecode(File('assets/database/pokemon.json').readAsStringSync()) as List) p['id'] as int: p as Map};

  test('o sorteio é o mesmo do site (mulberry32)', () {
    final (a, s1) = FactoryRun.nextRandom(1);
    expect(a, closeTo(0.6270739405881613, 1e-12));
    expect(FactoryRun.nextRandom(s1).$1, closeTo(0.002735721180215478, 1e-12));
  });

  test('começa com um inicial grátis no nível 5, 5 Poké Balls e a Bolsa; a mesma semente dá a mesma corrida', () {
    final f = FactoryRun.empty();
    expect(FactoryRun.startRun(f, data, 150, 1), isNull);
    final run = FactoryRun.startRun(f, data, 1, 42)!;
    expect(run['team'], hasLength(1));
    expect(run['team'][0]['level'], 5);
    expect(run['bag'], FactoryRun.startBag);
    expect(run['bag']['poke-ball'], 5);
    expect(jsonEncode(FactoryRun.startRun(f, data, 1, 42)), jsonEncode(run));
    // O mesmo que o site sorteia (web-site/src/lib/factoryRun.test.js): a corrida continua de um no outro.
    expect(run['seed'], 3599190471);
    expect(run['team'][0]['ivs'], {'hp': 25, 'atk': 22, 'def': 29, 'spa': 26, 'spd': 17, 'spe': 23});
    expect(run['team'][0]['nature'], 'Docile');
    expect(run['boss'], {'region': 11, 'step': 0});
    expect(run['encounter'], isNull);
    expect(run['route'], {'floor': 1, 'biome': 'grass', 'options': [{'kind': 'trainer'}]});
    expect(FactoryRun.chooseNode(run, data, 0)['encounter'], {
      'kind': 'trainer', 'foes': [{'id': 868, 'level': 2, 'iv': 0, 'ev': 3}, {'id': 280, 'level': 2, 'iv': 0, 'ev': 3}], 'trainerSeed': 500729487, 'scene': 'grass',
    });
  });

  test('40 andares iguais ao site (test/fixtures/factory_trace.json): mapa, chefes, captura, carta e loja', () {
    final expected = jsonDecode(File('test/fixtures/factory_trace.json').readAsStringSync()) as List;
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 7, 2024)!;
    final out = [];
    // 1.0 no Dart é 1 no site.
    Object? n(Object? v) => v is double && v == v.roundToDouble() ? v.toInt() : v;
    for (var i = 0; i < 40; i++) {
      final options = [for (final o in FactoryRun.routeOf(run)!['options'] as List) Map<String, dynamic>.from(o as Map)];
      run = FactoryRun.chooseNode(run, data, i % options.length);
      final encounter = run['encounter'] == null ? null : Map<String, dynamic>.from(run['encounter'] as Map);
      final foes = FactoryRun.foesOf(run);
      if (encounter != null) {
        final team = FactoryRun.teamOf(run);
        run = FactoryRun.winFloor(run, data, hp: [for (var k = 0; k < team.length; k++) k == 0 ? 0.7 : 1.0], captured: i % 3 == 0);
      }
      if (FactoryRun.pendingOf(run)!['capture'] != null) run = FactoryRun.capture(run, FactoryRun.teamOf(run).length >= FactoryRun.maxTeam ? 1 : null);
      if (FactoryRun.pendingOf(run)!['cards'] != null) run = FactoryRun.takeCard(run, '${(FactoryRun.pendingOf(run)!['cards'] as List).first}', data);
      run = {...run, 'money': (run['money'] as int) + 500};
      for (final id in (FactoryRun.pendingOf(run)!['shop'] as List?) ?? const []) {
        run = FactoryRun.buyItem(run, '$id', 0, data) ?? run;
      }
      final pending = FactoryRun.pendingOf(run)!;
      run = FactoryRun.nextFloor(run, data);
      out.add([
        run['seed'], run['floor'], run['money'], run['bag'], run['boss']['region'], run['boss']['step'],
        [for (final m in FactoryRun.teamOf(run)) [m['id'], m['level'], m['exp'], m['item'] ?? '', (m['extras'] as List).length, n(m['hp'])]],
        [for (final o in options) '${o['kind']}${o['biome'] != null ? ':${o['biome']}' : ''}'],
        encounter?['kind'] ?? '',
        [for (final f in foes) [f['id'], f['level'], f['shiny'] == true ? 1 : 0]],
        pending['event'], pending['reward'], run['stash'],
      ]);
    }
    for (var i = 0; i < expected.length; i++) {
      expect(jsonEncode(out[i]), jsonEncode(expected[i]), reason: 'andar ${i + 1}');
    }
  });

  test('venceu: XP só para quem está de pé; HP continua; o capturado na batalha entra no time; shiny libera o inicial shiny', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 4, 3)!;
    run = {
      ...run,
      'team': [...FactoryRun.teamOf(run), {...FactoryRun.teamOf(run).first, 'id': 7}],
      'encounter': {'kind': 'wild', 'foes': [{'id': 19, 'level': 5, 'iv': 0, 'ev': 0, 'shiny': true}]},
    };
    final after = FactoryRun.winFloor(run, data, hp: [0.4, 0], captured: true);
    expect(after['floor'], 2);
    expect(FactoryRun.pendingOf(FactoryRun.winFloor(run, data))!['capture'], isNull);
    final team = FactoryRun.teamOf(after);
    expect(team[0]['exp'], FactoryRun.expAt(5) + FactoryRun.expFor(data.species[19]![0] as int, 5, 5));
    expect(team[1]['exp'], FactoryRun.expAt(5));
    final caught = FactoryRun.capture(after);
    expect(caught['team'][2]['shiny'], true);
    expect(FactoryRun.teamOf(FactoryRun.skipCapture(after)), hasLength(2));
    final f = FactoryRun.empty();
    expect(FactoryRun.unlockShiny(f, data, {'id': 19, 'shiny': true}), f);
    expect(FactoryRun.unlockShiny(f, data, {'id': 4, 'shiny': true})['shinies'], [4]);
    expect(FactoryRun.buyShiny({...f, 'coins': 1000000}, data, 1), isNull);
    expect(FactoryRun.buyShiny({...f, 'owned': [1], 'coins': 1000000}, data, 1)!['shinies'], [1]);
    expect(FactoryRun.buyShiny({...f, 'coins': 100}, data, 1), isNull);
  });

  test('itens sem limite: principal e extras (porcentagem); Bolsa fora da batalha', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 1, 5)!;
    run = {...run, 'money': 1000000000, 'pending': {'shop': ['leftovers', 'choice-band', 'protein', 'super-potion', 'poke-ball']}};
    run = FactoryRun.buyItem(run, 'leftovers', 0, data)!;
    run = FactoryRun.buyItem(run, 'choice-band', 0, data)!;
    run = FactoryRun.buyItem(run, 'poke-ball', 0, data)!;
    expect(run['bag']['poke-ball'], 6);
    expect(run['team'][0]['item'], 'leftovers');
    expect(FactoryRun.memberOf(run, FactoryRun.teamOf(run)[0], ['tackle']).$2['boost']['atk'], 0.05);
    final swapped = FactoryRun.setMainItem(run, 0, 0);
    expect([swapped['team'][0]['item'], swapped['team'][0]['extras']], ['choice-band', ['leftovers']]);
    for (var i = 0; i < 20; i++) {
      run = FactoryRun.buyItem(run, 'protein', 0, data)!;
    }
    final set = FactoryRun.memberOf(run, FactoryRun.teamOf(run)[0], ['tackle']).$2;
    expect(set['evs']['atk'], 252);
    expect(set['bonus']['atk'], FactoryRun.overflowPoints(run['team'][0]['ivs'] as Map, run['team'][0]['evs'] as Map, 5)['atk']);
    final hurt = {...run, 'team': [{...FactoryRun.teamOf(run)[0], 'hp': 0.3}]};
    expect(FactoryRun.applyBagItem(hurt, 'super-potion', 0)!['team'][0]['hp'], 0.8);
    expect(FactoryRun.applyBagItem(hurt, 'revive', 0), isNull);
    expect(FactoryRun.teamDown({...run, 'team': [{'hp': 0}]}), isTrue);
  });

  test('perdeu: moedas pela pontuação; moedas compram Pokémon pela força', () {
    final run = {...FactoryRun.startRun(FactoryRun.empty(), data, 1, 5)!, 'floor': 21, 'defeated': 30, 'bosses': 2};
    final f = FactoryRun.endRun({...FactoryRun.empty(), 'best': 7}, run);
    expect([f['coins'], f['best'], f['run']], [210, 20, null]);
    // Primeiro um inicial grátis (de qualquer geração); os outros se compram (1 em 4096 de vir shiny).
    expect(FactoryRun.buyPokemon({...f, 'coins': 10000}, data, 150), isNull);
    final picked = FactoryRun.claimStarter(f, data, 906);
    expect(FactoryRun.startersOf(picked, data), [906]);
    final bought = FactoryRun.buyPokemon({...picked, 'coins': 10000}, data, 150)!;
    expect(bought['owned'], [906, 150]);
    expect(bought['shinies'], isEmpty);
    expect(FactoryRun.buyPokemon({...picked, 'coins': 10000}, data, 150, 0)!['shinies'], [150]);
    expect(FactoryRun.startersOf(bought, data), contains(150));
  });

  test('chefe sem treinador (Mega deixa a Mega Pedra), loja nova, golpes, itens guardados e mecânicas', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 4, 3)!;
    run = {...run, 'floor': 25, 'encounter': {'kind': 'wildboss', 'foes': [{'id': 6, 'level': 20, 'iv': 31, 'ev': 50, 'item': 'charizardite-x', 'gimmick': 'mega', 'title': 'mega'}]}};
    var after = FactoryRun.winFloor(run, data, captured: true);
    expect(after['stash'], ['charizardite-x']);
    expect(FactoryRun.pendingOf(after)!['capture']['id'], 6);
    expect(FactoryRun.foeMember(FactoryRun.foesOf(run).first, ['tackle']).$2['gimmick'], 'mega');
    after = {...after, 'money': 1000000, 'team': [...FactoryRun.teamOf(after), {...FactoryRun.teamOf(after).first, 'id': 133}, {...FactoryRun.teamOf(after).first, 'id': 6}],
      'pending': {'shop': ['tm:thunderbolt', 'move-tutor', 'evo:thunder-stone', 'dynamax-band', 'tera-orb']}};
    expect(FactoryRun.buyItem(after, 'evo:thunder-stone', 0, data), isNull);
    after = FactoryRun.buyItem(after, 'evo:thunder-stone', 1, data)!;
    expect(after['team'][1]['id'], 135);
    after = FactoryRun.buyItem(after, 'tm:thunderbolt', 0, data)!;
    final taught = FactoryRun.teachMove(after, 1, 'thunderbolt', ['tackle', 'growl', 'quick-attack', 'thunder-shock'], 3, 'tm')!;
    expect(taught['team'][1]['moves'], ['tackle', 'growl', 'quick-attack', 'thunderbolt']);
    expect(FactoryRun.memberOf(taught, FactoryRun.teamOf(taught)[1], ['tackle']).$2['moves'], ['tackle', 'growl', 'quick-attack', 'thunderbolt']);
    after = FactoryRun.buyItem(FactoryRun.buyItem(after, 'dynamax-band', 0, data)!, 'tera-orb', 0, data)!;
    expect(FactoryRun.buyItem(after, 'dynamax-band', 0, data), isNull);
    after = FactoryRun.equipFromStash(after, 0, 2);
    expect(FactoryRun.gimmicksOf(data, after, FactoryRun.teamOf(after)[2]), ['mega', 'dmax', 'tera']);
    expect(FactoryRun.memberOf(after, FactoryRun.teamOf(after)[2], ['ember'], data).$2['gimmick'], 'mega');
    for (final region in {for (final b in data.bosses) '${b['region']}'}) {
      expect(FactoryRun.storyLine(data, region, 'intro').length, greaterThan(20));
    }
  });

  test('golpes pelo nível, iguais ao site; golpes fortes esperam um nível compatível', () {
    expect(FactoryRun.movesAt(pokemon[4]!['moves'] as List, 5, ['fire'], moves), ['scratch', 'growl']);
    final golem = FactoryRun.movesAt(pokemon[76]!['moves'] as List, 9, ['rock', 'ground'], moves);
    expect(golem, isNot(contains('explosion')));
    expect(golem, isNot(contains('rollout')));
  });

  test('na batalha: passa do nível 100, os bônus somam, o HP continua e o selvagem fica sem bolsa', () async {
    final start = FactoryRun.startRun(FactoryRun.empty(), data, 4, 7)!;
    final strong = {...FactoryRun.teamOf(start)[0], 'level': 150, 'extras': ['choice-scarf', 'choice-scarf'], 'hp': 0.5};
    final run = {...start, 'team': [strong, {...strong, 'hp': 0}], 'encounter': {'kind': 'wild', 'foes': [{'id': 19, 'level': 5, 'iv': 0, 'ev': 0}]}};
    final moveList = FactoryRun.movesAt(pokemon[4]!['moves'] as List, 150, ['fire'], moves);
    final plain = {...strong, 'extras': <String>[], 'hp': 1};
    final mons = await TurnBattleSetup.mons([
      for (final i in FactoryRun.battleOrder(run)) FactoryRun.memberOf(run, FactoryRun.teamOf(run)[i], moveList),
      FactoryRun.memberOf(run, plain, moveList),
    ], (row) => '${row['name']}');
    expect(mons[0].level, 150);
    final foes = await TurnBattleSetup.mons([for (final f in FactoryRun.foesOf(run)) FactoryRun.foeMember(f, const ['tackle'])], (row) => '${row['name']}');
    final battle = TurnBattle([mons[0], mons[1]], foes, League.seededRandom(1), startBags: FactoryRun.bagsFor(run), healPct: true);
    final reference = TurnBattle([mons[2]], foes, League.seededRandom(1));
    expect(battle.bags[1].values.every((n) => n == 0), isTrue);
    expect(battle.bags[0]['potion'], 4);
    // No motor: +10% de Velocidade (2 extras), metade do HP e o segundo continua desmaiado.
    expect(battle.teams[0][0].spe, (reference.teams[0][0].spe * 1.1).floor());
    expect(battle.teams[0][0].hp, (battle.teams[0][0].maxHp / 2).ceil());
    expect(battle.teams[0][1].hp, 0);
    battle.dispose();
    reference.dispose();
  });

  test('mapa: cidades, caminhos (sempre uma batalha), bioma, treinador forte, Poké Mart, Centro e eventos; bolas antigas vão para a Bolsa', () {
    final kanto = data.bosses.firstWhere((b) => b['game'] == 'Red/Blue');
    final brock = (kanto['leaders'] as List).firstWhere((l) => l['name'] == 'Brock');
    expect(brock['city'], 'Pewter City');
    Map<String, dynamic> at(int floor, [int seed = 3]) => {...FactoryRun.startRun(FactoryRun.empty(), data, 4, seed)!, 'floor': floor};
    var state = 5;
    double rand() {
      final (v, s) = FactoryRun.nextRandom(state);
      state = s;
      return v;
    }

    // Até o ginásio (Brock): o caminho só se divide nas bifurcações; o líder só na cidade dele.
    final red = data.bosses.indexWhere((b) => b['game'] == 'Red/Blue');
    final leaders = data.bosses[red]['leaders'] as List;
    Map<String, dynamic> on(int floor, int step, [int leg = 1]) => {...at(floor), 'leg': leg, 'boss': {'region': red, 'step': step}};
    double Function() seq(List<double> v) {
      var i = 0;
      return () => v[i++ % v.length];
    }

    for (var pos = 0; pos < FactoryRun.routeLength; pos++) {
      final options = FactoryRun.routeOptions(on(11 + pos, 1, 11), data, rand)['options'] as List;
      expect(options, hasLength(FactoryRun.forks.contains(pos) ? 3 : 1));
      expect(options.any((o) => FactoryRun.isBattleNode(o as Map)), isTrue);
    }
    expect(FactoryRun.routeOptions(on(10, 1), data, rand)['options'], [{'kind': 'boss'}]);
    // O rival: em qualquer andar da rota; no último, sempre. Liga: a Elite Four e o Campeão em sequência.
    expect(FactoryRun.routeOptions(on(3, 0), data, seq([0.1, 0.5]))['options'], [{'kind': 'boss'}]);
    expect((FactoryRun.routeOptions(on(1, 0), data, seq([0.9, 0.5]))['options'] as List).first['kind'], isNot('boss'));
    expect(FactoryRun.routeOptions(on(9, 0), data, seq([0.9, 0.5]))['options'], [{'kind': 'boss'}]);
    final first = leaders.indexWhere((l) => l['kind'] == 'elite');
    expect((FactoryRun.routeOptions(on(5, first), data, seq([0.1, 0.5]))['options'] as List).first['kind'], isNot('boss'));
    for (var step = first + 1; step < leaders.length; step++) {
      expect(FactoryRun.routeOptions(on(12, step, 12), data, seq([0.5]))['options'], [{'kind': 'boss'}]);
    }
    expect(FactoryRun.routeCities(data, on(12, first + 1, 12)), (from: 'Indigo Plateau', to: 'Indigo Plateau'));
    final water = FactoryRun.encounterFor(data, 20, rand, null, false, {'kind': 'wild', 'biome': 'water'});
    expect((data.species[water['foes'][0]['id']]![4] as List).any(FactoryRun.biomes['water']!.contains), isTrue);
    final cave = {...at(20), 'encounter': {'kind': 'wild', 'biome': 'cave', 'foes': [{'id': 74, 'level': 20}]}};
    expect(FactoryRun.captureFor(cave, data), {'rates': [255], 'dusk': true});
    final ace = FactoryRun.encounterFor(data, 30, rand, null, false, {'kind': 'ace'});
    final won = FactoryRun.winFloor({...at(30), 'encounter': {...ace, 'reward': 'ultra-ball'}}, data);
    expect(won['bag']['ultra-ball'], 1);
    final base = {...at(4), 'team': [{...FactoryRun.teamOf(at(4)).first, 'hp': 0}]};
    final center = FactoryRun.chooseNode({...base, 'route': {'floor': 4, 'options': [{'kind': 'center'}]}}, data, 0);
    expect([center['floor'], center['team'][0]['hp']], [5, 1]);
    final mart = FactoryRun.chooseNode({...base, 'route': {'floor': 4, 'options': [{'kind': 'mart'}]}}, data, 0);
    expect((FactoryRun.pendingOf(mart)!['shop'] as List).length, greaterThanOrEqualTo(10));
    final old = FactoryRun.of({'factory': {'run': {...at(3), 'balls': 7}}});
    expect([old['run']['balls'], old['run']['bag']['poke-ball']], [null, 12]);
  });

  test('na batalha: a bola só no selvagem; a Master Ball captura e acaba a batalha (igual ao site)', () async {
    final hit = TurnBattleSetup.hitter(await DamageData.load());
    Map<String, dynamic> set(List<String> moves) => {'level': 50, 'moves': moves};
    final a = await TurnBattleSetup.mons([(25, set(['thunderbolt']))], (row) => '${row['name']}');
    final b = await TurnBattleSetup.mons([(150, set(['psychic']))], (row) => '${row['name']}');
    final wild = TurnBattle(a, b, League.seededRandom(3), startBags: [{'master-ball': 1}, null], capture: {'rates': [3], 'dusk': false});
    addTearDown(wild.dispose);
    wild.start();
    expect(wild.canUseItem(0, 'master-ball', 0), isTrue);
    expect(wild.canUseItem(0, 'poke-ball', 0), isFalse);
    final events = wild.playTurn(hit, item: 'master-ball', target: wild.activeIndex[1]);
    expect([wild.captured, wild.winner, wild.bags[0]['master-ball']], [0, 0, 0]);
    final ball = events.firstWhere((e) => e.t == 'ball');
    expect([ball.slug, ball.value, ball.index], ['master-ball', 3, 1]);
    expect(events.any((e) => e.key == 'caught'), isTrue);
    final c = await TurnBattleSetup.mons([(150, set(['psychic']))], (row) => '${row['name']}');
    final trainer = TurnBattle(await TurnBattleSetup.mons([(25, set(['thunderbolt']))], (row) => '${row['name']}'), c, League.seededRandom(3), startBags: [{'master-ball': 1}, null]);
    addTearDown(trainer.dispose);
    expect(trainer.canUseItem(0, 'master-ball', 0), isFalse);
  });

  test('evoluídos só a partir do nível em que evoluem: abaixo dele, a forma anterior (igual ao site)', () {
    expect([FactoryRun.minLevelOf(data, 252), FactoryRun.minLevelOf(data, 253), FactoryRun.minLevelOf(data, 254)], [1, 16, 36]);
    expect([FactoryRun.devolve(data, 254, 2), FactoryRun.devolve(data, 254, 20), FactoryRun.devolve(data, 254, 40)], [252, 253, 254]);
    expect(FactoryRun.minLevelOf(data, 26), 25);
    var state = 8;
    double rand() {
      final (v, s) = FactoryRun.nextRandom(state);
      state = s;
      return v;
    }

    for (var floor = 1; floor <= 30; floor++) {
      for (final node in [{'kind': 'wild', 'biome': 'forest'}, {'kind': 'trainer'}, {'kind': 'ace'}]) {
        for (final f in FactoryRun.encounterFor(data, floor, rand, null, false, node)['foes'] as List) {
          expect(f['level'] as int, greaterThanOrEqualTo(FactoryRun.minLevelOf(data, f['id'] as int)));
        }
      }
      for (final f in FactoryRun.encounterFor(data, floor, rand, null, true)['foes'] as List) {
        expect(f['level'] as int, greaterThanOrEqualTo(FactoryRun.minLevelOf(data, f['id'] as int)));
      }
    }
  });
}
