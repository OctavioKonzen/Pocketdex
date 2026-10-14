import 'dart:convert';
import 'dart:math';
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
    expect(run['seed'], 2967354801);
    expect(run['team'][0]['ivs'], {'hp': 25, 'atk': 22, 'def': 29, 'spa': 26, 'spd': 17, 'spe': 23});
    expect(run['team'][0]['nature'], 'Docile');
    expect(run['boss'], {'region': 11, 'step': 0});
    expect(run['encounter'], isNull);
    expect(run['route'], {'floor': 1, 'biome': 'grass', 'options': [{'kind': 'trainer'}]});
    expect(FactoryRun.chooseNode(run, data, 0)['encounter'], {
      'kind': 'trainer', 'foes': [{'id': 276, 'level': 3, 'iv': 0, 'ev': 3}], 'trainerSeed': 500729487, 'scene': 'grass',
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
      // Na cidade: compra no Poké Mart dela antes de escolher (o ginásio ou o lugar perto dela).
      if (FactoryRun.routeOf(run)!['town'] == true) {
        run = FactoryRun.townShop({...run, 'money': (run['money'] as int) + 500});
        for (final id in FactoryRun.pendingOf(run)!['shop'] as List) {
          run = FactoryRun.buyItem(run, '$id', 0, data) ?? run;
        }
        run = {...run, 'pending': null};
      }
      run = FactoryRun.chooseNode(run, data, i % options.length);
      final encounter = run['encounter'] == null ? null : Map<String, dynamic>.from(run['encounter'] as Map);
      final foes = FactoryRun.foesOf(run);
      if (encounter != null) {
        final team = FactoryRun.teamOf(run);
        run = FactoryRun.winFloor(run, data, hp: [for (var k = 0; k < team.length; k++) k == 0 ? 0.7 : 1.0], captured: i % 3 == 0);
      }
      run = {...run, 'pending': FactoryRun.pendingOf(run) ?? <String, dynamic>{}};
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

  test('só a primeira forma à venda; contas antigas ficam com a primeira; melhorias permanentes (igual ao site)', () {
    expect(FactoryRun.baseForm(data, 6), 4);
    expect(FactoryRun.forSale(data, 6), isFalse);
    final rich = {...FactoryRun.empty(), 'owned': [1], 'coins': 99999};
    expect(FactoryRun.buyPokemon(rich, data, 6), isNull);
    expect(FactoryRun.normalizeOwned({...FactoryRun.empty(), 'owned': [1, 6, 5, 3], 'shinies': [6]}, data), containsPair('owned', [1, 4]));
    var f = {...rich, 'best': 999, 'owned': [1, 4, 7, 152, 155, 158, 252, 255]};
    for (final id in FactoryRun.upgrades.keys) {
      while (FactoryRun.upgradePrice(f, id) != null) {
        f = FactoryRun.buyUpgrade(f, id)!;
      }
    }
    final run = FactoryRun.startRun(f, data, 1, 42)!;
    expect(FactoryRun.teamOf(run).first['level'], 10);
    expect(run['money'], 500);
    expect(run['bag']['revive'], 4);
    expect(run['mult'], {'money': 1, 'exp': 1.25, 'shop': 0.8});
    // O mesmo preço do site.
    expect(FactoryRun.upgradePrice(FactoryRun.empty(), 'level'), 150);
    expect(FactoryRun.upgradePrice({...FactoryRun.empty(), 'upgrades': {'level': 1}}, 'level'), 455);
  });

  test('devolve moedas na troca para a primeira forma; melhorias que mudam o jogo; chefes com itens (igual ao site)', () {
    int price(int id) => FactoryRun.pokemonPrice(data.species[id]![1] as int);
    final fixed = FactoryRun.normalizeOwned({...FactoryRun.empty(), 'coins': 0, 'owned': [1, 6, 5, 4]}, data);
    expect(fixed['owned'], [1, 4]);
    expect(fixed['coins'], price(6) + price(5));
    expect(FactoryRun.normalizeOwned({...FactoryRun.empty(), 'coins': 10, 'owned': [1, 6]}, data)['coins'], 10 + price(6) - price(4));
    var f = {...FactoryRun.empty(), 'coins': 999999, 'best': 999, 'owned': [1, 4, 7, 152, 155, 158, 252, 255]};
    for (final id in FactoryRun.upgrades.keys) {
      while (FactoryRun.upgradePrice(f, id) != null) {
        f = FactoryRun.buyUpgrade(f, id)!;
      }
    }
    final run = FactoryRun.startRun(f, data, 1, 42)!;
    expect(run['expShare'], true);
    expect(run['cardCount'], 4);
    expect(run['rerolls'], 2);
    expect(run['shinyRate'], 4);
    expect(FactoryRun.rerollRoute(run, data)!['rerolls'], 1);
    expect(FactoryRun.rerollRoute({...run, 'rerolls': 0}, data), isNull);
    var state = 5;
    double rand() {
      final (v, s) = FactoryRun.nextRandom(state);
      state = s;
      return v;
    }
    final boss = FactoryRun.encounterFor(data, 20, rand, FactoryRun.bossOf(data, FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!));
    expect((boss['foes'] as List).every((x) => FactoryRun.foeItems.contains(x['item'])), isTrue);
  });

  test('Mapa: aparece fácil na loja até ser comprado; sem ele, a bifurcação vai às cegas (igual ao site)', () {
    final cases = [(42, 2, 3), (123456789, 5, 2), (2147483647, 9, 3), (7, 100, 3)];
    expect([for (final (seed, floor, n) in cases) FactoryRun.blindPick({'seed': seed, 'floor': floor, 'route': {'options': List.filled(n, {})}})], [1, 0, 1, 2]);
    final run = {...FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!, 'money': 9999, 'pending': {'shop': ['town-map']}};
    final bought = FactoryRun.buyItem(run, 'town-map', 0, data)!;
    expect(bought['townMap'], true);
    expect(FactoryRun.buyItem(bought, 'town-map', 0, data), isNull);
  });

  test('base da equipe vilã: só capangas com os Pokémon da equipe; cenário de cada chefe (igual ao site)', () {
    // A base é um lugar da cidade (com a equipe vilã na cidade): na rota, o lugar do ginásio.
    final run = {
      ...FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!,
      'floor': 23, 'leg': 3, 'boss': {'region': 0, 'step': 11}, 'dungeon': {'place': 'base', 'scene': 'base-rocket', 'start': 21},
    };
    expect(FactoryRun.routeBiome(data, run), 'base-rocket');
    expect(FactoryRun.routeBiome(data, {...run, 'dungeon': null}), isNot('base-rocket'));
    var state = 11;
    double rand() {
      final (v, s) = FactoryRun.nextRandom(state);
      state = s;
      return v;
    }
    for (var i = 0; i < 30; i++) {
      final route = FactoryRun.routeOptions({...run, 'floor': 21 + (i % 9)}, data, rand);
      expect((route['options'] as List).any((o) => ['wild', 'mart', 'trade', 'wildboss'].contains(o['kind'])), isFalse);
    }
    final grunt = FactoryRun.encounterFor(data, 23, rand, null, false, {'kind': 'trainer', 'biome': 'base-rocket'});
    expect(grunt['grunt'], 'rocket');
    final brock = (data.bosses[0]['leaders'] as List).cast<Map>().firstWhere((l) => l['id'] == 'kanto-brock');
    expect(FactoryRun.bossScene(data, {...brock, 'region': 'Kanto'}), 'gym-rock');
    expect(FactoryRun.bossScene(data, {'kind': 'champion', 'region': 'Kanto'}), 'champion-kanto');
    expect(FactoryRun.bossScene(data, {'kind': 'villain', 'name': 'Archie'}), 'base-aqua');
    expect(FactoryRun.bossScene(data, null, 'forest'), 'forest');
  });

  test('troca, Escape Rope e conquistas (iguais ao site)', () {
    final base = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    final first = FactoryRun.teamOf(base).first;
    final run = {...base, 'team': [{...first, 'level': 10, 'item': 'leftovers'}], 'pending': {'trade': {'id': 19}}};
    final traded = FactoryRun.teamOf(FactoryRun.tradeMon(run, 0, data)).first;
    expect(traded['id'], 19);
    expect(traded['level'], 13);
    expect(traded['ivs'], {'hp': 29, 'atk': 26, 'def': 16, 'spa': 14, 'spd': 21, 'spe': 25});
    expect(traded['nature'], 'Modest');
    expect(traded['item'], 'leftovers');
    expect(FactoryRun.escapeRope(base, data, hp: [0]), isNull);
    final escaped = FactoryRun.escapeRope({...base, 'floor': 7, 'bag': {...base['bag'] as Map, 'escape-rope': 1}}, data, hp: [0])!;
    expect(escaped['route'], {'floor': 7, 'biome': 'flowers', 'options': [{'kind': 'trainer'}]});
    expect(FactoryRun.teamOf(escaped).first['hp'], FactoryRun.escapeHp);
    expect(escaped['bag']['escape-rope'], 0);
    final (f1, earned) = FactoryRun.progress(
        {...FactoryRun.empty(), 'coins': 0}, {...base, 'floor': 30, 'badges': 1, 'champions': 1, 'pending': {'champion': true}});
    expect(earned, containsAll(['badge', 'champion', 'floor25']));
    expect((f1['hall'] as List), hasLength(1));
    final (f2, again) = FactoryRun.progress(f1, {...base, 'floor': 30, 'badges': 1, 'champions': 1, 'pending': {'champion': true}});
    expect(again, isEmpty);
    expect(identical(f1, f2), isTrue);
  });

  test('XP só para quem lutou; com o Exp. Share, a metade para o resto do time (igual ao site)', () {
    final base = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    final first = FactoryRun.teamOf(base).first;
    final run = {
      ...base,
      'team': [first, {...first, 'id': 4}, {...first, 'id': 7, 'hp': 0.0}],
      'encounter': {'kind': 'wild', 'foes': [{'id': 19, 'level': 7, 'iv': 0, 'ev': 0}, {'id': 16, 'level': 7, 'iv': 0, 'ev': 0}]},
    };
    int e(int id, int lvl) => FactoryRun.expFor(data.species[id]![0] as int, 7, lvl);
    final after = FactoryRun.winFloor(run, data, fought: [[0], [0, 1]]);
    expect(FactoryRun.pendingOf(after)!['gains'], [e(19, 5) + e(16, 5), e(16, 5), 0]);
    expect(FactoryRun.winFloor(run, data, fought: [[0], [0]])['pending']['gains'][1], 0);
    final shared = FactoryRun.buyItem({...run, 'money': 99999, 'pending': {'shop': ['exp-share']}}, 'exp-share', 0, data)!;
    expect(shared['expShare'], true);
    final half = FactoryRun.winFloor({...shared, 'encounter': run['encounter']}, data, fought: [[0], [0]]);
    expect(half['pending']['gains'][1], (e(19, 5) * FactoryRun.expShare).floor() + (e(16, 5) * FactoryRun.expShare).floor());
    expect(FactoryRun.expProgress({'level': 5, 'exp': 125}), 0);
    expect(FactoryRun.expProgress({'level': 5, 'exp': 125}, 9999), 1);
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
    // Selvagem: só quem vive no lugar (o habitat dele, dos locais de encontro dos jogos).
    var local = 0;
    for (var i = 0; i < 100; i++) {
      final water = FactoryRun.encounterFor(data, 20, rand, null, false, {'kind': 'wild', 'biome': 'water'});
      if ((data.species[water['foes'][0]['id']]![6] as List).contains('water')) local++;
    }
    expect(local, 100);
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

  test('história: rival com o inicial de vantagem, lendário da região, missão da rota e escolhas (igual ao site)', () {
    expect(FactoryRun.starterLine(data, 1), [1, 2, 3]);
    expect([FactoryRun.rivalStarter(data, 1), FactoryRun.rivalStarter(data, 4), FactoryRun.rivalStarter(data, 7), FactoryRun.rivalStarter(data, 19)], [4, 7, 1, null]);
    final base = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    expect(base['starter'], 1);
    expect(FactoryRun.regionLegends[data.bosses[base['boss']['region'] as int]['region']], contains(FactoryRun.regionLegend(data, base)));
    expect(['defeat', 'catch'], contains(base['mission']['kind']));
    expect(base['mission']['leg'], 1);
    final red = data.bosses.indexWhere((b) => b['game'] == 'Red/Blue');
    Json step(String kind) => {'region': red, 'step': (data.bosses[red]['leaders'] as List).indexWhere((l) => l['kind'] == kind)};
    expect(
        FactoryRun.newMission({...base, 'boss': step('villain'), 'dungeon': {'place': 'base', 'scene': 'base-rocket', 'start': 1}}, data, () => 0.5)['kind'],
        'grunts');
    final rival = FactoryRun.chooseNode({
      ...base,
      'boss': step('rival'),
      'floor': 9,
      'route': {'floor': 9, 'biome': 'grass', 'options': [{'kind': 'boss'}]},
    }, data, 0);
    expect((rival['encounter']['foes'] as List).any((f) => [4, 5, 6].contains(f['id'])), isTrue);
    final run = {
      ...base,
      'money': 0,
      'mission': {'leg': 1, 'kind': 'defeat', 'type': 'normal', 'need': 3, 'done': 2},
      'encounter': {'kind': 'trainer', 'foes': [{'id': 19, 'level': 5, 'iv': 0, 'ev': 0}]},
    };
    final won = FactoryRun.winFloor(run, data, bag: {'potion': 1});
    expect(won['mission']['done'], 3);
    expect(won['pending']['mission']['money'] as int, greaterThanOrEqualTo(FactoryRun.missionMoney));
    expect(won['money'] as int, greaterThanOrEqualTo(won['pending']['mission']['money'] as int));
    expect(FactoryRun.winFloor({...run, 'mission': {...run['mission'] as Map, 'type': 'fire'}}, data)['mission']['done'], 2);
    final at = {...base, 'money': 1000, 'floor': 4, 'scene': 'grass'};
    Json help(Json r) => {...r, 'pending': {'choice': {'kind': 'help', 'cost': 100}}};
    expect(FactoryRun.resolveChoice(help(at), data, false)['pending']['event']['kind'], 'declined');
    final helped = FactoryRun.resolveChoice(help(at), data, true);
    expect(helped['money'], 900);
    expect(helped['pending']['event']['kind'], 'helped');
    expect(FactoryRun.resolveChoice(help({...at, 'money': 10}), data, true)['money'], 10);
    expect(FactoryRun.resolveChoice({...at, 'hms': ['flash'], 'pending': {'choice': {'kind': 'secret'}}}, data, true)['pending']['event']['kind'], 'secretFound');
    final follow = FactoryRun.resolveChoice({...at, 'pending': {'choice': {'kind': 'follow'}}}, data, true);
    expect(follow['floor'], 3);
    expect(follow['encounter']['kind'], 'wild');
    expect(data.species[follow['encounter']['foes'][0]['id']]![5] as num, lessThanOrEqualTo(75));
  });

  test('jogabilidade: MOs pelas insígnias, Pokédex da corrida, Creche com ovo, revanche do Campeão (igual ao site)', () {
    final base = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    expect(FactoryRun.hmBadges, {1: 'cut', 2: 'flash', 3: 'surf'});
    final sea = {
      ...base,
      'route': {
        'floor': 2,
        'biome': 'water',
        'options': [{'kind': 'wild', 'biome': 'underwater'}, {'kind': 'trainer'}],
      },
    };
    final dive = (sea['route'] as Map)['options'][0] as Map;
    expect(FactoryRun.nodeBlocked(sea, dive), isTrue);
    expect(identical(FactoryRun.chooseNode(sea, data, 0), sea), isTrue);
    expect(FactoryRun.blindPick(sea), 1);
    expect(FactoryRun.nodeBlocked({...sea, 'hms': ['surf']}, dive), isFalse);
    expect(FactoryRun.cutPath(sea), isNull);
    final cut = FactoryRun.cutPath({...sea, 'hms': ['cut']})!;
    expect((cut['route']['options'] as List).last, {'kind': 'wild', 'biome': 'water', 'rare': true, 'cut': true});
    expect(FactoryRun.cutPath(cut), isNull);
    expect(FactoryRun.dexOf(base), [1]);
    final four = {...base, 'dex': [1, 2, 3, 4]};
    expect(FactoryRun.dexRewardFor(four, 4), isNull);
    expect(FactoryRun.dexRewardFor(four, 19), FactoryRun.dexRewards[0]);
    final caught = FactoryRun.capture({...four, 'money': 0, 'pending': {'capture': {'id': 19, 'level': 5}}});
    expect(caught['dex'], [1, 2, 3, 4, 19]);
    expect(caught['money'], FactoryRun.dexRewards[0]['money']);
    final item = '${FactoryRun.dexRewards[0]['item']}';
    expect(caught['bag'][item], ((base['bag'][item] as num?) ?? 0) + (FactoryRun.dexRewards[0]['count'] as int));
    final first = FactoryRun.teamOf(base).first;
    final two = {...base, 'team': [first, {...first, 'id': 19, 'level': 10}]};
    expect(FactoryRun.leaveDaycare(base, 0), isNull);
    final left = FactoryRun.leaveDaycare(two, 1)!;
    expect((left['team'] as List).length, 1);
    final back = FactoryRun.takeDaycare({...left, 'floor': (left['floor'] as int) + FactoryRun.daycareEgg}, data)!;
    expect(FactoryRun.teamOf(back)[1]['level'], 10 + FactoryRun.daycareEgg);
    expect(back['pending']['capture'], {'id': 19, 'level': 5, 'egg': true});
    final egg = FactoryRun.capture(back);
    expect((FactoryRun.teamOf(egg)[2]['ivs'] as Map).values.cast<int>().reduce(min), greaterThanOrEqualTo(FactoryRun.eggIvs));
    final red = data.bosses.indexWhere((b) => b['game'] == 'Red/Blue');
    final re = {...base, 'rematch': {'region': red}};
    expect(FactoryRun.rematchBoss(data, re)['kind'], 'champion');
    final fight = FactoryRun.chooseNode({
      ...re,
      'route': {'floor': 2, 'biome': 'grass', 'options': [{'kind': 'rematch'}]},
    }, data, 0);
    expect(fight['encounter']['kind'], 'rematch');
    expect(fight['encounter']['boss']['kind'], 'champion');
    final won = FactoryRun.winFloor(fight, data);
    expect(won['rematch'], isNull);
    expect(won['rematches'], 1);
    expect(won['boss'], fight['boss']);
  });

  test('lugares novos, noite e estações (pelo relógio) e os efeitos novos (igual ao site)', () {
    for (final b in ['ruins', 'flowers', 'plant', 'crystal', 'dunes', 'bamboo', 'temple']) {
      expect(FactoryRun.biomeIds, contains(b));
      expect(data.species.values.any((s) => (s[6] as List).contains(b)), isTrue);
    }
    expect(FactoryRun.clockOf(DateTime(2026, 1, 10, 21)), (night: true, season: 'spring'));
    expect(FactoryRun.clockOf(DateTime(2026, 4, 10, 12)), (night: false, season: 'winter'));
    expect(FactoryRun.clockOf(DateTime(2026, 10, 13, 5)), (night: true, season: 'summer'));
    final base = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    final floors = [for (var k = 0; k < 40; k++) {...base, 'floor': k + 1}];
    expect(floors.any((r) => FactoryRun.weatherOf(r, 'grass', 'winter') == 'snow'), isTrue);
    expect(floors.any((r) => FactoryRun.weatherOf(r, 'grass', 'summer') == 'snow'), isFalse);
    expect(floors.any((r) => FactoryRun.fieldOf(r, 'flowers') == 'spores'), isTrue);
    int ghosts(bool night) {
      var n = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final run = {
          ...FactoryRun.startRun(FactoryRun.empty(), data, 1, seed)!,
          'floor': 20,
          'route': {'floor': 20, 'biome': 'grass', 'options': [{'kind': 'trainer'}]},
        };
        final out = FactoryRun.chooseNode(run, data, 0, night ? (night: true, season: 'spring') : null);
        n += (out['encounter']['foes'] as List).where((f) => (data.species[f['id']]![4] as List).any((t) => t == 'ghost' || t == 'dark')).length;
      }
      return n;
    }

    expect(ghosts(true), greaterThan(ghosts(false)));
  });

  test('a música de cada lugar (igual ao site)', () {
    expect(FactoryRun.placeMusic('grass'), 'place_field');
    expect(FactoryRun.placeMusic('crystal'), 'place_cave');
    expect(FactoryRun.placeMusic('base-rocket'), 'place_city');
    expect(FactoryRun.placeMusic('gym-fire'), 'battle_music');
    for (final b in FactoryRun.biomeIds) {
      expect(FactoryRun.placeMusic(b), isNot('battle_music'));
    }
  });

  test('árvore de melhorias (igual ao site)', () {
    final f = {...FactoryRun.empty(), 'coins': 99999};
    expect(FactoryRun.upgradeNeeds(f, 'level'), isEmpty);
    expect(FactoryRun.upgradeNeeds(f, 'ivs'), [
      {'kind': 'up', 'id': 'level', 'level': 2},
      {'kind': 'best', 'floor': 8},
    ]);
    expect(FactoryRun.buyUpgrade(f, 'ivs'), isNull);
    var g = FactoryRun.buyUpgrade(f, 'level')!;
    expect(FactoryRun.upgradeNeeds(g, 'level'), [{'kind': 'best', 'floor': 3}]);
    g = FactoryRun.buyUpgrade({...g, 'best': 3}, 'level')!;
    expect(FactoryRun.buyUpgrade({...g, 'best': 7}, 'ivs'), isNull);
    expect(FactoryRun.buyUpgrade({...g, 'best': 8}, 'ivs')!['upgrades']['ivs'], 1);
    expect(FactoryRun.upgradeNeeds({...g, 'best': 99, 'upgrades': {'reroll': 1}}, 'cards'), [{'kind': 'owned', 'count': 8}]);
    expect([for (final b in FactoryRun.upgradeBranches) ...b.$3]..sort(), FactoryRun.upgrades.keys.toList()..sort());
  });

  test('tirar o item equipado (igual ao site)', () {
    final base = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    final first = FactoryRun.teamOf(base).first;
    final run = {
      ...base,
      'team': [
        {...first, 'item': 'leftovers', 'extras': ['life-orb']},
        {...first, 'item': null, 'extras': <String>[]},
      ],
      'stash': <String>[],
    };
    final off = FactoryRun.unequipItem(run, 0);
    expect(FactoryRun.teamOf(off)[0]['item'], isNull);
    expect(off['stash'], ['leftovers']);
    final extra = FactoryRun.unequipItem(off, 0, 0);
    expect(FactoryRun.teamOf(extra)[0]['extras'], isEmpty);
    expect(extra['stash'], ['leftovers', 'life-orb']);
    expect(FactoryRun.teamOf(FactoryRun.equipFromStash(extra, 0, 1))[1]['item'], 'leftovers');
    expect(identical(FactoryRun.unequipItem(run, 1), run), isTrue);
  });

  test('batalhas duplas a partir do andar doubleFloor, com 2 de pé (igual ao site)', () {
    Map<String, dynamic> run(int floor, bool pair, double hp) => {'floor': floor, 'encounter': {'pair': pair}, 'team': [{'hp': 1}, {'hp': hp}]};
    expect(FactoryRun.isDoubleBattle(run(FactoryRun.doubleFloor, true, 0.5)), isTrue);
    expect(FactoryRun.isDoubleBattle(run(FactoryRun.doubleFloor - 1, true, 0.5)), isFalse);
    expect(FactoryRun.isDoubleBattle(run(FactoryRun.doubleFloor, false, 0.5)), isFalse);
    expect(FactoryRun.isDoubleBattle(run(FactoryRun.doubleFloor, true, 0)), isFalse);
  });

  test('cidade: o ginásio e um lugar com batalha perto (10 andares e um chefe; depois volta para a cidade); Poké Mart e Centro (igual ao site)', () {
    final red = data.bosses.indexWhere((b) => b['game'] == 'Red/Blue');
    var run = FactoryRun.nextFloor({...FactoryRun.startRun(FactoryRun.empty(), data, 4, 3)!, 'floor': 10, 'leg': 1, 'boss': {'region': red, 'step': 1}}, data);
    final route = FactoryRun.routeOf(run)!;
    expect(route['town'], isTrue);
    final place = '${run['town']['place']}';
    expect(route['options'], [
      {'kind': 'boss'},
      {'kind': 'dungeon', 'place': place, 'scene': FactoryRun.dungeons[place]!.scene},
    ]);
    expect(FactoryRun.pendingOf(FactoryRun.townShop(run))!['shop'], run['town']['shop']);
    expect(FactoryRun.teamOf(FactoryRun.townCenter({...run, 'team': [for (final m in FactoryRun.teamOf(run)) {...m, 'hp': 0}]})).every((m) => m['hp'] == 1), isTrue);
    // Entra no lugar: os andares dele (sem o líder), o chefe no último e a volta para a cidade.
    run = FactoryRun.chooseNode(run, data, 1);
    expect(run['dungeon']['place'], place);
    expect(FactoryRun.atCity(data, run), isFalse);
    expect(FactoryRun.routeOf(run)!['options'].any((o) => o['kind'] == 'boss'), isFalse);
    run = FactoryRun.nextFloor({...run, 'floor': (run['floor'] as num).toInt() + FactoryRun.dungeonLength - 1}, data);
    expect(FactoryRun.routeOf(run)!['options'], [{'kind': 'dboss'}]);
    run = FactoryRun.chooseNode(run, data, 0);
    expect(run['encounter']['kind'], 'dboss');
    run = FactoryRun.nextFloor(FactoryRun.winFloor(run, data), data);
    expect(run['dungeon'], isNull);
    expect(FactoryRun.routeOf(run)!['options'], [{'kind': 'boss'}]);
  });
}
