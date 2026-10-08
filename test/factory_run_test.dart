import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    expect(run['balls'], 5);
    expect(run['bag'], FactoryRun.startBag);
    expect(jsonEncode(FactoryRun.startRun(f, data, 1, 42)), jsonEncode(run));
    // O mesmo que o site sorteia (web-site/src/lib/factoryRun.test.js): a corrida continua de um no outro.
    expect(run['seed'], 503953318);
    expect(run['team'][0]['ivs'], {'hp': 25, 'atk': 22, 'def': 29, 'spa': 26, 'spd': 17, 'spe': 23});
    expect(run['team'][0]['nature'], 'Docile');
    expect(run['boss'], {'region': 11, 'step': 0});
    expect(run['encounter'], {'kind': 'wild', 'foes': [{'id': 235, 'level': 3, 'iv': 0, 'ev': 3}]});
  });

  test('40 andares iguais ao site (test/fixtures/factory_trace.json): chefes, captura, carta e loja', () {
    final expected = jsonDecode(File('test/fixtures/factory_trace.json').readAsStringSync()) as List;
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 7, 2024)!;
    final out = [];
    for (var i = 0; i < 40; i++) {
      final team = FactoryRun.teamOf(run);
      run = FactoryRun.winFloor(run, data, hp: [for (var k = 0; k < team.length; k++) k == 0 ? 0.7 : 1.0]);
      if (FactoryRun.pendingOf(run)!['capture'] != null) run = FactoryRun.capture(run, FactoryRun.teamOf(run).length >= FactoryRun.maxTeam ? 1 : null);
      if (FactoryRun.pendingOf(run)!['cards'] != null) run = FactoryRun.takeCard(run, '${(FactoryRun.pendingOf(run)!['cards'] as List).first}', data);
      run = {...run, 'money': (run['money'] as int) + 500};
      for (final id in (FactoryRun.pendingOf(run)!['shop'] as List?) ?? const []) {
        run = FactoryRun.buyItem(run, '$id', 0, data) ?? run;
      }
      run = FactoryRun.nextFloor(run, data);
      out.add([
        run['seed'], run['floor'], run['money'], run['balls'], run['boss']['region'], run['boss']['step'],
        [for (final m in FactoryRun.teamOf(run)) [m['id'], m['level'], m['exp'], m['item'] ?? '', (m['extras'] as List).length]],
        run['encounter']['kind'],
        [for (final f in FactoryRun.foesOf(run)) [f['id'], f['level'], f['shiny'] == true ? 1 : 0]],
      ]);
    }
    for (var i = 0; i < expected.length; i++) {
      expect(jsonEncode(out[i]), jsonEncode(expected[i]), reason: 'andar ${i + 1}');
    }
  });

  test('venceu: XP só para quem está de pé; HP continua; captura com Poké Ball; shiny libera o inicial shiny', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 4, 3)!;
    run = {
      ...run,
      'team': [...FactoryRun.teamOf(run), {...FactoryRun.teamOf(run).first, 'id': 7}],
      'encounter': {'kind': 'wild', 'foes': [{'id': 19, 'level': 5, 'iv': 0, 'ev': 0, 'shiny': true}]},
    };
    final after = FactoryRun.winFloor(run, data, hp: [0.4, 0]);
    expect(after['floor'], 2);
    final team = FactoryRun.teamOf(after);
    expect(team[0]['exp'], FactoryRun.expAt(5) + FactoryRun.expFor(data.species[19]![0] as int, 5, 5));
    expect(team[1]['exp'], FactoryRun.expAt(5));
    final caught = FactoryRun.capture(after);
    expect(caught['balls'], 4);
    expect(caught['team'][2]['shiny'], true);
    expect(FactoryRun.capture({...after, 'balls': 0}), {...after, 'balls': 0});
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
    expect(run['balls'], 6);
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
    var after = FactoryRun.winFloor(run, data);
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
    final run = {...start, 'team': [strong, {...strong, 'hp': 0}]};
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
}
