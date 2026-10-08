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

  test('começa com um inicial grátis no nível 5; a mesma semente dá a mesma corrida', () {
    final f = FactoryRun.empty();
    expect(FactoryRun.startRun(f, data, 150, 1), isNull);
    final run = FactoryRun.startRun(f, data, 1, 42)!;
    expect(run['team'], hasLength(1));
    expect(run['team'][0]['level'], 5);
    expect(jsonEncode(FactoryRun.startRun(f, data, 1, 42)), jsonEncode(run));
    // O mesmo que o site sorteia (web-site/src/lib/factoryRun.js): a corrida continua de um no outro.
    expect(run['seed'], 1135788988);
    expect(run['team'][0]['ivs'], {'hp': 25, 'atk': 22, 'def': 29, 'spa': 26, 'spd': 17, 'spe': 23});
    expect(run['team'][0]['nature'], 'Docile');
    expect(run['encounter'], {'kind': 'wild', 'foes': [{'id': 403, 'level': 3, 'iv': 0}]});
  });

  test('venceu: XP, dinheiro, captura; time cheio troca; evolução', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 4, 3)!;
    run = {...run, 'encounter': {'kind': 'wild', 'foes': [{'id': 19, 'level': 5, 'iv': 0}]}};
    final after = FactoryRun.winFloor(run, data);
    expect(after['floor'], 2);
    expect(after['money'], 40);
    expect(after['team'][0]['exp'], FactoryRun.expAt(5) + (data.species[19]![0] * 5 / 7).floor());
    final caught = FactoryRun.capture(after);
    expect([for (final m in caught['team']) m['id']], [4, 19]);
    final (mon, evolved) = FactoryRun.levelTo({'id': 1, 'level': 15, 'exp': 0, 'bonus': {}}, 16, data, () => 0);
    expect([mon['id'], evolved], [2, 2]);
  });

  test('loja e cartas; itens sem limite viram pontos', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 1, 5)!;
    run = {...run, 'floor': 10, 'encounter': {'kind': 'trainer', 'foes': [{'id': 19, 'level': 12, 'iv': 0}]}};
    final after = FactoryRun.winFloor(run, data);
    expect(after['pending']['shop'], contains('rare-candy'));
    expect(after['pending']['cards'], hasLength(3));
    var shop = {...after, 'money': 20000, 'pending': {'shop': ['leftovers', 'choice-band', 'protein']}};
    shop = FactoryRun.buyItem(shop, 'leftovers', 0, data)!;
    shop = FactoryRun.buyItem(shop, 'choice-band', 0, data)!;
    expect(shop['team'][0]['item'], 'leftovers');
    expect(shop['team'][0]['bonus']['atk'], 10);
    final card = FactoryRun.takeCard({...shop, 'pending': {'cards': ['atk']}}, 'atk', data);
    expect(FactoryRun.memberOf(card, FactoryRun.teamOf(card)[0], ['tackle']).$2['bonus']['atk'], 18);
  });

  test('perdeu: moedas pela pontuação; moedas compram Pokémon pela força', () {
    final run = {...FactoryRun.startRun(FactoryRun.empty(), data, 1, 5)!, 'floor': 21, 'defeated': 30};
    final f = FactoryRun.endRun({...FactoryRun.empty(), 'best': 7}, run);
    expect([f['coins'], f['best'], f['run']], [160, 20, null]);
    final bought = FactoryRun.buyPokemon({...f, 'coins': 10000}, data, 150)!;
    expect(bought['owned'], [150]);
    expect(FactoryRun.startersOf(bought, data), contains(150));
    expect(FactoryRun.pokemonPrice(data.species[150]![1]), greaterThan(FactoryRun.pokemonPrice(data.species[19]![1])));
  });

  test('golpes pelo nível, iguais ao site', () {
    final list = FactoryRun.movesAt(pokemon[4]!['moves'] as List, 5, ['fire'], moves);
    expect(list, ['scratch', 'growl']);
  });

  test('na batalha: passa do nível 50, os bônus somam e o selvagem fica sem bolsa', () async {
    final start = FactoryRun.startRun(FactoryRun.empty(), data, 4, 7)!;
    final run = {...start, 'team': [{...start['team'][0], 'level': 80, 'bonus': {'hp': 0, 'atk': 0, 'def': 0, 'spa': 0, 'spd': 0, 'spe': 600}}]};
    final moveList = FactoryRun.movesAt(pokemon[4]!['moves'] as List, 80, ['fire'], moves);
    final plain = {...run, 'team': [{...run['team'][0], 'bonus': {'hp': 0, 'atk': 0, 'def': 0, 'spa': 0, 'spd': 0, 'spe': 0}}]};
    final mons = await TurnBattleSetup.mons([
      FactoryRun.memberOf(run, FactoryRun.teamOf(run).single, moveList),
      FactoryRun.memberOf(plain, FactoryRun.teamOf(plain).single, moveList),
    ], (row) => '${row['name']}');
    expect(mons[0].level, 80);
    final foes = await TurnBattleSetup.mons([for (final f in FactoryRun.foesOf(run)) FactoryRun.foeMember(f, const ['tackle'])], (row) => '${row['name']}');
    final battle = TurnBattle([mons[0]], foes, League.seededRandom(1), startBags: FactoryRun.bagsFor(run));
    expect(run['encounter']['kind'], 'wild');
    expect(battle.bags[1].values.every((n) => n == 0), isTrue);
    expect(battle.bags[0]['potion'], 3);
    // Os bônus valem no motor (a velocidade volta dele já somada).
    expect(battle.teams[0][0].spe, mons[1].spe + 600);
    battle.dispose();
  });
}
