// lib/services/factory_run.dart
//
// Battle Factory, um roguelike: você escolhe um inicial no nível 5 e vai
// subindo andares (sem fim). Cada andar é um Pokémon selvagem (dá para
// capturar com Poké Ball: começa com 5, as outras se compram), um treinador
// ou, mais raro, um lendário; a cada 10 andares vem um chefe (os líderes de
// ginásio com o rival e os vilões no meio, a Elite Four e o Campeão de um jogo
// sorteado, na ordem da história; depois do Campeão, outro jogo; os times deles
// crescem conforme a corrida sobe). O time NÃO é curado entre os andares: o HP e
// quem desmaiou continuam (Bolsa, loja e, com 5% de chance, a Enfermeira Joy).
// Cada Pokémon derrotado dá XP e EVs (só para quem está de pé) e dinheiro
// para a loja, que aparece a cada 5 andares (uma delas logo antes do chefe)
// e com 20% de chance nos outros. Depois de cada chefe, uma carta de bônus.
// Sem limite de nível, IVs, EVs ou itens: um item é o segurado (efeito de
// verdade) e os outros dão uma versão bem mais fraca do bônus (porcentagem).
// Selvagens podem vir shiny (+10% nos atributos); capturar um inicial shiny
// libera o shiny dele para começar (também se compra com moedas, bem caro).
// Perdeu: a pontuação vira moedas, que compram Pokémon para começar.
// A corrida fica na conta (league.factory) no mesmo formato e com o mesmo
// sorteio do site (web-site/src/lib/factoryRun.js, onde está a conta da
// dificuldade): começa no app e continua no site.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

typedef Json = Map<String, dynamic>;

class FactoryData {
  /// id → [xp base, total de atributos, raridade (0 comum, 1 lendário, 2 mítico, 3 bebê), [EVs que dá], [tipos]].
  final Map<int, List> species;

  /// id → [[evolui para, nível], ...].
  final Map<int, List<List<int>>> evolutions;
  final List<int> starters;

  /// Chefes por jogo, na ordem da história: [{region, game, leaders: [{id, name, trainer, kind, team, pool}]}].
  final List<Json> bosses;

  /// Formas regionais dos chefes: id da forma → espécie.
  final Map<int, int> forms;
  const FactoryData(this.species, this.evolutions, this.starters, [this.bosses = const [], this.forms = const {}]);

  static Future<FactoryData>? _loading;
  static Future<FactoryData> load() => _loading ??= rootBundle.loadString('assets/database/factory.json').then((t) => parse(jsonDecode(t) as Json));

  static FactoryData parse(Json j) {
    final species = {for (final e in (j['species'] as Map).entries) int.parse('${e.key}'): e.value as List};
    return FactoryData(
      // Em ordem de id, como o site (Object.entries).
      Map.fromEntries(species.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      {
        for (final e in (j['evolutions'] as Map).entries)
          int.parse('${e.key}'): [
            for (final x in e.value as List) [for (final v in x as List) (v as num).toInt()]
          ]
      },
      [for (final v in j['starters'] as List) (v as num).toInt()],
      [for (final b in (j['bosses'] as List?) ?? const []) Map<String, dynamic>.from(b as Map)],
      {for (final e in ((j['forms'] as Map?) ?? const {}).entries) int.parse('${e.key}'): (e.value as num).toInt()},
    );
  }

  /// Espécie (para XP, EVs e evolução) de um id, que pode ser uma forma regional de chefe.
  List? speciesOf(int id) => species[id] ?? species[forms[id]];
  int bstOf(int id) => ((speciesOf(id)?[1] as num?) ?? 400).toInt();
}

class FactoryRun {
  FactoryRun._();

  static const stats = ['hp', 'atk', 'def', 'spa', 'spd', 'spe'];
  static const natures = ['Hardy', 'Lonely', 'Brave', 'Adamant', 'Naughty', 'Bold', 'Docile', 'Relaxed', 'Impish', 'Lax', 'Timid', 'Hasty', 'Serious',
    'Jolly', 'Naive', 'Modest', 'Mild', 'Quiet', 'Bashful', 'Rash', 'Calm', 'Gentle', 'Sassy', 'Careful', 'Quirky'];
  static const maxTeam = 6, startLevel = 5, startBalls = 5, bossEvery = 10;

  /// A Bolsa do começo da corrida (os itens gastos na batalha não voltam).
  static const startBag = {'potion': 4, 'super-potion': 1, 'hyper-potion': 0, 'max-potion': 0, 'revive': 1};
  static const bagItems = ['potion', 'super-potion', 'hyper-potion', 'max-potion', 'revive'];

  /// Quanto cada item da Bolsa cura (parte do HP máximo; igual na batalha: healPct do motor).
  static const healShare = {'potion': 0.25, 'super-potion': 0.5, 'hyper-potion': 0.75, 'max-potion': 1.0};
  static const joyChance = 0.05, shinyChance = 0.02, shinyBoost = 0.1;

  static Json _zero() => {for (final s in stats) s: 0};
  static Json _add(Map? a, Map? b) => {for (final s in stats) s: ((a?[s] as num?) ?? 0).toInt() + ((b?[s] as num?) ?? 0).toInt()};
  static Json _copy(Json j) => jsonDecode(jsonEncode(j)) as Json;
  static double _round3(num n) => (n * 1000).round() / 1000;
  // Potências com multiplicação e raiz: o mesmo resultado do site.
  static double _pow15(double x) => x * math.sqrt(x);
  static double _pow6(double x) {
    final x2 = x * x;
    return x2 * x2 * x2;
  }

  static int _int(Object? v) => (v as num).toInt();

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
        final (value, seed) = nextRandom(_int(run['seed']));
        run['seed'] = seed;
        return value;
      };
  static T _pick<T>(List<T> list, double Function() rand) => list[(rand() * list.length).floor()];

  // ------------------------------------------------------------ dificuldade

  static int foeLevelAt(int floor) => 2 + ((floor - 1) * 0.8).floor();
  static int foeEvsAt(int floor) => 2 * floor;
  static int foeIvsAt(int floor) => math.min(31, floor ~/ 2) + math.max(0, ((floor - 100) / 10).floor());
  static double foeBoostAt(int floor) => (math.max(0, floor - 50) * 0.002 * 1000).round() / 1000;
  static double priceScale(int floor) => 1 + (floor - 1) / 20;
  static int speciesBudget(int floor) => 290 + floor * 7;

  // ------------------------------------------------------------ itens e cartas

  /// Itens de segurar: o principal tem o efeito de verdade; cada um a mais dá esta porcentagem.
  static const heldBoost = <String, Map<String, double>>{
    'choice-band': {'atk': 0.05}, 'choice-specs': {'spa': 0.05}, 'choice-scarf': {'spe': 0.05},
    'life-orb': {'atk': 0.03, 'spa': 0.03}, 'expert-belt': {'atk': 0.02, 'spa': 0.02}, 'muscle-band': {'atk': 0.02}, 'wise-glasses': {'spa': 0.02},
    'leftovers': {'hp': 0.04}, 'sitrus-berry': {'hp': 0.03}, 'assault-vest': {'spd': 0.05}, 'rocky-helmet': {'def': 0.04},
    'eviolite': {'def': 0.04, 'spd': 0.04}, 'focus-sash': {'hp': 0.02, 'def': 0.01, 'spd': 0.01}, 'quick-claw': {'spe': 0.03},
  };
  static const vitamins = {'hp-up': 'hp', 'protein': 'atk', 'iron': 'def', 'calcium': 'spa', 'zinc': 'spd', 'carbos': 'spe'};
  static const vitaminEvs = 24, bottleCapIvs = 3;

  /// Preço no 1º andar (priceScale aumenta com o andar). A ordem é a do site.
  static final shop = <String, int>{
    'poke-ball': 50,
    'potion': 40, 'super-potion': 90, 'hyper-potion': 160, 'max-potion': 300, 'revive': 180,
    'rare-candy': 120,
    for (final k in vitamins.keys) k: 90,
    'bottle-cap': 200,
    for (final k in heldBoost.keys) k: 250,
  };

  /// Cartas de bônus (depois de cada chefe, escolhe 1 de 3). Igual ao site.
  static const cards = <String, ({String label, Map<String, double>? team, int levels, String? mult, double by, int balls, bool heal})>{
    'atk': (label: '+6% de Ataque e Ataque Especial para o time todo', team: {'atk': 0.06, 'spa': 0.06}, levels: 0, mult: null, by: 0, balls: 0, heal: false),
    'def': (label: '+6% de Defesa e Defesa Especial para o time todo', team: {'def': 0.06, 'spd': 0.06}, levels: 0, mult: null, by: 0, balls: 0, heal: false),
    'hp': (label: '+8% de HP para o time todo', team: {'hp': 0.08}, levels: 0, mult: null, by: 0, balls: 0, heal: false),
    'spe': (label: '+6% de Velocidade para o time todo', team: {'spe': 0.06}, levels: 0, mult: null, by: 0, balls: 0, heal: false),
    'level': (label: '+3 níveis para o time todo', team: null, levels: 3, mult: null, by: 0, balls: 0, heal: false),
    'money': (label: '+50% de dinheiro por Pokémon derrotado', team: null, levels: 0, mult: 'money', by: 0.5, balls: 0, heal: false),
    'exp': (label: '+50% de XP por Pokémon derrotado', team: null, levels: 0, mult: 'exp', by: 0.5, balls: 0, heal: false),
    'sale': (label: 'Loja 20% mais barata', team: null, levels: 0, mult: 'shop', by: -0.2, balls: 0, heal: false),
    'balls': (label: '+5 Poké Balls', team: null, levels: 0, mult: null, by: 0, balls: 5, heal: false),
    'heal': (label: 'Cura o time todo e +1 Max Potion', team: null, levels: 0, mult: null, by: 0, balls: 0, heal: true),
  };

  // ------------------------------------------------------------ meta

  static Json empty() => {'best': 0, 'coins': 0, 'owned': <int>[], 'shinies': <int>[], 'run': null};
  static Json of(Map? league) => {...empty(), ...?(league?['factory'] is Map ? _copy(Map<String, dynamic>.from(league!['factory'] as Map)) : null)};

  static int pokemonPrice(int bst) => math.max(20, ((_pow15(math.max(0, bst - 250).toDouble()) / 10 / 5).round() * 5));

  static List<int> startersOf(Json factory, FactoryData data) =>
      [...data.starters, for (final id in (factory['owned'] as List)) if (!data.starters.contains(id)) _int(id)];
  static List<int> shiniesOf(Json factory) => [for (final x in (factory['shinies'] as List?) ?? const []) _int(x)];

  static Json? buyPokemon(Json factory, FactoryData data, int id) {
    final info = data.species[id];
    final owned = [for (final x in factory['owned'] as List) _int(x)];
    if (info == null || owned.contains(id) || data.starters.contains(id)) return null;
    final price = pokemonPrice(_int(info[1]));
    if ((factory['coins'] as num) < price) return null;
    return {...factory, 'coins': _int(factory['coins']) - price, 'owned': [...owned, id]};
  }

  /// Preço para transformar um inicial em shiny (bem caro).
  static int shinyPrice(int bst) => math.max(3000, pokemonPrice(bst) * 20);

  static Json? buyShiny(Json factory, FactoryData data, int id) {
    final info = data.species[id];
    final shinies = shiniesOf(factory);
    if (info == null || shinies.contains(id) || !startersOf(factory, data).contains(id)) return null;
    final price = shinyPrice(_int(info[1]));
    if ((factory['coins'] as num) < price) return null;
    return {...factory, 'coins': _int(factory['coins']) - price, 'shinies': [...shinies, id]};
  }

  /// Capturou um shiny: se é um dos iniciais dele, libera o shiny para começar.
  static Json unlockShiny(Json factory, FactoryData data, Map? mon) {
    final shinies = shiniesOf(factory);
    if (mon == null || mon['shiny'] != true) return factory;
    final id = _int(mon['id']);
    if (shinies.contains(id) || !startersOf(factory, data).contains(id)) return factory;
    return {...factory, 'shinies': [...shinies, id]};
  }

  static int runCoins(Json run) => (_int(run['floor']) - 1) * 5 + _int(run['defeated']) * 2 + ((run['bosses'] as num?) ?? 0).toInt() * 25;

  // ------------------------------------------------------------ Pokémon da corrida

  static Json newMon(int id, int level, double Function() rand, [int minIv = 0, bool shiny = false]) => {
        'id': id, 'level': level, 'exp': expAt(level), if (shiny) 'shiny': true,
        'ivs': {for (final s in stats) s: minIv + (rand() * (32 - minIv)).floor()},
        'evs': _zero(),
        'nature': _pick(natures, rand),
        'item': null, 'extras': <String>[], 'hp': 1,
      };

  /// Sobe para o nível (com as evoluções que ele alcançar): (mon, evoluiu para).
  static (Json, int?) levelTo(Json mon, int level, FactoryData data, double Function() rand) {
    var out = {...mon, 'level': math.max(1, level)};
    out['exp'] = math.max(((out['exp'] as num?) ?? 0).toInt(), expAt(out['level'] as int));
    int? evolved;
    for (var guard = 0; guard < 3; guard++) {
      final options = [for (final e in data.evolutions[_int(out['id'])] ?? const <List<int>>[]) if ((out['level'] as int) >= e[1]) e];
      if (options.isEmpty) break;
      final to = _pick(options, rand)[0];
      out = {...out, 'id': to};
      evolved = to;
    }
    return (out, evolved);
  }

  /// XP de derrotar um adversário (a conta está no site). Igual ao site.
  static int expFor(int baseExp, int foeLevel, int level, [double factor = 1]) {
    final scale = _pow6((foeLevel + 10) / (level + 10));
    final species = math.min(1.6, math.max(0.6, math.sqrt(baseExp / 100)));
    return (5 * foeLevel * foeLevel * species * scale * factor).floor();
  }

  static (Json, int, int?) _gainExp(Json mon, int exp, FactoryData data, double Function() rand) {
    final total = _int(mon['exp']) + exp;
    final from = _int(mon['level']);
    var level = from;
    while (total >= expAt(level + 1)) {
      level++;
    }
    if (level > from) {
      final (out, evolved) = levelTo({...mon, 'exp': total}, level, data, rand);
      return (out, from, evolved);
    }
    return ({...mon, 'exp': total}, from, null);
  }

  // ------------------------------------------------------------ andares

  /// O chefe da vez: o jogo sorteado no começo, na ordem da história (líderes com rival e vilões no meio, Elite Four, Campeão).
  static Json bossOf(FactoryData data, Json run) {
    final game = data.bosses[_int(run['boss']['region'])];
    return {'region': game['region'], 'game': game['game'], ...Map<String, dynamic>.from((game['leaders'] as List)[_int(run['boss']['step'])] as Map)};
  }

  /// O time do chefe: o da batalha do jogo e, conforme os andares sobem, completado com os outros que ele usa (até 6). Igual ao site.
  static List<int> bossTeam(Map boss, int floor) {
    final team = [for (final id in boss['team'] as List) _int(id)];
    final want = math.min(maxTeam, math.max(team.length, 2 + floor ~/ 25));
    final given = [for (final id in (boss['pool'] as List?) ?? const []) _int(id)];
    final pool = given.isNotEmpty ? given : [...team];
    final extra = [for (final id in pool) if (!team.contains(id)) id];
    for (var i = 0; team.length < want && pool.isNotEmpty; i++) {
      team.add(i < extra.length ? extra[i] : pool[(i - extra.length) % pool.length]);
    }
    return team;
  }

  static Json encounterFor(FactoryData data, int floor, double Function() rand, [Json? boss]) {
    final level = math.max(2, foeLevelAt(floor) + (rand() * 2).floor());
    final iv = foeIvsAt(floor), ev = foeEvsAt(floor), boost = foeBoostAt(floor);
    Json foe(int id, int lvl, [Json extra = const {}]) => {'id': id, 'level': math.max(2, lvl), 'iv': iv, 'ev': ev, if (boost != 0) 'boost': boost, ...extra};
    if (boss != null) {
      // Os times dos chefes são de Pokémon evoluídos: quem é mais forte que as espécies do andar vem com nível menor.
      final bonus = const {'gym': 1, 'rival': 1, 'villain': 2, 'elite': 2, 'champion': 3}[boss['kind']] ?? 1;
      final team = bossTeam(boss, floor);
      int levelOf(int id, int i) {
        final lvl = level + bonus + (i == team.length - 1 ? 1 : 0);
        return math.max(2, (lvl * _pow15(math.min(1, speciesBudget(floor) / data.bstOf(id)))).round());
      }

      final foes = [for (var i = 0; i < team.length; i++) foe(team[i], levelOf(team[i], i), {'iv': math.max(31, iv), 'ev': (ev * 1.25).round()})];
      return {
        'kind': 'boss', 'foes': foes,
        'boss': {'id': boss['id'], 'name': boss['name'], 'trainer': boss['trainer'], 'kind': boss['kind'], 'region': boss['region'], 'game': boss['game']},
      };
    }
    final r = rand();
    final legendChance = floor >= 15 ? 0.03 + math.min(0.07, (floor - 15) / 2000) : 0.0;
    final kind = r < legendChance ? 'legendary' : r < legendChance + 0.35 ? 'trainer' : 'wild';
    // Nos primeiros andares, nada de Fantasma (imune aos golpes Normal que os iniciais têm no começo).
    final entries = [
      for (final e in data.species.entries)
        if (floor >= 8 || !(e.value.length > 4 && (e.value[4] as List).contains('ghost'))) (id: e.key, bst: _int(e.value[1]), rarity: _int(e.value[2]))
    ];
    final budget = speciesBudget(floor);
    int pick(List<({int id, int bst, int rarity})> pool) {
      final fit = [for (final p in pool) if (p.bst <= budget && p.bst >= math.min(budget, 600) - 160) p];
      if (fit.isNotEmpty) return _pick(fit, rand).id;
      final near = [...pool]..sort((a, b) {
          final d = (a.bst - budget).abs().compareTo((b.bst - budget).abs());
          return d != 0 ? d : a.id.compareTo(b.id);
        });
      return _pick(near.take(20).toList(), rand).id;
    }

    final common = [for (final p in entries) if (p.rarity == 0 || p.rarity == 3) p];
    if (kind == 'legendary') {
      final legends = [for (final p in entries) if (p.rarity == 1 || p.rarity == 2) p];
      final id = _pick(legends, rand).id;
      return {'kind': kind, 'foes': [foe(id, level + 3, rand() < shinyChance ? {'shiny': true} : const {})]};
    }
    if (kind == 'trainer') {
      final count = math.min(maxTeam, 1 + floor ~/ 12 + (rand() < 0.3 ? 1 : 0));
      final foes = <Json>[];
      for (var i = 0; i < count; i++) {
        final id = pick(common);
        foes.add(foe(id, level - (rand() * 3).floor()));
      }
      return {'kind': kind, 'foes': foes, 'trainerSeed': (rand() * 1e9).floor()};
    }
    final id = pick(common);
    return {'kind': kind, 'foes': [foe(id, level, rand() < shinyChance ? {'shiny': true} : const {})]};
  }

  static Json _encounterOf(Json run, FactoryData data, double Function() rand) {
    final floor = _int(run['floor']);
    return encounterFor(data, floor, rand, floor % bossEvery == 0 ? bossOf(data, run) : null);
  }

  static Json? startRun(Json factory, FactoryData data, int id, int seed, [bool shiny = false]) {
    if (!startersOf(factory, data).contains(id) || (shiny && !shiniesOf(factory).contains(id))) return null;
    final run = <String, dynamic>{
      'seed': seed & 0xFFFFFFFF, 'floor': 1, 'money': 0, 'defeated': 0, 'bosses': 0, 'balls': startBalls, 'bag': {...startBag},
      'team': <Json>[], 'teamBoost': _zero(), 'mult': {'money': 1, 'exp': 1, 'shop': 1}, 'cards': <String>[], 'boss': {'region': 0, 'step': 0},
      'encounter': null, 'pending': null,
    };
    final rand = _dice(run);
    // O inicial vem com IVs bons (15 a 31).
    run['team'] = [newMon(id, startLevel, rand, 15, shiny)];
    run['boss'] = {'region': (rand() * data.bosses.length).floor(), 'step': 0};
    run['encounter'] = _encounterOf(run, data, rand);
    return run;
  }

  static List<Json> teamOf(Json run) => [for (final m in run['team'] as List) Map<String, dynamic>.from(m as Map)];
  static List<Json> foesOf(Json run) => [for (final f in (run['encounter']?['foes'] as List?) ?? const []) Map<String, dynamic>.from(f as Map)];
  static double _mult(Json run, String k) => ((run['mult'] as Map)[k] as num).toDouble();
  static double hpOf(Map mon) => ((mon['hp'] as num?) ?? 1).toDouble();
  static Map<String, int> bagOf(Json run) => {for (final id in bagItems) id: (((run['bag'] as Map?)?[id] as num?) ?? 0).toInt()};

  static Json _nextBoss(Json run, FactoryData data, double Function() rand) {
    final region = _int(run['boss']['region']);
    final step = _int(run['boss']['step']) + 1;
    if (step < (data.bosses[region]['leaders'] as List).length) return {'region': region, 'step': step};
    final others = [for (var i = 0; i < data.bosses.length; i++) if (i != region || data.bosses.length == 1) i];
    return {'region': _pick(others, rand), 'step': 0};
  }

  /// Venceu o andar. hp: a parte do HP de cada um do time (na ordem da
  /// corrida) no fim da batalha; bag: a Bolsa que sobrou. Igual ao site.
  static Json winFloor(Json run, FactoryData data, {List<double>? hp, Map<String, int>? bag}) {
    final out = _copy(run);
    final team0 = teamOf(out);
    out['team'] = [for (var i = 0; i < team0.length; i++) {...team0[i], 'hp': hp != null && i < hp.length ? hp[i] : hpOf(team0[i])}];
    out['bag'] = {...(bag ?? Map<String, dynamic>.from(run['bag'] as Map))};
    final rand = _dice(out);
    final kind = run['encounter']['kind'] as String;
    final foes = foesOf(run);
    final factor = kind == 'boss' || kind == 'trainer' ? 1.5 : 1.0;
    final moneyFactor = kind == 'boss' ? 3 : kind == 'trainer' ? 2 : 1;
    var money = 0;
    final evs = _zero();
    for (final f in foes) {
      money += ((_int(f['level']) * 6 + 10) * moneyFactor * _mult(out, 'money')).floor();
      final yields = (data.speciesOf(_int(f['id'])))?.elementAtOrNull(3) as List? ?? const [0, 0, 0, 0, 0, 0];
      for (var i = 0; i < stats.length; i++) {
        evs[stats[i]] = (evs[stats[i]] as int) + _int(yields[i]) * 3;
      }
    }
    final levels = <Json>[];
    var exp = 0;
    final team = teamOf(out);
    for (var i = 0; i < team.length; i++) {
      final m = team[i];
      if (!(hpOf(m) > 0)) continue;
      var gained = 0;
      for (final f in foes) {
        gained += expFor(_int(data.speciesOf(_int(f['id']))?[0] ?? 60), _int(f['level']), _int(m['level']), factor * _mult(out, 'exp'));
      }
      exp = math.max(exp, gained);
      final (mon, from, evolved) = _gainExp({...m, 'evs': _add(m['evs'] as Map?, evs)}, gained, data, rand);
      if (_int(mon['level']) > from || evolved != null) levels.add({'index': i, 'from': from, 'to': mon['level'], 'evolved': evolved});
      team[i] = mon;
    }
    out['team'] = team;
    out['money'] = _int(out['money']) + money;
    out['defeated'] = _int(out['defeated']) + foes.length;
    final cleared = _int(out['floor']);
    out['floor'] = cleared + 1;
    if (kind == 'boss') {
      out['bosses'] = ((out['bosses'] as num?) ?? 0).toInt() + 1;
      out['boss'] = _nextBoss(out, data, rand);
    }
    final joy = rand() < joyChance;
    if (joy) out['team'] = [for (final m in teamOf(out)) {...m, 'hp': 1}];
    final cardsPick = kind == 'boss' ? _pickCards(rand) : null;
    // A loja: garantida a cada 5 andares (logo antes de cada chefe e no meio) e com 20% de chance nos outros.
    final shopPick = cleared % 5 == 4 || rand() < 0.2 ? _pickShop(rand) : null;
    out['pending'] = {
      'exp': exp, 'money': money, 'levels': levels, 'joy': joy,
      'capture': kind == 'wild' || kind == 'legendary' ? foes.first : null,
      'cards': cardsPick,
      'shop': shopPick,
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
    final ids = [for (final id in shop.keys) if (id != 'poke-ball') id];
    final out = ['poke-ball', _pick(const ['potion', 'super-potion', 'hyper-potion', 'max-potion', 'revive'], rand)];
    while (out.length < 6) {
      final id = _pick(ids, rand);
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  static Json? pendingOf(Json run) => run['pending'] == null ? null : Map<String, dynamic>.from(run['pending'] as Map);

  /// Captura o selvagem derrotado com uma Poké Ball (replace: posição a trocar com o time cheio).
  static Json capture(Json run, [int? replace]) {
    final foe = pendingOf(run)?['capture'];
    if (foe == null || !(((run['balls'] as num?) ?? 0) > 0)) return run;
    final out = _copy(run);
    out['balls'] = _int(out['balls']) - 1;
    final rand = _dice(out);
    final mon = newMon(_int(foe['id']), _int(foe['level']), rand, 0, foe['shiny'] == true);
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
    if (card.team != null) {
      final boost = (out['teamBoost'] as Map?) ?? const {};
      out['teamBoost'] = {for (final s in stats) s: _round3(((boost[s] as num?) ?? 0) + (card.team![s] ?? 0))};
    }
    if (card.mult != null) (out['mult'] as Map)[card.mult!] = math.max(0.4, _round3(_mult(out, card.mult!) + card.by));
    if (card.balls > 0) out['balls'] = _int(out['balls']) + card.balls;
    if (card.heal) {
      out['team'] = [for (final m in teamOf(out)) {...m, 'hp': 1}];
      final bag = Map<String, dynamic>.from(out['bag'] as Map);
      bag['max-potion'] = ((bag['max-potion'] as num?) ?? 0).toInt() + 1;
      out['bag'] = bag;
    }
    if (card.levels > 0) {
      final rand = _dice(out);
      out['team'] = [for (final m in teamOf(out)) levelTo(m, _int(m['level']) + card.levels, data, rand).$1];
    }
    return out;
  }

  /// Preço do item no andar (com o desconto das cartas). O Rare Candy também sobe com o nível do time.
  static int shopPrice(Json run, String id) {
    final top = id == 'rare-candy' ? teamOf(run).fold(startLevel, (int a, m) => math.max(a, _int(m['level']))) : startLevel;
    return math.max(1, (shop[id]! * priceScale(_int(run['floor'])) * (top / startLevel) * _mult(run, 'shop')).round());
  }

  /// Compra um item da loja (index: o Pokémon que recebe; itens da Bolsa e Poké Ball não precisam). null se não dá.
  static Json? buyItem(Json run, String id, int index, FactoryData data) {
    if (!shop.containsKey(id)) return null;
    final price = shopPrice(run, id);
    if (!((pendingOf(run)?['shop'] as List?)?.contains(id) ?? false) || (run['money'] as num) < price) return null;
    final out = _copy(run);
    out['money'] = _int(out['money']) - price;
    if (id == 'poke-ball') return out..['balls'] = _int(out['balls']) + 1;
    if (bagItems.contains(id)) {
      final bag = Map<String, dynamic>.from(out['bag'] as Map);
      bag[id] = ((bag[id] as num?) ?? 0).toInt() + 1;
      return out..['bag'] = bag;
    }
    final team = teamOf(out);
    if (index < 0 || index >= team.length) return null;
    final mon = team[index];
    if (id == 'rare-candy') {
      team[index] = levelTo(mon, _int(mon['level']) + 1, data, _dice(out)).$1;
    } else if (vitamins.containsKey(id)) {
      team[index] = {...mon, 'evs': _add(mon['evs'] as Map?, {vitamins[id]!: vitaminEvs})};
    } else if (id == 'bottle-cap') {
      team[index] = {...mon, 'ivs': _add(mon['ivs'] as Map?, {for (final s in stats) s: bottleCapIvs})};
    } else if (heldBoost.containsKey(id)) {
      // Sem item: vira o segurado; já com um: entra nos extras (sem limite de itens).
      team[index] = mon['item'] != null ? {...mon, 'extras': [...((mon['extras'] as List?) ?? const []), id]} : {...mon, 'item': id};
    } else {
      return null;
    }
    out['team'] = team;
    return out;
  }

  /// Troca o item principal pelo extra da posição (o principal volta para os extras).
  static Json setMainItem(Json run, int index, int extra) {
    final team = teamOf(run);
    if (index < 0 || index >= team.length) return run;
    final mon = team[index];
    final extras = [for (final x in (mon['extras'] as List?) ?? const []) '$x'];
    if (extra < 0 || extra >= extras.length) return run;
    final id = extras[extra];
    if (mon['item'] != null) {
      extras[extra] = '${mon['item']}';
    } else {
      extras.removeAt(extra);
    }
    team[index] = {...mon, 'item': id, 'extras': extras};
    return {...run, 'team': team};
  }

  /// Usa um item da Bolsa fora da batalha (poção em quem está ferido, Revive em quem desmaiou). null se não dá.
  static Json? applyBagItem(Json run, String id, int index) {
    final team = teamOf(run);
    final bag = bagOf(run);
    if (index < 0 || index >= team.length || !((bag[id] ?? 0) > 0)) return null;
    final hp = hpOf(team[index]);
    double next;
    if (id == 'revive') {
      if (hp > 0) return null;
      next = 0.5;
    } else if (healShare.containsKey(id)) {
      if (!(hp > 0) || hp >= 1) return null;
      next = math.min(1, _round3(hp + healShare[id]!));
    } else {
      return null;
    }
    team[index] = {...team[index], 'hp': next};
    return {...run, 'team': team, 'bag': {...Map<String, dynamic>.from(run['bag'] as Map), id: bag[id]! - 1}};
  }

  /// O time inteiro desmaiado (não dá para seguir).
  static bool teamDown(Json run) => teamOf(run).every((m) => !(hpOf(m) > 0));

  static Json nextFloor(Json run, FactoryData data) {
    final out = _copy(run)..['pending'] = null;
    out['encounter'] = _encounterOf(out, data, _dice(out));
    return out;
  }

  /// Perdeu: a corrida acaba; a pontuação vira moedas e o recorde fica salvo.
  static Json endRun(Json factory, Json run) {
    final coins = runCoins(run);
    return {
      ...factory,
      'coins': _int(factory['coins']) + coins,
      'best': math.max(_int(factory['best']), _int(run['floor']) - 1),
      'run': null,
      'last': {'floor': _int(run['floor']) - 1, 'coins': coins},
    };
  }

  // ------------------------------------------------------------ para a batalha

  /// Nível mínimo para um golpe pelo poder (os evoluídos aprendem coisa forte "no nível 1"). Igual ao site.
  static int movePowerLevel(num power) => math.max(0, ((power - 40) * 0.6).floor());

  /// Golpes que dobram de força a cada turno contam como mais fortes.
  static const _escalating = {'rollout': 80, 'ice-ball': 80};

  /// Golpes que ele sabe no nível (os aprendidos por nível até ali), os melhores 4. Igual ao site.
  static List<String> movesAt(List formMoves, int level, List<String> types, Map<String, Map<String, dynamic>> moves) {
    final levelUp = [for (final m in formMoves) if (m is List && m[1] == 'level-up' && (m[2] as num) <= level) m];
    // Ordenação estável (como a do site).
    final order = [for (var i = 0; i < levelUp.length; i++) i]..sort((a, b) {
        final d = (levelUp[a][2] as num).compareTo(levelUp[b][2] as num);
        return d != 0 ? d : a.compareTo(b);
      });
    final learned = <String>[];
    for (final i in order) {
      final slug = levelUp[i][0] as String;
      if (!learned.contains(slug) && moves.containsKey(slug) && level >= movePowerLevel(_escalating[slug] ?? (moves[slug]!['power'] as num?) ?? 0)) learned.add(slug);
    }
    double power(String s) {
      final m = moves[s]!;
      final p = (m['power'] as num?) ?? 0;
      final category = '${m['damage_class'] ?? m['category']}';
      if (category == 'status' || p <= 0) return 0;
      return p * (types.contains(m['type']) ? 1.5 : 1) * (((m['accuracy'] as num?) ?? 100) / 100);
    }

    final damaging = [for (final s in learned) if (power(s) > 0) s];
    final rank = {for (var i = 0; i < damaging.length; i++) damaging[i]: i};
    damaging.sort((a, b) {
      final d = power(b).compareTo(power(a));
      return d != 0 ? d : rank[a]!.compareTo(rank[b]!);
    });
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

  /// A Bolsa de cada lado: a sua é a da corrida; selvagem não tem itens; treinador e chefe têm mais nos andares altos. Igual ao site.
  static List<Map<String, int>?> bagsFor(Json run) {
    final floor = _int(run['floor']);
    final kind = run['encounter']?['kind'];
    final none = {for (final id in bagItems) id: 0};
    final foe = kind == 'boss'
        ? {...none, 'hyper-potion': 1 + floor ~/ 40, 'max-potion': floor >= 60 ? 1 : 0, 'revive': floor >= 100 ? 1 : 0}
        : kind == 'trainer'
            ? {...none, 'potion': math.min(3, 1 + floor ~/ 15), 'super-potion': floor >= 20 ? 1 : 0, 'hyper-potion': floor >= 40 ? 1 : 0}
            : none;
    return [{...none, ...bagOf(run)}, foe];
  }

  /// A ordem na batalha: quem está de pé primeiro (o primeiro entra em campo). Posições no time da corrida.
  static List<int> battleOrder(Json run) {
    final team = teamOf(run);
    return [
      for (var i = 0; i < team.length; i++) if (hpOf(team[i]) > 0) i,
      for (var i = 0; i < team.length; i++) if (!(hpOf(team[i]) > 0)) i,
    ];
  }

  /// Sem limite de IVs e EVs: o que passa de 31 e 252 vira pontos (IV + EV/4) × nível / 100.
  static Json overflowPoints(Map? ivs, Map? evs, int level) => {
        for (final s in stats)
          s: (((math.max(0, ((ivs?[s] as num?) ?? 0) - 31) + math.max(0, ((evs?[s] as num?) ?? 0) - 252) / 4) * level) / 100).floor()
      };
  static Json _cap(Map? values, int max) => {for (final s in stats) s: math.min(max, math.max(0, ((values?[s] as num?) ?? 0).floor()))};

  /// A porcentagem a mais nos atributos: os itens extras, as cartas do time e o shiny.
  static Map<String, double> boostOf(Json run, Map mon) {
    final out = {for (final s in stats) s: (((run['teamBoost'] as Map?)?[s] as num?) ?? 0).toDouble()};
    if (mon['shiny'] == true) {
      for (final s in stats) {
        out[s] = out[s]! + shinyBoost;
      }
    }
    for (final id in (mon['extras'] as List?) ?? const []) {
      for (final e in (heldBoost['$id'] ?? const <String, double>{}).entries) {
        out[e.key] = out[e.key]! + e.value;
      }
    }
    return {for (final s in stats) s: _round3(out[s]!)};
  }

  /// O Pokémon da corrida como membro de time (TurnBattleSetup.mons).
  static (int, Json) memberOf(Json run, Json mon, List<String> moveList) => (
        _int(mon['id']),
        {
          'level': mon['level'], 'levelCap': 'none', 'nature': mon['nature'], 'ivs': _cap(mon['ivs'] as Map?, 31), 'evs': _cap(mon['evs'] as Map?, 252),
          'item': mon['item'] ?? '', 'moves': moveList, 'lockMoves': true, 'shiny': mon['shiny'] == true,
          'bonus': overflowPoints(mon['ivs'] as Map?, mon['evs'] as Map?, _int(mon['level'])), 'boost': boostOf(run, mon), 'hpRatio': hpOf(mon),
        }
      );

  /// Um adversário do andar como membro de time.
  static (int, Json) foeMember(Json foe, List<String> moveList) {
    final ivs = {for (final s in stats) s: foe['iv']}, evs = {for (final s in stats) s: foe['ev'] ?? 0};
    final boost = ((foe['boost'] as num?) ?? 0).toDouble() + (foe['shiny'] == true ? shinyBoost : 0);
    return (
      _int(foe['id']),
      {
        'level': foe['level'], 'levelCap': 'none', 'ivs': _cap(ivs, 31), 'evs': _cap(evs, 252), 'moves': moveList, 'lockMoves': true,
        'bonus': overflowPoints(ivs, evs, _int(foe['level'])),
        if (boost != 0) 'boost': {for (final s in stats) s: _round3(boost)},
        if (foe['shiny'] == true) 'shiny': true,
      }
    );
  }
}
