// lib/services/factory_run.dart
//
// Battle Factory: você escolhe um inicial no nível 5 e vai subindo andares.
// Cada andar é um Pokémon selvagem (dá para capturar, até 6 no time), um
// treinador ou, mais raro, um lendário. Cada Pokémon derrotado dá XP (o time
// todo sobe de nível e evolui) e dinheiro para a loja, que aparece a cada 5
// andares e com 20% de chance nos outros. A cada 10 andares você escolhe uma
// carta de bônus. Aqui não há limite de itens, IVs ou EVs: um item é o
// segurado e os outros viram pontos a mais nos atributos (o motor soma esses
// pontos: tool/battle-engine/engine.mjs, "bonus").
// Perdeu: a corrida acaba e a pontuação vira moedas, que compram Pokémon para
// começar as próximas corridas (os mais fortes custam mais).
// A corrida fica na conta (league.factory) no mesmo formato do site
// (web-site/src/lib/factoryRun.js): começa no app e continua no site.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

typedef Json = Map<String, dynamic>;

class FactoryData {
  /// id → [xp base, total de atributos, raridade (0 comum, 1 lendário, 2 mítico, 3 bebê)].
  final Map<int, List<int>> species;

  /// id → [[evolui para, nível], ...].
  final Map<int, List<List<int>>> evolutions;
  final List<int> starters;
  const FactoryData(this.species, this.evolutions, this.starters);

  static Future<FactoryData>? _loading;
  static Future<FactoryData> load() => _loading ??= rootBundle.loadString('assets/database/factory.json').then((t) => parse(jsonDecode(t) as Json));

  static FactoryData parse(Json j) => FactoryData(
        {for (final e in (j['species'] as Map).entries) int.parse('${e.key}'): [for (final v in e.value as List) (v as num).toInt()]},
        {
          for (final e in (j['evolutions'] as Map).entries)
            int.parse('${e.key}'): [
              for (final x in e.value as List) [for (final v in x as List) (v as num).toInt()]
            ]
        },
        [for (final v in j['starters'] as List) (v as num).toInt()],
      );
}

class FactoryRun {
  FactoryRun._();

  static const stats = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
  static const natures = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
    'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky'];
  static const maxTeam = 6, startLevel = 5, maxLevel = 100;

  static Json _zero() => {for (final s in stats) s: 0};
  static Json _add(Map? a, Map? b) => {for (final s in stats) s: ((a?[s] as num?) ?? 0).toInt() + ((b?[s] as num?) ?? 0).toInt()};
  static Json _copy(Json j) => jsonDecode(jsonEncode(j)) as Json;

  /// XP total para chegar ao nível (crescimento médio, n³).
  static int expAt(int level) => level * level * level;

  // ------------------------------------------------------------ sorteio

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// mulberry32, igual ao site: devolve (valor 0..1, próximo estado).
  static (double, int) nextRandom(int state) {
    final t = (state + 0x6d2b79f5) & 0xFFFFFFFF;
    var r = _imul(t ^ (t >> 15), t | 1);
    r = (r ^ ((r + _imul(r ^ (r >> 7), r | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    return (((r ^ (r >> 14)) & 0xFFFFFFFF) / 4294967296, t);
  }

  /// Um sorteador que avança run['seed'].
  static double Function() _dice(Json run) => () {
        final (value, seed) = nextRandom((run['seed'] as num).toInt());
        run['seed'] = seed;
        return value;
      };
  static T _pick<T>(List<T> list, double Function() rand) => list[(rand() * list.length).floor()];

  // ------------------------------------------------------------ itens e cartas

  static const heldBonus = <String, Map<String, int>>{
    'leftovers': {'hp': 12}, 'sitrus-berry': {'hp': 10}, 'life-orb': {'atk': 6, 'spa': 6}, 'expert-belt': {'atk': 5, 'spa': 5},
    'choice-band': {'atk': 10}, 'muscle-band': {'atk': 6}, 'choice-specs': {'spa': 10}, 'wise-glasses': {'spa': 6},
    'choice-scarf': {'spe': 10}, 'assault-vest': {'spd': 10}, 'rocky-helmet': {'def': 10}, 'focus-sash': {'def': 5, 'spd': 5},
  };
  static const vitamins = {'hp-up': 'hp', 'protein': 'atk', 'iron': 'def', 'calcium': 'spa', 'zinc': 'spd', 'carbos': 'spe'};
  static final shop = <String, int>{
    'rare-candy': 150,
    for (final k in vitamins.keys) k: 120,
    'bottle-cap': 250,
    for (final k in heldBonus.keys) k: 300,
  };
  static const vitaminPoints = 6, bottleCapPoints = 3;

  /// Cartas de bônus (a cada 10 andares, escolhe 1 de 3). Igual ao site.
  static const cards = <String, ({String label, Map<String, int>? team, int levels, String? mult, double by})>{
    'atk': (label: '+8 de Ataque e Ataque Especial para o time todo', team: {'atk': 8, 'spa': 8}, levels: 0, mult: null, by: 0),
    'def': (label: '+8 de Defesa e Defesa Especial para o time todo', team: {'def': 8, 'spd': 8}, levels: 0, mult: null, by: 0),
    'hp': (label: '+15 de HP para o time todo', team: {'hp': 15}, levels: 0, mult: null, by: 0),
    'spe': (label: '+8 de Velocidade para o time todo', team: {'spe': 8}, levels: 0, mult: null, by: 0),
    'level': (label: '+3 níveis para o time todo', team: null, levels: 3, mult: null, by: 0),
    'money': (label: '+50% de dinheiro por Pokémon derrotado', team: null, levels: 0, mult: 'money', by: 0.5),
    'exp': (label: '+50% de XP por Pokémon derrotado', team: null, levels: 0, mult: 'exp', by: 0.5),
    'sale': (label: 'Loja 25% mais barata', team: null, levels: 0, mult: 'shop', by: -0.25),
  };

  // ------------------------------------------------------------ meta

  static Json empty() => {'best': 0, 'coins': 0, 'owned': <int>[], 'run': null};
  static Json of(Map? league) => {...empty(), ...?(league?['factory'] is Map ? _copy(Map<String, dynamic>.from(league!['factory'] as Map)) : null)};

  static int pokemonPrice(int bst) => math.max(20, ((math.pow(math.max(0, bst - 250), 1.5) / 10 / 5).round() * 5));

  static List<int> startersOf(Json factory, FactoryData data) =>
      [...data.starters, for (final id in (factory['owned'] as List)) if (!data.starters.contains(id)) (id as num).toInt()];

  static Json? buyPokemon(Json factory, FactoryData data, int id) {
    final info = data.species[id];
    final owned = [for (final x in factory['owned'] as List) (x as num).toInt()];
    if (info == null || owned.contains(id) || data.starters.contains(id)) return null;
    final price = pokemonPrice(info[1]);
    if ((factory['coins'] as num) < price) return null;
    return {...factory, 'coins': (factory['coins'] as num).toInt() - price, 'owned': [...owned, id]};
  }

  static int runCoins(Json run) => ((run['floor'] as num).toInt() - 1) * 5 + (run['defeated'] as num).toInt() * 2;

  // ------------------------------------------------------------ Pokémon da corrida

  static Json newMon(int id, int level, double Function() rand, [int minIv = 0]) => {
        'id': id, 'level': level, 'exp': expAt(level),
        'ivs': {for (final s in stats) s: minIv + (rand() * (32 - minIv)).floor()},
        'nature': _pick(natures, rand),
        'item': null, 'extras': <String>[], 'bonus': _zero(),
      };

  /// Sobe para o nível (com as evoluções que ele alcançar): (mon, evoluiu para).
  static (Json, int?) levelTo(Json mon, int level, FactoryData data, double Function() rand) {
    var out = {...mon, 'level': math.min(maxLevel, level)};
    out['exp'] = math.max((out['exp'] as num? ?? 0).toInt(), expAt(out['level'] as int));
    int? evolved;
    for (var guard = 0; guard < 3; guard++) {
      final options = [for (final e in data.evolutions[(out['id'] as num).toInt()] ?? const <List<int>>[]) if ((out['level'] as int) >= e[1]) e];
      if (options.isEmpty) break;
      final to = _pick(options, rand)[0];
      out = {...out, 'id': to};
      evolved = to;
    }
    return (out, evolved);
  }

  static (Json, int, int?) _gainExp(Json mon, int exp, FactoryData data, double Function() rand) {
    final total = (mon['exp'] as num).toInt() + exp;
    final from = (mon['level'] as num).toInt();
    var level = from;
    while (level < maxLevel && total >= expAt(level + 1)) {
      level++;
    }
    if (level > from) {
      final (out, evolved) = levelTo({...mon, 'exp': total}, level, data, rand);
      return (out, from, evolved);
    }
    return ({...mon, 'exp': total}, from, null);
  }

  // ------------------------------------------------------------ andares

  static Json encounterFor(FactoryData data, int floor, double Function() rand) {
    // Começa fácil (nível 2 a 3 no 1º andar) e chega perto do 100 no andar 100.
    final level = math.min(maxLevel, math.max(2, (1 + floor * 0.9 + rand() * 2).floor()));
    final r = rand();
    final kind = floor >= 10 && r < 0.04 ? 'legendary' : r < 0.36 ? 'trainer' : 'wild';
    final entries = [for (final e in data.species.entries) (id: e.key, bst: e.value[1], rarity: e.value[2])];
    final budget = math.min(720, 290 + floor * 7);
    int pick(List<({int id, int bst, int rarity})> pool) {
      final fit = [for (final p in pool) if (p.bst <= budget && p.bst >= budget - 160) p];
      if (fit.isNotEmpty) return _pick(fit, rand).id;
      final near = [...pool]..sort((a, b) => (a.bst - budget).abs().compareTo((b.bst - budget).abs()));
      return _pick(near.take(20).toList(), rand).id;
    }

    final common = [for (final p in entries) if (p.rarity == 0 || p.rarity == 3) p];
    final iv = math.min(31, floor ~/ 2);
    Json foe(int id, int lvl) => {'id': id, 'level': lvl.clamp(1, maxLevel), 'iv': iv};
    if (kind == 'legendary') {
      final legends = [for (final p in entries) if (p.rarity == 1 || p.rarity == 2) p];
      return {'kind': kind, 'foes': [foe(_pick(legends, rand).id, level + 3)]};
    }
    if (kind == 'trainer') {
      final count = math.min(maxTeam, 1 + floor ~/ 8 + (rand() < 0.3 ? 1 : 0));
      final foes = [for (var i = 0; i < count; i++) foe(pick(common), level - (rand() * 3).floor())];
      return {'kind': kind, 'foes': foes, 'trainerSeed': (rand() * 1e9).floor()};
    }
    return {'kind': kind, 'foes': [foe(pick(common), level)]};
  }

  static Json? startRun(Json factory, FactoryData data, int id, int seed) {
    if (!startersOf(factory, data).contains(id)) return null;
    final run = <String, dynamic>{
      'seed': seed & 0xFFFFFFFF, 'floor': 1, 'money': 0, 'defeated': 0, 'team': <Json>[], 'teamBonus': _zero(),
      'mult': {'money': 1, 'exp': 1, 'shop': 1}, 'cards': <String>[], 'encounter': null, 'pending': null,
    };
    final rand = _dice(run);
    // O inicial vem com IVs bons (15 a 31).
    run['team'] = [newMon(id, startLevel, rand, 15)];
    run['encounter'] = encounterFor(data, 1, rand);
    return run;
  }

  static List<Json> teamOf(Json run) => [for (final m in run['team'] as List) Map<String, dynamic>.from(m as Map)];
  static List<Json> foesOf(Json run) => [for (final f in (run['encounter']?['foes'] as List?) ?? const []) Map<String, dynamic>.from(f as Map)];
  static double _mult(Json run, String k) => ((run['mult'] as Map)[k] as num).toDouble();

  /// Venceu o andar: XP e dinheiro por Pokémon derrotado, depois captura/carta/loja (pending).
  static Json winFloor(Json run, FactoryData data) {
    final out = _copy(run);
    final rand = _dice(out);
    final kind = run['encounter']['kind'] as String;
    final foes = foesOf(run);
    final trainer = kind == 'trainer';
    var exp = 0, money = 0;
    for (final f in foes) {
      final level = (f['level'] as num).toInt();
      exp += ((data.species[(f['id'] as num).toInt()]?[0] ?? 60) * level / 7 * (trainer ? 1.5 : 1) * _mult(out, 'exp')).floor();
      money += (level * 8 * (trainer ? 2 : 1) * _mult(out, 'money')).floor();
    }
    final levels = <Json>[];
    final team = teamOf(out);
    for (var i = 0; i < team.length; i++) {
      final (mon, from, evolved) = _gainExp(team[i], exp, data, rand);
      if ((mon['level'] as int) > from || evolved != null) levels.add({'index': i, 'from': from, 'to': mon['level'], 'evolved': evolved});
      team[i] = mon;
    }
    out['team'] = team;
    out['money'] = (out['money'] as num).toInt() + money;
    out['defeated'] = (out['defeated'] as num).toInt() + foes.length;
    final cleared = (out['floor'] as num).toInt();
    out['floor'] = cleared + 1;
    out['pending'] = {
      'exp': exp, 'money': money, 'levels': levels,
      'capture': trainer ? null : foes.first,
      'cards': cleared % 10 == 0 ? _pickCards(rand) : null,
      'shop': cleared % 5 == 0 || rand() < 0.2 ? _pickShop(rand) : null,
    };
    out['encounter'] = null;
    return out;
  }

  static List<String> _pickCards(double Function() rand) {
    final ids = cards.keys.toList();
    final out = <String>[];
    while (out.length < 3) {
      final id = _pick(ids, rand);
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  static List<String> _pickShop(double Function() rand) {
    final ids = shop.keys.toList();
    final out = ['rare-candy'];
    while (out.length < 5) {
      final id = _pick(ids, rand);
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  static Json? pendingOf(Json run) => run['pending'] == null ? null : Map<String, dynamic>.from(run['pending'] as Map);

  /// Captura o selvagem derrotado (replace: posição a trocar com o time cheio).
  static Json capture(Json run, [int? replace]) {
    final foe = pendingOf(run)?['capture'];
    if (foe == null) return run;
    final out = _copy(run);
    final rand = _dice(out);
    final mon = newMon((foe['id'] as num).toInt(), (foe['level'] as num).toInt(), rand);
    final team = teamOf(out);
    if (team.length < maxTeam) {
      team.add(mon);
    } else if (replace != null && replace >= 0 && replace < team.length) {
      team[replace] = mon;
    } else {
      return run;
    }
    out['team'] = team;
    (out['pending'] as Map)['capture'] = null;
    return out;
  }

  static Json skipCapture(Json run) {
    if (run['pending'] == null) return run;
    final out = _copy(run);
    (out['pending'] as Map)['capture'] = null;
    return out;
  }

  static Json takeCard(Json run, String id, FactoryData data) {
    final card = cards[id];
    if (card == null || !((pendingOf(run)?['cards'] as List?)?.contains(id) ?? false)) return run;
    final out = _copy(run);
    out['cards'] = [...(out['cards'] as List), id];
    (out['pending'] as Map)['cards'] = null;
    if (card.team != null) out['teamBonus'] = _add(out['teamBonus'] as Map, card.team);
    if (card.mult != null) (out['mult'] as Map)[card.mult!] = _mult(out, card.mult!) + card.by;
    if (card.levels > 0) {
      final rand = _dice(out);
      out['team'] = [for (final m in teamOf(out)) levelTo(m, (m['level'] as num).toInt() + card.levels, data, rand).$1];
    }
    return out;
  }

  static int shopPrice(Json run, String id) => (shop[id]! * _mult(run, 'shop')).round();

  static Json? buyItem(Json run, String id, int index, FactoryData data) {
    final price = shopPrice(run, id);
    final team = teamOf(run);
    if (index < 0 || index >= team.length || !((pendingOf(run)?['shop'] as List?)?.contains(id) ?? false) || (run['money'] as num) < price) return null;
    final out = _copy(run);
    final mon = team[index];
    out['money'] = (out['money'] as num).toInt() - price;
    if (id == 'rare-candy') {
      if ((mon['level'] as num) >= maxLevel) return null;
      team[index] = levelTo(mon, (mon['level'] as num).toInt() + 1, data, _dice(out)).$1;
    } else if (vitamins.containsKey(id)) {
      team[index] = {...mon, 'bonus': _add(mon['bonus'] as Map, {vitamins[id]!: vitaminPoints})};
    } else if (id == 'bottle-cap') {
      team[index] = {...mon, 'bonus': _add(mon['bonus'] as Map, {for (final s in stats) s: bottleCapPoints})};
    } else if (heldBonus.containsKey(id)) {
      // Sem item: vira o segurado; já com um: vira pontos (sem limite de itens).
      team[index] = mon['item'] != null
          ? {...mon, 'extras': [...(mon['extras'] as List), id], 'bonus': _add(mon['bonus'] as Map, heldBonus[id])}
          : {...mon, 'item': id};
    } else {
      return null;
    }
    out['team'] = team;
    return out;
  }

  static Json nextFloor(Json run, FactoryData data) {
    final out = _copy(run)..['pending'] = null;
    out['encounter'] = encounterFor(data, (out['floor'] as num).toInt(), _dice(out));
    return out;
  }

  /// Perdeu: a corrida acaba; a pontuação vira moedas e o recorde fica salvo.
  static Json endRun(Json factory, Json run) {
    final coins = runCoins(run);
    return {
      ...factory,
      'coins': (factory['coins'] as num).toInt() + coins,
      'best': math.max((factory['best'] as num).toInt(), (run['floor'] as num).toInt() - 1),
      'run': null,
      'last': {'floor': (run['floor'] as num).toInt() - 1, 'coins': coins},
    };
  }

  // ------------------------------------------------------------ para a batalha

  /// Golpes que ele sabe no nível (os aprendidos por nível até ali), os melhores 4. Igual ao site.
  static List<String> movesAt(List formMoves, int level, List<String> types, Map<String, Map<String, dynamic>> moves) {
    final levelUp = [for (final m in formMoves) if (m is List && m[1] == 'level-up' && (m[2] as num) <= level) m]
      ..sort((a, b) => (a[2] as num).compareTo(b[2] as num));
    final learned = <String>[];
    for (final m in levelUp) {
      final slug = m[0] as String;
      if (!learned.contains(slug) && moves.containsKey(slug)) learned.add(slug);
    }
    double power(String s) {
      final m = moves[s]!;
      final p = (m['power'] as num?) ?? 0;
      final category = '${m['damage_class'] ?? m['category']}';
      if (category == 'status' || p <= 0) return 0;
      return p * (types.contains(m['type']) ? 1.5 : 1) * (((m['accuracy'] as num?) ?? 100) / 100);
    }

    final damaging = [for (final s in learned) if (power(s) > 0) s]..sort((a, b) => power(b).compareTo(power(a)));
    final chosen = <String>[];
    for (final s in damaging) {
      if (chosen.length < 3 && !chosen.any((c) => moves[c]!['type'] == moves[s]!['type'])) chosen.add(s);
    }
    for (final s in damaging) {
      if (chosen.length < 3 && !chosen.contains(s)) chosen.add(s);
    }
    for (final s in learned.reversed) {
      if (chosen.length < 4 && !chosen.contains(s)) chosen.add(s);
    }
    return chosen.isEmpty ? ['tackle'] : chosen;
  }

  /// A Bolsa de cada lado: a sua é a padrão; selvagem não tem itens; treinador tem poucas poções. Igual ao site.
  static List<Map<String, int>?> bagsFor(Json run) {
    final floor = (run['floor'] as num).toInt();
    final trainer = run['encounter']?['kind'] == 'trainer';
    return [
      null,
      trainer
          ? {'potion': math.min(3, 1 + floor ~/ 15), 'super-potion': floor >= 20 ? 1 : 0, 'hyper-potion': floor >= 40 ? 1 : 0, 'revive': 0}
          : {'potion': 0, 'super-potion': 0, 'hyper-potion': 0, 'revive': 0},
    ];
  }

  /// O Pokémon da corrida como membro de time (TurnBattleSetup.mons).
  static (int, Json) memberOf(Json run, Json mon, List<String> moveList) => (
        (mon['id'] as num).toInt(),
        {
          'level': mon['level'], 'levelCap': maxLevel, 'nature': mon['nature'], 'ivs': mon['ivs'], 'item': mon['item'] ?? '',
          'moves': moveList, 'lockMoves': true, 'bonus': _add(mon['bonus'] as Map, run['teamBonus'] as Map),
        }
      );

  static (int, Json) foeMember(Json foe, List<String> moveList) => (
        (foe['id'] as num).toInt(),
        {
          'level': foe['level'], 'levelCap': maxLevel, 'ivs': {for (final s in stats) s: foe['iv']}, 'moves': moveList, 'lockMoves': true,
        }
      );
}
