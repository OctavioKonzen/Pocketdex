// lib/services/factory_run.dart
//
// Battle Factory, um roguelike com a história de cada região: na primeira vez
// um inicial grátis (de qualquer geração), os outros se compram com moedas.
// Andares sem fim pelo mapa (de cidade em cidade): em cada andar, 2 ou 3
// caminhos (selvagem do bioma da rota, com captura na batalha e uma chance
// para cada bola; treinador; treinador forte com item; Poké Mart; Centro
// Pokémon; evento); a cada
// 10 andares um chefe da história (líderes, rival e vilões, Elite Four e
// Campeão de um jogo sorteado; depois, outra região); nos andares 5, 15, 25...
// às vezes um chefe sem treinador (Mega, Gigantamax ou lendário). Sem cura
// entre andares (Bolsa, loja, Enfermeira Joy); loja com TMs, Move Tutor, Move
// Reminder, pedras de evolução, Dynamax Band e Tera Orb; chefes deixam Cristais
// Z e as Megas a Mega Pedra. Sem limite de nível, IVs, EVs ou itens. Shiny é 1
// em 4096 (+10% nos atributos).
// A corrida fica na conta (league.factory) no mesmo formato e com o mesmo
// sorteio do site (web-site/src/lib/factoryRun.js, onde está a conta da
// dificuldade): começa no app e continua no site.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

typedef Json = Map<String, dynamic>;

class FactoryData {
  /// id → [xp base, total de atributos, raridade (0 comum, 1 lendário, 2 mítico, 3 bebê), [EVs que dá], [tipos], taxa de captura].
  final Map<int, List> species;

  /// id → [[evolui para, nível, item?], ...] (com item: só usando o item, como as pedras).
  final Map<int, List<List>> evolutions;
  final List<int> starters;

  /// Chefes por jogo, na ordem da história: [{region, game, leaders: [{id, name, trainer, kind, city, team, pool}]}].
  final List<Json> bosses;

  /// Formas regionais dos chefes: id da forma → espécie.
  final Map<int, int> forms;

  /// Mega: espécie → [[Mega Pedra, id da Mega]]; espécies com Gigantamax; Cristal Z por tipo; TMs; itens de evolução.
  final Map<int, List<List>> megas;
  final List<int> gmax;
  final Map<String, String> zcrystals;
  final List<String> tms, stones;

  /// A história de cada região (tool/factory_stories.py).
  final Map<String, Map<String, String>> stories;

  /// O mapa de cada região (tool/factory_routes.py): {cities: {cidade: [lugar, rota, lugar no caminho, lugar da cidade]}, start: {região: cidade}}.
  final Json routes;
  const FactoryData(this.species, this.evolutions, this.starters,
      [this.bosses = const [], this.forms = const {}, this.megas = const {}, this.gmax = const [], this.zcrystals = const {},
      this.tms = const [], this.stones = const [], this.stories = const {}, this.routes = const {}]);

  static Future<FactoryData>? _loading;

  /// Os dados já carregados (as telas abrem sem esperar de novo).
  static FactoryData? loaded;
  static Future<FactoryData> load() => _loading ??= rootBundle.loadString('assets/database/factory.json').then((t) => loaded = parse(jsonDecode(t) as Json));

  static FactoryData parse(Json j) {
    final species = {for (final e in (j['species'] as Map).entries) int.parse('${e.key}'): e.value as List};
    return FactoryData(
      // Em ordem de id, como o site (Object.entries).
      Map.fromEntries(species.entries.toList()..sort((a, b) => a.key.compareTo(b.key))),
      {
        for (final e in (j['evolutions'] as Map).entries)
          int.parse('${e.key}'): [
            for (final x in e.value as List) [for (final v in x as List) v is num ? v.toInt() : v]
          ]
      },
      [for (final v in j['starters'] as List) (v as num).toInt()],
      [for (final b in (j['bosses'] as List?) ?? const []) Map<String, dynamic>.from(b as Map)],
      {for (final e in ((j['forms'] as Map?) ?? const {}).entries) int.parse('${e.key}'): (e.value as num).toInt()},
      {
        for (final e in ((j['megas'] as Map?) ?? const {}).entries)
          int.parse('${e.key}'): [
            for (final x in e.value as List) [for (final v in x as List) v is num ? v.toInt() : v]
          ]
      },
      [for (final v in (j['gmax'] as List?) ?? const []) (v as num).toInt()],
      {for (final e in ((j['zcrystals'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
      [for (final v in (j['tms'] as List?) ?? const []) '$v'],
      [for (final v in (j['stones'] as List?) ?? const []) '$v'],
      {
        for (final e in ((j['stories'] as Map?) ?? const {}).entries)
          '${e.key}': {for (final x in (e.value as Map).entries) '${x.key}': '${x.value}'}
      },
      Map<String, dynamic>.from((j['routes'] as Map?) ?? const {}),
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

  /// As Poké Balls (a chance de cada uma está no motor de batalha: BALLS em tool/battle-engine/engine.mjs).
  static const ballIds = ['poke-ball', 'great-ball', 'ultra-ball', 'quick-ball', 'net-ball', 'dusk-ball', 'timer-ball', 'master-ball'];

  /// A Bolsa do começo da corrida (os itens gastos na batalha não voltam).
  static const startBag = {'poke-ball': startBalls, 'potion': 4, 'super-potion': 1, 'hyper-potion': 0, 'max-potion': 0, 'revive': 1};
  static const bagItems = [...ballIds, 'potion', 'super-potion', 'hyper-potion', 'max-potion', 'revive', 'escape-rope'];

  /// Escape Rope: se perder uma batalha, o time foge com pouco HP em vez de a corrida acabar.
  static const escapeHp = 0.1;

  /// Quanto cada item da Bolsa cura (parte do HP máximo; igual na batalha: healPct do motor).
  static const healShare = {'potion': 0.25, 'super-potion': 0.5, 'hyper-potion': 0.75, 'max-potion': 1.0};
  static const joyChance = 0.05, shinyChance = 1 / 4096, shinyBoost = 0.1;

  /// Nos andares 5, 15, 25...: chance de um chefe sem treinador (Mega, Gigantamax ou lendário).
  static const wildBossChance = 0.4;

  static Json _zero() => {for (final s in stats) s: 0};
  static Json _add(Map? a, Map? b) => {for (final s in stats) s: ((a?[s] as num?) ?? 0).toInt() + ((b?[s] as num?) ?? 0).toInt()};
  static Json _copy(Json j) => jsonDecode(jsonEncode(j)) as Json;
  static double _round3(num n) => (n * 1000).round() / 1000;
  // Potências com multiplicação e raiz: o mesmo resultado do site.
  static double _pow15(double x) => x * math.sqrt(x);
  static double _pow8(double x) {
    final x2 = x * x, x4 = x2 * x2;
    return x4 * x4;
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
  static int foeEvsAt(int floor) => 3 * floor;
  static int foeIvsAt(int floor) => math.min(31, floor ~/ 2) + math.max(0, ((floor - 100) / 10).floor());
  static double foeBoostAt(int floor) => (math.max(0, floor - 30) * 0.003 * 1000).round() / 1000;
  /// Preço da loja no andar: cresce junto com o dinheiro (nível e tamanho dos times dos treinadores). Igual ao site.
  static double priceScale(int floor) => (1 + (floor - 1) / 20) * (1 + 0.4 * math.min(5, floor ~/ 12));

  /// Nos 10 primeiros andares, mais dinheiro (até o dobro no 1º).
  static double earlyMoney(int floor) => 1 + math.max(0, 11 - floor) / 10;
  static int speciesBudget(int floor) => 290 + floor * 7;

  // ------------------------------------------------------------ itens e cartas

  /// Itens de segurar: o principal tem o efeito de verdade; cada um a mais dá esta porcentagem.
  static const heldBoost = <String, Map<String, double>>{
    'choice-band': {'atk': 0.05}, 'choice-specs': {'spa': 0.05}, 'choice-scarf': {'spe': 0.05},
    'life-orb': {'atk': 0.03, 'spa': 0.03}, 'expert-belt': {'atk': 0.02, 'spa': 0.02}, 'muscle-band': {'atk': 0.02}, 'wise-glasses': {'spa': 0.02},
    'leftovers': {'hp': 0.04}, 'sitrus-berry': {'hp': 0.03}, 'assault-vest': {'spd': 0.05}, 'rocky-helmet': {'def': 0.04},
    'eviolite': {'def': 0.04, 'spd': 0.04}, 'focus-sash': {'hp': 0.02, 'def': 0.01, 'spd': 0.01}, 'quick-claw': {'spe': 0.03},
    'shell-bell': {'hp': 0.02}, 'black-sludge': {'hp': 0.03}, 'weakness-policy': {'atk': 0.02, 'spa': 0.02}, 'lum-berry': {'hp': 0.02},
    'scope-lens': {'atk': 0.02, 'spa': 0.02}, 'bright-powder': {'spe': 0.02}, 'air-balloon': {'spe': 0.02}, 'heavy-duty-boots': {'def': 0.01, 'spd': 0.01},
    'kings-rock': {'atk': 0.02},
    // Lucky Egg: sem atributo; quem segura ganha mais XP (luckyEgg).
    'lucky-egg': {},
  };
  static const vitamins = {'hp-up': 'hp', 'protein': 'atk', 'iron': 'def', 'calcium': 'spa', 'zinc': 'spd', 'carbos': 'spe'};
  static const vitaminEvs = 24, bottleCapIvs = 3;

  /// Preço no 1º andar (priceScale aumenta com o andar). A ordem é a do site.
  static final shop = <String, int>{
    'poke-ball': 50, 'great-ball': 120, 'ultra-ball': 250, 'quick-ball': 200, 'net-ball': 150, 'dusk-ball': 150, 'timer-ball': 150,
    // Rara na loja (3%): sempre captura.
    'master-ball': 5000,
    'potion': 40, 'super-potion': 90, 'hyper-potion': 160, 'max-potion': 300, 'revive': 180,
    'rare-candy': 120,
    for (final k in vitamins.keys) k: 90,
    'bottle-cap': 200,
    for (final k in heldBoost.keys) k: 250,
    // Serviços e chaves das mecânicas.
    'move-tutor': 300, 'move-reminder': 150, 'dynamax-band': 2500, 'tera-orb': 2500,
    'escape-rope': 450,
    // Exp. Share: o time todo ganha XP (quem não lutou, a metade).
    'exp-share': 800,
    // Mapa (Town Map): mostra o mapa da rota e deixa escolher o caminho nas bifurcações (sem ele, vai às cegas).
    'town-map': 200,
  };

  /// Preço base de um TM ("tm:<golpe>") e de uma pedra de evolução ("evo:<item>").
  static const tmPrice = 220, evoPrice = 400;

  /// Fichas de serviço (gastas ao ensinar um golpe).
  static const tokens = ['move-tutor', 'move-reminder'];

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

  static Json empty() => {'best': 0, 'coins': 0, 'owned': <int>[], 'shinies': <int>[], 'upgrades': <String, int>{}, 'run': null};
  static Json of(Map? league) {
    final out = {...empty(), ...?(league?['factory'] is Map ? _copy(Map<String, dynamic>.from(league!['factory'] as Map)) : null)};
    // Corridas antigas: as Poké Balls ficavam fora da Bolsa (run.balls).
    final run = out['run'];
    if (run is Map && run['balls'] != null) {
      final r = Map<String, dynamic>.from(run)..remove('balls');
      final bag = Map<String, dynamic>.from((r['bag'] as Map?) ?? const {});
      bag['poke-ball'] = ((bag['poke-ball'] as num?) ?? 0).toInt() + _int(run['balls']);
      out['run'] = r..['bag'] = bag;
    }
    return out;
  }

  static int pokemonPrice(int bst) => math.max(20, ((_pow15(math.max(0, bst - 250).toDouble()) / 10 / 5).round() * 5));

  static List<int> ownedOf(Json factory) => [for (final x in (factory['owned'] as List?) ?? const []) _int(x)];

  /// Na primeira vez escolhe um inicial grátis; depois só os que tem (os outros se compram).
  static bool freePick(Json factory) => ownedOf(factory).isEmpty;
  static List<int> startersOf(Json factory, FactoryData data) => freePick(factory) ? [...data.starters] : ownedOf(factory);
  static List<int> shiniesOf(Json factory) => [for (final x in (factory['shinies'] as List?) ?? const []) _int(x)];

  /// Escolhe o inicial grátis (só na primeira vez).
  static Json claimStarter(Json factory, FactoryData data, int id) {
    if (!freePick(factory) || !data.starters.contains(id)) return factory;
    return {...factory, 'owned': [id]};
  }

  /// A primeira forma da linha evolutiva (Charizard → Charmander, Pikachu → Pichu). Igual ao site.
  static int baseForm(FactoryData data, int id) {
    var out = id;
    for (var guard = 0; guard < 4; guard++) {
      final pre = _preEvolutions(data)[out];
      if (pre == null) break;
      out = pre[0];
    }
    return out;
  }

  /// Só a primeira forma está à venda: a evolução vem jogando.
  static bool forSale(FactoryData data, int id) => data.species[id] != null && baseForm(data, id) == id;

  /// Contas antigas (que compraram uma forma evoluída): ficam com a primeira forma dela, sem repetir (o shiny também).
  /// Devolve a mesma Factory se não mudou nada. Igual ao site.
  static Json normalizeOwned(Json factory, FactoryData data) {
    List<int> fix(List<int> list) {
      final out = <int>[];
      for (final id in list) {
        final b = baseForm(data, id);
        if (!out.contains(b)) out.add(b);
      }
      return out;
    }

    final owned = fix(ownedOf(factory)), shinies = fix(shiniesOf(factory));
    bool same(List<int> a, List<int> b) => a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);
    if (same(owned, ownedOf(factory)) && same(shinies, shiniesOf(factory))) return factory;
    // Devolve as moedas: a diferença para a primeira forma (ou tudo, se a primeira forma já era dele).
    int price(int id) => pokemonPrice(_int(data.species[id]?[1] ?? 0));
    var refund = 0;
    final kept = <int>[];
    final before = ownedOf(factory);
    for (final id in before) {
      final base = baseForm(data, id);
      if (id == base) {
        kept.add(id);
        continue;
      }
      refund += kept.contains(base) || before.contains(base) ? price(id) : price(id) - price(base);
      kept.add(base);
    }
    final r = math.max(0, refund);
    return {...factory, 'owned': owned, 'shinies': shinies, 'coins': _int(factory['coins'] ?? 0) + r, 'refunded': r};
  }

  /// Melhorias permanentes (compradas com moedas antes da corrida): nome, quanto por nível, máximo e preço base. Igual ao site.
  /// offset: o que se soma ao valor mostrado (shiny: 1 + nível = quantas vezes mais comum).
  static const _baseUpgrades = <String, ({String label, int per, int max, int base, int offset})>{
    'level': (label: 'Treino: o inicial começa {0} nível acima', per: 1, max: 5, base: 150, offset: 0),
    'ivs': (label: 'Genética: IVs mínimos do inicial +{0}', per: 3, max: 5, base: 120, offset: 0),
    'balls': (label: 'Começa com +{0} Poké Ball', per: 1, max: 5, base: 60, offset: 0),
    'potions': (label: 'Começa com +{0} Potion', per: 1, max: 5, base: 60, offset: 0),
    'revive': (label: 'Começa com +{0} Revive', per: 1, max: 3, base: 200, offset: 0),
    'money': (label: 'Começa com +{0} de dinheiro', per: 100, max: 5, base: 100, offset: 0),
    'shop': (label: 'Loja {0}% mais barata', per: 4, max: 5, base: 250, offset: 0),
    'exp': (label: '+{0}% de XP', per: 5, max: 5, base: 250, offset: 0),
    // As que mudam o jeito de jogar.
    'expShare': (label: 'Começa com o Exp. Share', per: 1, max: 1, base: 1200, offset: 0),
    'reroll': (label: '{0}× por corrida: sortear o caminho de novo', per: 1, max: 2, base: 700, offset: 0),
    'cards': (label: 'Uma carta a mais para escolher depois de cada chefe', per: 1, max: 1, base: 2000, offset: 0),
    'shiny': (label: 'Shiny {0}× mais comum', per: 1, max: 3, base: 900, offset: 1),
    'greatBalls': (label: 'Começa com +{0} Great Ball', per: 1, max: 3, base: 250, offset: 0),
    'rope': (label: 'Começa com +{0} Escape Rope', per: 1, max: 2, base: 500, offset: 0),
    'coins': (label: '+{0}% de moedas no fim da corrida', per: 10, max: 5, base: 400, offset: 0),
    'map': (label: 'Começa com o Mapa da Cidade', per: 1, max: 1, base: 900, offset: 0),
    'dmax': (label: 'Começa com a Dynamax Band', per: 1, max: 1, base: 2500, offset: 0),
    'tera': (label: 'Começa com a Tera Orb', per: 1, max: 1, base: 3000, offset: 0),
    // A árvore grande: itens na Bolsa, itens guardados, bônus no time, XP e dinheiro, fichas (upgradeFx diz o efeito).
    'superPotions': (label: 'Começa com +{0} Super Potion', per: 1, max: 3, base: 150, offset: 0),
    'hyperPotions': (label: 'Começa com +{0} Hyper Potion', per: 1, max: 3, base: 300, offset: 0),
    'maxPotions': (label: 'Começa com +{0} Max Potion', per: 1, max: 2, base: 600, offset: 0),
    'sitrus': (label: 'Começa com uma Sitrus Berry guardada', per: 1, max: 1, base: 800, offset: 0),
    'lum': (label: 'Começa com uma Lum Berry guardada', per: 1, max: 1, base: 900, offset: 0),
    'leftovers': (label: 'Começa com Leftovers guardado', per: 1, max: 1, base: 1200, offset: 0),
    'sash': (label: 'Começa com uma Focus Sash guardada', per: 1, max: 1, base: 1500, offset: 0),
    'ultraBalls': (label: 'Começa com +{0} Ultra Ball', per: 1, max: 3, base: 400, offset: 0),
    'masterBall': (label: 'Começa com +{0} Master Ball', per: 1, max: 1, base: 6000, offset: 0),
    'quickBalls': (label: 'Começa com +{0} Quick Ball', per: 1, max: 3, base: 300, offset: 0),
    'netBalls': (label: 'Começa com +{0} Net Ball', per: 1, max: 3, base: 250, offset: 0),
    'timerBalls': (label: 'Começa com +{0} Timer Ball', per: 1, max: 3, base: 250, offset: 0),
    'duskBalls': (label: 'Começa com +{0} Dusk Ball', per: 1, max: 3, base: 250, offset: 0),
    'expPlus': (label: 'Mais +{0}% de XP', per: 3, max: 5, base: 500, offset: 0),
    'luckyEgg': (label: 'Começa com o Lucky Egg guardado', per: 1, max: 1, base: 1500, offset: 0),
    'hpBoost': (label: 'Vigor: +{0}% de HP no time', per: 1, max: 10, base: 200, offset: 0),
    'speBoost': (label: 'Agilidade: +{0}% de Velocidade no time', per: 1, max: 10, base: 250, offset: 0),
    'tutor': (label: 'Começa com +{0} ficha de Move Tutor', per: 1, max: 3, base: 400, offset: 0),
    'reminder': (label: 'Começa com +{0} ficha de Move Reminder', per: 1, max: 3, base: 250, offset: 0),
    'atk': (label: 'Força: +{0}% de Ataque no time', per: 1, max: 10, base: 200, offset: 0),
    'spa': (label: 'Foco: +{0}% de Ataque Especial no time', per: 1, max: 10, base: 200, offset: 0),
    'def': (label: 'Couraça: +{0}% de Defesa no time', per: 1, max: 10, base: 200, offset: 0),
    'spd': (label: 'Escudo: +{0}% de Defesa Especial no time', per: 1, max: 10, base: 200, offset: 0),
    'allStats': (label: 'Mestre: +{0}% em todos os atributos do time', per: 1, max: 5, base: 1500, offset: 0),
    'band': (label: 'Começa com uma Choice Band guardada', per: 1, max: 1, base: 1200, offset: 0),
    'scarf': (label: 'Começa com uma Choice Scarf guardada', per: 1, max: 1, base: 1500, offset: 0),
    'specs': (label: 'Começa com Choice Specs guardado', per: 1, max: 1, base: 1200, offset: 0),
    'lifeOrb': (label: 'Começa com uma Life Orb guardada', per: 1, max: 1, base: 1500, offset: 0),
    'vest': (label: 'Começa com um Assault Vest guardado', per: 1, max: 1, base: 1300, offset: 0),
    'helmet': (label: 'Começa com um Rocky Helmet guardado', per: 1, max: 1, base: 1000, offset: 0),
    'quickClaw': (label: 'Começa com uma Quick Claw guardada', per: 1, max: 1, base: 900, offset: 0),
    'balloon': (label: 'Começa com um Air Balloon guardado', per: 1, max: 1, base: 900, offset: 0),
    'brightPowder': (label: 'Começa com um Bright Powder guardado', per: 1, max: 1, base: 1000, offset: 0),
    'boots': (label: 'Começa com Heavy-Duty Boots guardadas', per: 1, max: 1, base: 900, offset: 0),
    'kingsRock': (label: 'Começa com uma King\'s Rock guardada', per: 1, max: 1, base: 1000, offset: 0),
    'loot': (label: 'Treinadores pagam +{0}% de dinheiro', per: 5, max: 5, base: 300, offset: 0),
    'expertBelt': (label: 'Começa com uma Expert Belt guardada', per: 1, max: 1, base: 1200, offset: 0),
    'bonusCoins': (label: 'Mais +{0}% de moedas no fim da corrida', per: 10, max: 5, base: 900, offset: 0),
    'policy': (label: 'Começa com uma Weakness Policy guardada', per: 1, max: 1, base: 1500, offset: 0),
    'muscleBand': (label: 'Começa com uma Muscle Band guardada', per: 1, max: 1, base: 1000, offset: 0),
    'wiseGlasses': (label: 'Começa com Wise Glasses guardado', per: 1, max: 1, base: 1000, offset: 0),
    'shellBell': (label: 'Começa com um Shell Bell guardado', per: 1, max: 1, base: 1100, offset: 0),
    'scopeLens': (label: 'Começa com uma Scope Lens guardada', per: 1, max: 1, base: 1600, offset: 0),
    'eviolite': (label: 'Começa com um Eviolite guardado', per: 1, max: 1, base: 1600, offset: 0),
  };

  /// O efeito das melhorias da árvore grande, aplicado no começo da corrida: ('bag', item), ('stash', item), ('token',
  /// ficha), ('boost', atributo), ('boostAll', _), ('mult', 'exp' | 'money') e ('coins', _). Igual ao site.
  static const _baseFx = <String, (String, String)>{
    'superPotions': ('bag', 'super-potion'),
    'hyperPotions': ('bag', 'hyper-potion'),
    'maxPotions': ('bag', 'max-potion'),
    'sitrus': ('stash', 'sitrus-berry'),
    'lum': ('stash', 'lum-berry'),
    'leftovers': ('stash', 'leftovers'),
    'sash': ('stash', 'focus-sash'),
    'ultraBalls': ('bag', 'ultra-ball'),
    'masterBall': ('bag', 'master-ball'),
    'quickBalls': ('bag', 'quick-ball'),
    'netBalls': ('bag', 'net-ball'),
    'timerBalls': ('bag', 'timer-ball'),
    'duskBalls': ('bag', 'dusk-ball'),
    'expPlus': ('mult', 'exp'),
    'luckyEgg': ('stash', 'lucky-egg'),
    'hpBoost': ('boost', 'hp'),
    'speBoost': ('boost', 'spe'),
    'tutor': ('token', 'move-tutor'),
    'reminder': ('token', 'move-reminder'),
    'atk': ('boost', 'atk'),
    'spa': ('boost', 'spa'),
    'def': ('boost', 'def'),
    'spd': ('boost', 'spd'),
    'allStats': ('boostAll', 'all'),
    'band': ('stash', 'choice-band'),
    'scarf': ('stash', 'choice-scarf'),
    'specs': ('stash', 'choice-specs'),
    'lifeOrb': ('stash', 'life-orb'),
    'vest': ('stash', 'assault-vest'),
    'helmet': ('stash', 'rocky-helmet'),
    'quickClaw': ('stash', 'quick-claw'),
    'balloon': ('stash', 'air-balloon'),
    'brightPowder': ('stash', 'bright-powder'),
    'boots': ('stash', 'heavy-duty-boots'),
    'kingsRock': ('stash', 'kings-rock'),
    'loot': ('mult', 'money'),
    'expertBelt': ('stash', 'expert-belt'),
    'bonusCoins': ('coins', 'all'),
    'policy': ('stash', 'weakness-policy'),
    'muscleBand': ('stash', 'muscle-band'),
    'wiseGlasses': ('stash', 'wise-glasses'),
    'shellBell': ('stash', 'shell-bell'),
    'scopeLens': ('stash', 'scope-lens'),
    'eviolite': ('stash', 'eviolite'),
  };

  /// A árvore de melhorias: cada ramo começa numa raiz e o resto pede a anterior num nível (needs), um andar recorde
  /// (best) e quantos Pokémon você já tem para começar (owned). Cada nível a mais pede 3 andares a mais de recorde. Igual ao site.
  static const _baseTree = <String, ({(String, int)? needs, int best, int owned})>{
    'ivs': (needs: ('level', 2), best: 8, owned: 0),
    'revive': (needs: ('potions', 2), best: 6, owned: 0),
    'shop': (needs: ('money', 2), best: 6, owned: 0),
    'exp': (needs: ('ivs', 2), best: 12, owned: 0),
    'expShare': (needs: ('exp', 3), best: 20, owned: 3),
    'reroll': (needs: ('map', 1), best: 15, owned: 0),
    'cards': (needs: ('reroll', 1), best: 25, owned: 8),
    'shiny': (needs: ('greatBalls', 2), best: 15, owned: 5),
    'greatBalls': (needs: ('balls', 2), best: 10, owned: 0),
    'rope': (needs: ('revive', 1), best: 12, owned: 0),
    'coins': (needs: ('shop', 2), best: 12, owned: 0),
    'map': (needs: null, best: 10, owned: 0),
    'dmax': (needs: null, best: 20, owned: 4),
    'tera': (needs: ('dmax', 1), best: 30, owned: 6),
    'superPotions': (needs: ('potions', 2), best: 6, owned: 0),
    'hyperPotions': (needs: ('superPotions', 2), best: 14, owned: 0),
    'maxPotions': (needs: ('hyperPotions', 2), best: 24, owned: 0),
    'sitrus': (needs: ('superPotions', 1), best: 10, owned: 0),
    'lum': (needs: ('sitrus', 1), best: 16, owned: 0),
    'leftovers': (needs: ('revive', 2), best: 15, owned: 0),
    'sash': (needs: ('rope', 1), best: 22, owned: 0),
    'ultraBalls': (needs: ('greatBalls', 2), best: 18, owned: 0),
    'masterBall': (needs: ('ultraBalls', 3), best: 40, owned: 10),
    'quickBalls': (needs: ('balls', 3), best: 12, owned: 0),
    'netBalls': (needs: ('quickBalls', 1), best: 14, owned: 0),
    'timerBalls': (needs: ('netBalls', 1), best: 18, owned: 0),
    'duskBalls': (needs: ('quickBalls', 1), best: 14, owned: 0),
    'expPlus': (needs: ('exp', 5), best: 25, owned: 0),
    'luckyEgg': (needs: ('expShare', 1), best: 30, owned: 0),
    'hpBoost': (needs: ('ivs', 2), best: 10, owned: 0),
    'speBoost': (needs: ('hpBoost', 3), best: 15, owned: 0),
    'tutor': (needs: ('level', 2), best: 10, owned: 0),
    'reminder': (needs: ('tutor', 1), best: 12, owned: 0),
    'atk': (needs: null, best: 5, owned: 0),
    'spa': (needs: ('atk', 2), best: 8, owned: 0),
    'def': (needs: ('atk', 2), best: 8, owned: 0),
    'spd': (needs: ('def', 2), best: 12, owned: 0),
    'allStats': (needs: ('spd', 5), best: 30, owned: 6),
    'band': (needs: ('atk', 5), best: 20, owned: 0),
    'scarf': (needs: ('band', 1), best: 30, owned: 0),
    'specs': (needs: ('spa', 5), best: 20, owned: 0),
    'lifeOrb': (needs: ('spa', 3), best: 25, owned: 0),
    'vest': (needs: ('spd', 3), best: 25, owned: 0),
    'helmet': (needs: ('def', 3), best: 18, owned: 0),
    'quickClaw': (needs: ('map', 1), best: 12, owned: 0),
    'balloon': (needs: ('quickClaw', 1), best: 18, owned: 0),
    'brightPowder': (needs: ('balloon', 1), best: 24, owned: 0),
    'boots': (needs: ('map', 1), best: 14, owned: 0),
    'kingsRock': (needs: ('boots', 1), best: 20, owned: 0),
    'loot': (needs: ('money', 2), best: 8, owned: 0),
    'expertBelt': (needs: ('loot', 3), best: 20, owned: 0),
    'bonusCoins': (needs: ('coins', 5), best: 35, owned: 0),
    'policy': (needs: ('dmax', 1), best: 25, owned: 0),
    'muscleBand': (needs: ('dmax', 1), best: 22, owned: 0),
    'wiseGlasses': (needs: ('muscleBand', 1), best: 24, owned: 0),
    'shellBell': (needs: ('wiseGlasses', 1), best: 28, owned: 0),
    'scopeLens': (needs: ('tera', 1), best: 32, owned: 0),
    'eviolite': (needs: ('tera', 1), best: 34, owned: 0),
  };

  /// Os ramos da árvore, na ordem (da raiz para a ponta).
  static const _baseBranches = [
    ('🧪', 'Sobrevivência', ['potions', 'revive', 'rope', 'sash', 'leftovers', 'superPotions', 'hyperPotions', 'maxPotions', 'sitrus', 'lum']),
    ('🎯', 'Captura', ['balls', 'greatBalls', 'shiny', 'ultraBalls', 'masterBall', 'quickBalls', 'netBalls', 'timerBalls', 'duskBalls']),
    ('🎓', 'Treino', ['level', 'ivs', 'exp', 'expShare', 'luckyEgg', 'expPlus', 'hpBoost', 'speBoost', 'tutor', 'reminder']),
    ('⚔️', 'Combate', ['atk', 'spa', 'specs', 'lifeOrb', 'def', 'spd', 'allStats', 'vest', 'helmet', 'band', 'scarf']),
    ('🧭', 'Exploração', ['map', 'reroll', 'cards', 'quickClaw', 'balloon', 'brightPowder', 'boots', 'kingsRock']),
    ('💰', 'Comércio', ['money', 'shop', 'coins', 'bonusCoins', 'loot', 'expertBelt']),
    ('⚡', 'Poder', ['dmax', 'tera', 'scopeLens', 'eviolite', 'policy', 'muscleBand', 'wiseGlasses', 'shellBell']),
  ];

  /// Os nós pequenos da árvore (como nas árvores de habilidade dos jogos): de cada melhoria sai uma trilha de
  /// [minorLength] nós do tema do ramo ("atk~1", "atk~2"...), cada um com um nível só, pedindo o anterior e um recorde
  /// um pouco maior. O efeito é um dos de [upgradeFx]; o texto, o da melhoria grande do mesmo efeito ([minorBase]). Igual ao site.
  static const minorLength = 8;
  static const minorFx = <String, List<(String, String)>>{
    'Sobrevivência': [('boost', 'hp'), ('bag', 'potion'), ('boost', 'def'), ('boost', 'spd')],
    'Captura': [('bag', 'poke-ball'), ('bag', 'great-ball'), ('bag', 'quick-ball'), ('bag', 'net-ball'), ('bag', 'dusk-ball'), ('bag', 'timer-ball')],
    'Treino': [('mult', 'exp'), ('boost', 'hp'), ('boost', 'spe')],
    'Combate': [('boost', 'atk'), ('boost', 'spa'), ('boost', 'def'), ('boost', 'spd'), ('boost', 'spe')],
    'Exploração': [('mult', 'money'), ('boost', 'spe'), ('bag', 'escape-rope')],
    'Comércio': [('mult', 'money'), ('coins', 'all')],
    'Poder': [('boostAll', 'all'), ('boost', 'atk'), ('boost', 'spa')],
  };

  /// A melhoria grande que dá o texto, o nome e o símbolo de cada efeito pequeno.
  static const minorBase = {
    'boost:hp': 'hpBoost', 'boost:atk': 'atk', 'boost:def': 'def', 'boost:spa': 'spa', 'boost:spd': 'spd', 'boost:spe': 'speBoost',
    'boostAll:all': 'allStats', 'mult:exp': 'expPlus', 'mult:money': 'loot', 'coins:all': 'bonusCoins',
    'bag:potion': 'potions', 'bag:poke-ball': 'balls', 'bag:great-ball': 'greatBalls', 'bag:quick-ball': 'quickBalls', 'bag:net-ball': 'netBalls',
    'bag:dusk-ball': 'duskBalls', 'bag:timer-ball': 'timerBalls', 'bag:escape-rope': 'rope',
  };

  /// A melhoria grande de um nó pequeno ("atk~3" → "atk"), ou ele mesmo.
  static String minorOf(String id) => id.split('~').first;
  static bool isMinor(String id) => id.contains('~');

  static final _tree = _buildTree();
  static final upgrades = _tree.upgrades;
  static final upgradeFx = _tree.fx;
  static final upgradeTree = _tree.tree;
  static final upgradeBranches = _tree.branches;

  static ({
    Map<String, ({String label, int per, int max, int base, int offset})> upgrades,
    Map<String, (String, String)> fx,
    Map<String, ({(String, int)? needs, int best, int owned})> tree,
    List<(String, String, List<String>)> branches,
  }) _buildTree() {
    final ups = {..._baseUpgrades}, fx = {..._baseFx}, tree = {..._baseTree};
    final branches = <(String, String, List<String>)>[];
    for (final (icon, branch, ids) in _baseBranches) {
      final kinds = minorFx[branch]!;
      final list = <String>[];
      for (var i = 0; i < ids.length; i++) {
        final parent = ids[i];
        list.add(parent);
        for (var k = 1; k <= minorLength; k++) {
          final id = '$parent~$k';
          final (kind, arg) = kinds[(i + k - 1) % kinds.length];
          final percent = kind == 'mult' || kind == 'coins';
          ups[id] = (
            label: _baseUpgrades[minorBase['$kind:$arg']]!.label,
            per: percent ? 2 : 1,
            max: 1,
            base: ((_baseUpgrades[parent]!.base * 0.25 + 60 * k) / 10).round() * 10,
            offset: 0,
          );
          fx[id] = (kind, arg);
          tree[id] = (needs: (k == 1 ? parent : '$parent~${k - 1}', 1), best: (_baseTree[parent]?.best ?? 0) + 2 * k, owned: 0);
          list.add(id);
        }
      }
      branches.add((icon, branch, list));
    }
    return (upgrades: ups, fx: fx, tree: tree, branches: branches);
  }

  static const upgradeLevelBest = 3;

  /// O que falta para comprar o próximo nível: [{kind: up, id, level} | {kind: best, floor} | {kind: owned, count}] (vazio: pode).
  static List<Json> upgradeNeeds(Json factory, String id) {
    final node = upgradeTree[id];
    final out = <Json>[];
    final needs = node?.needs;
    if (needs != null && upgradeLevel(factory, needs.$1) < needs.$2) out.add({'kind': 'up', 'id': needs.$1, 'level': needs.$2});
    final best = (node?.best ?? 0) + upgradeLevelBest * upgradeLevel(factory, id);
    if (_int(factory['best'] ?? 0) < best) out.add({'kind': 'best', 'floor': best});
    final owned = node?.owned ?? 0;
    if (owned > 0 && ((factory['owned'] as List?)?.length ?? 0) < owned) out.add({'kind': 'owned', 'count': owned});
    return out;
  }
  static int upgradeLevel(Json factory, String id) => (((factory['upgrades'] as Map?)?[id] as num?) ?? 0).toInt();
  static int upgradeValue(Json factory, String id) => upgradeLevel(factory, id) * upgrades[id]!.per;

  /// Preço do próximo nível (null no máximo).
  static int? upgradePrice(Json factory, String id) {
    final up = upgrades[id];
    final level = upgradeLevel(factory, id);
    if (up == null || level >= up.max) return null;
    return (up.base * math.pow(level + 1, 1.6) / 5).round() * 5;
  }

  /// Compra o próximo nível da melhoria (null se não dá).
  static Json? buyUpgrade(Json factory, String id) {
    final price = upgradePrice(factory, id);
    if (price == null || _int(factory['coins']) < price || upgradeNeeds(factory, id).isNotEmpty) return null;
    return {
      ...factory, 'coins': _int(factory['coins']) - price,
      'upgrades': {...Map<String, dynamic>.from((factory['upgrades'] as Map?) ?? const {}), id: upgradeLevel(factory, id) + 1},
    };
  }

  /// Compra um Pokémon com as moedas (null se não dá). roll (0 a 1): 1 em 4096 de vir shiny.
  static Json? buyPokemon(Json factory, FactoryData data, int id, [double roll = 1]) {
    final info = data.species[id];
    final owned = ownedOf(factory);
    if (info == null || !forSale(data, id) || owned.contains(id) || freePick(factory)) return null;
    final price = pokemonPrice(_int(info[1]));
    if ((factory['coins'] as num) < price) return null;
    final shinies = shiniesOf(factory);
    return {
      ...factory, 'coins': _int(factory['coins']) - price, 'owned': [...owned, id],
      'shinies': roll < shinyChance && !shinies.contains(id) ? [...shinies, id] : shinies,
    };
  }

  /// Preço para transformar um inicial em shiny (bem caro).
  static int shinyPrice(int bst) => math.max(3000, pokemonPrice(bst) * 20);

  static Json? buyShiny(Json factory, FactoryData data, int id) {
    final info = data.species[id];
    final shinies = shiniesOf(factory);
    if (info == null || shinies.contains(id) || !ownedOf(factory).contains(id)) return null;
    final price = shinyPrice(_int(info[1]));
    if ((factory['coins'] as num) < price) return null;
    return {...factory, 'coins': _int(factory['coins']) - price, 'shinies': [...shinies, id]};
  }

  /// Capturou um shiny: se é um dos iniciais dele, libera o shiny para começar.
  static Json unlockShiny(Json factory, FactoryData data, Map? mon) {
    final shinies = shiniesOf(factory);
    if (mon == null || mon['shiny'] != true) return factory;
    final id = _int(mon['id']);
    if (shinies.contains(id) || !(data.starters.contains(id) || ownedOf(factory).contains(id))) return factory;
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

  /// Habilidades fora da batalha (como nos jogos), de quem as tem no time: Pickup acha itens depois das batalhas;
  /// Intimidate (em quem vai na frente) às vezes espanta os selvagens; Synchronize (em quem vai na frente) passa a Nature
  /// para o capturado. Igual ao site.
  static const pickup = [52, 53, 190, 424, 216, 231, 263, 264, 417, 446, 506, 659, 660, 674, 702, 819, 820];
  static const intimidate = [23, 24, 58, 59, 128, 130, 209, 210, 234, 237, 262, 284, 303, 373, 397, 398, 403, 404, 405, 507, 508, 551, 552, 553, 559, 560, 667, 668, 727];
  static const synchronize = [63, 64, 65, 151, 177, 178, 196, 197, 280, 281, 282];
  static const pickupChance = 0.12, intimidateChance = 0.5;
  static const pickupItems = ['potion', 'poke-ball', 'super-potion', 'great-ball', 'revive', 'hyper-potion', 'ultra-ball'];

  /// Quem vai na frente (o primeiro de pé na batalha).
  static Json? _leadOf(Json run) {
    final order = battleOrder(run);
    return order.isEmpty ? null : teamOf(run)[order.first];
  }

  /// Amizade: quem está no time ganha um ponto a cada andar vencido; com friendEvolve, os que evoluem por amizade
  /// evoluem (Eevee: Espeon de dia, Umbreon à noite, pelo relógio). Igual ao site.
  static const friendEvolve = 10;
  static const friendEvos = <int, Object>{
    133: [196, 197], 42: 169, 113: 242, 172: 25, 173: 35, 174: 39, 175: 176, 298: 183, 406: 315, 427: 428, 433: 358, 440: 113,
    446: 143, 447: 448, 527: 528, 541: 542, 772: 773, 872: 873,
  };
  static List<int> _friendTargets(int id) => switch (friendEvos[id]) { final List l => l.cast<int>(), final int v => [v], _ => const [] };

  /// Eventos raros na rota (a partir do andar rareFloor): chuva de meteoros (Clefairy, com mais chance de shiny) e um
  /// Pokémon mítico. Igual ao site.
  static const rareFloor = 8, rareChance = 0.04;
  static const mythics = [151, 251, 385, 386, 490, 491, 492, 494, 647, 648, 719, 720, 721, 801, 802, 807, 893];

  /// Sobe para o nível (com as evoluções que ele alcançar): (mon, evoluiu para).
  static (Json, int?) levelTo(Json mon, int level, FactoryData data, double Function() rand) {
    var out = {...mon, 'level': math.max(1, level)};
    out['exp'] = math.max(((out['exp'] as num?) ?? 0).toInt(), expAt(out['level'] as int));
    int? evolved;
    for (var guard = 0; guard < 3; guard++) {
      // Evoluções por item (pedras) só com o item: canEvolveWith/buyItem.
      // As por amizade (friendEvos) não são por nível (a Eevee, só por pedra ou amizade).
      final id = _int(out['id']);
      final friends = friendEvos.containsKey(id) ? (id == 133 ? null : _friendTargets(id)) : const <int>[];
      final options = [
        for (final e in data.evolutions[id] ?? const <List>[])
          if (e.length < 3 && (out['level'] as int) >= (e[1] as int) && friends != null && !friends.contains(e[0])) e
      ];
      if (options.isEmpty) break;
      final to = _pick(options, rand)[0] as int;
      out = {...out, 'id': to};
      evolved = to;
    }
    return (out, evolved);
  }

  /// XP de derrotar um adversário (a conta está no site). Igual ao site.
  static int expFor(int baseExp, int foeLevel, int level, [double factor = 1]) {
    final scale = math.min(30.0, _pow8((2 * foeLevel + 10) / (foeLevel + level + 10)));
    final species = math.min(1.6, math.max(0.6, math.sqrt(baseExp / 100)));
    return (6 * foeLevel * foeLevel * species * scale * factor).floor() + 1;
  }

  /// Exp. Share: quem não lutou ganha essa parte do XP (e os EVs).
  static const expShare = 0.5;

  /// Lucky Egg: XP a mais para quem segura (como extra, menos). Igual ao site.
  static const luckyEgg = (held: 1.5, extra: 1.2);

  /// Os itens que os chefes e o treinador forte seguram (efeito de verdade na batalha). Igual ao site.
  static const foeItems = [
    'leftovers', 'sitrus-berry', 'life-orb', 'choice-band', 'choice-specs', 'choice-scarf', 'focus-sash', 'assault-vest', 'rocky-helmet',
    'expert-belt', 'lum-berry', 'weakness-policy', 'scope-lens', 'air-balloon',
  ];

  /// Quantas vezes mais comum o shiny está (melhoria "shiny"), vindo do caminho escolhido.
  static double _shinyRate(Map? node) => ((node?['shiny'] as num?) ?? 1).toDouble();
  static double _eggOf(Map m) => m['item'] == 'lucky-egg' ? luckyEgg.held : ((m['extras'] as List?) ?? const []).contains('lucky-egg') ? luckyEgg.extra : 1.0;

  /// O XP de um derrotado para cada um do time (posição na corrida): fought = quem lutou contra ele; sem fought, todos de pé.
  static List<int> expShares(Json run, FactoryData data, Map foe, List<int>? fought, [double factor = 1]) {
    final base = _int(data.speciesOf(_int(foe['id']))?[0] ?? 60);
    final team = teamOf(run);
    return [
      for (var i = 0; i < team.length; i++)
        () {
          if (!(hpOf(team[i]) > 0)) return 0;
          final share = fought == null || fought.contains(i) ? 1.0 : run['expShare'] == true ? expShare : 0.0;
          return share == 0 ? 0 : (expFor(base, _int(foe['level']), _int(team[i]['level']), factor * _mult(run, 'exp')) * share * _eggOf(team[i])).floor();
        }(),
    ];
  }

  /// O fator de XP do tipo de andar (treinadores e chefes dão mais).
  static double expFactor(String? kind) => kind == 'ace' || kind == 'rematch' || kind == 'rival' || kind == 'dboss' ? 1.75 : kind == 'boss' || kind == 'wildboss' || kind == 'trainer' ? 1.5 : 1.0;

  /// A barra de XP: quanto do nível atual já foi (0 a 1), com o XP a mais (extra).
  static double expProgress(Map mon, [int extra = 0]) {
    final level = _int(mon['level']);
    final from = expAt(level), to = expAt(level + 1);
    return ((((mon['exp'] as num?) ?? from) + extra - from) / (to - from)).clamp(0.0, 1.0).toDouble();
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
    // Antes do andar 10, times pequenos, como no começo dos jogos: fica o mais forte.
    final cap = floor < 10 ? 1 + floor ~/ 4 : maxTeam;
    return team.length > cap ? team.sublist(team.length - cap) : team;
  }

  /// Nível de quem evolui por item (pedra), sem nível no jogo: a partir dele já aparece evoluído.
  static const itemEvolutionLevel = 20;
  static final _preCache = Expando<Map<int, List<int>>>();

  /// De quem cada espécie evolui: espécie → [pré-evolução, nível (0: por item)]. A primeira que aparecer. Igual ao site.
  static Map<int, List<int>> _preEvolutions(FactoryData data) => _preCache[data] ??= () {
        final out = <int, List<int>>{};
        // Em ordem de id, como o site (Object.entries).
        for (final from in data.evolutions.keys.toList()..sort()) {
          for (final x in data.evolutions[from]!) {
            out.putIfAbsent(_int(x[0]), () => [from, _int(x[1])]);
          }
        }
        return out;
      }();

  /// O nível mínimo em que a espécie (ou forma) aparece: o nível de cada evolução até ela.
  static int minLevelOf(FactoryData data, int id) {
    final pre = _preEvolutions(data)[data.forms[id] ?? id];
    if (pre == null) return 1;
    return math.max(pre[1] == 0 ? itemEvolutionLevel : pre[1], minLevelOf(data, pre[0]));
  }

  /// Abaixo do nível em que evolui, volta para a forma anterior (um Sceptile nível 2 é um Treecko). Igual ao site.
  static int devolve(FactoryData data, int id, int level) {
    var out = id;
    for (var guard = 0; guard < 4 && minLevelOf(data, out) > level; guard++) {
      final pre = _preEvolutions(data)[data.forms[out] ?? out];
      if (pre == null) break;
      out = pre[0];
    }
    return out;
  }

  /// Nível de um chefe: quem é mais forte que as espécies do andar vem com nível menor.
  static int _bossLevel(FactoryData data, int floor, int id, int lvl) => math.max(2, (lvl * _pow15(math.min(1, speciesBudget(floor) / data.bstOf(id)))).round());

  // ------------------------------------------------------------ mapa

  /// Os lugares das rotas (cada um é também o cenário da batalha) e os tipos que mais aparecem neles. Igual ao site.
  static const biomes = <String, List<String>>{
    'grass': ['normal', 'grass', 'bug', 'flying'],
    'forest': ['bug', 'grass', 'poison', 'fairy'],
    'water': ['water', 'flying'],
    'beach': ['water', 'ground', 'flying', 'rock'],
    'underwater': ['water'],
    'swamp': ['poison', 'water', 'grass', 'bug'],
    'sewer': ['poison', 'dark', 'electric', 'normal'],
    'cave': ['rock', 'ground', 'dark', 'poison'],
    'icecave': ['ice', 'rock', 'water'],
    'mountain': ['rock', 'fighting', 'ground', 'steel', 'dragon'],
    'desert': ['ground', 'rock', 'fire', 'bug'],
    'volcano': ['fire', 'rock', 'ground'],
    'city': ['electric', 'steel', 'psychic', 'normal'],
    'snow': ['ice', 'water'],
    'tower': ['ghost', 'psychic', 'dark'],
    'sky': ['flying', 'dragon', 'fairy'],
    'ruins': ['rock', 'psychic', 'ground', 'ghost'],
    'flowers': ['fairy', 'grass', 'bug', 'normal'],
    'plant': ['electric', 'steel'],
    'crystal': ['rock', 'steel', 'fairy', 'psychic'],
    'dunes': ['ground', 'dark', 'ghost', 'bug'],
    'bamboo': ['grass', 'fighting', 'bug', 'dark'],
    'temple': ['psychic', 'fighting', 'dragon', 'ghost'],
    'lavacave': ['fire', 'rock', 'ground'],
    'poisoncave': ['poison', 'dark', 'bug'],
    'seacave': ['water', 'rock'],
  };
  static final biomeIds = biomes.keys.toList();

  /// Quanto a mais aparecem os tipos do lugar (selvagens; treinadores).
  static const routeTypeWeight = 8, routeTypeTrainer = 3;

  /// Os lugares possíveis da rota até o ginásio de cada tipo (um deles por rota).
  static const _typeBiomes = {
    'normal': ['grass', 'city', 'flowers'], 'fire': ['volcano', 'desert'], 'water': ['water', 'beach'], 'grass': ['forest', 'grass', 'swamp', 'bamboo', 'flowers'],
    'electric': ['city', 'sewer', 'plant'], 'ice': ['snow', 'icecave'], 'fighting': ['mountain', 'cave', 'bamboo', 'temple'], 'poison': ['swamp', 'sewer', 'forest'],
    'ground': ['desert', 'mountain', 'cave', 'dunes'], 'flying': ['sky', 'grass', 'beach'], 'psychic': ['tower', 'city', 'temple', 'ruins'], 'bug': ['forest', 'grass', 'flowers'],
    'rock': ['cave', 'mountain', 'desert', 'ruins', 'crystal'], 'ghost': ['tower', 'ruins', 'dunes'], 'dragon': ['sky', 'mountain', 'temple'], 'dark': ['cave', 'tower', 'sewer', 'dunes'],
    'steel': ['mountain', 'city', 'cave', 'plant', 'crystal'], 'fairy': ['sky', 'forest', 'flowers'],
  };

  /// Na Dusk Ball (3×): os lugares escuros.
  static const darkBiomes = ['cave', 'tower', 'icecave', 'sewer', 'underwater', 'lavacave', 'poisoncave', 'seacave'];

  /// Os chefes de cidade (líder no ginásio dele; Elite Four e Campeão na Liga). Rival e vilões aparecem na rota.
  static const _cityKinds = ['gym', 'elite', 'champion'];

  /// Andares da rota (o 10º é o chefe dela) e da cidade (o último é o líder); onde a rota (e a cidade) se divide (só
  /// ali dá para escolher); chance do rival em cada andar.
  static const routeLength = 10, cityLength = 10, cityBoss = routeLength + cityLength - 1, forks = [1, 4, 7], ambushChance = 0.3;
  /// O rival aparece bastante: de surpresa na rota (fora os da história), no máximo uma vez por rota, a partir do andar rivalFloor.
  static const rivalChance = 0.2, rivalFloor = 12;

  static List _leaders(FactoryData data, Json run) => data.bosses[_int(run['boss']['region'])]['leaders'] as List;

  /// O próximo chefe de cidade (pula rival e vilões): o destino da rota. Igual ao site.
  static Json targetOf(FactoryData data, Json run) {
    final leaders = _leaders(data, run);
    var step = _int(run['boss']['step']);
    while (step < leaders.length - 1 && !_cityKinds.contains(leaders[step]['kind'])) {
      step++;
    }
    return {'step': step, ...Map<String, dynamic>.from(leaders[step] as Map)};
  }

  /// Já está na Liga: depois da primeira da Elite Four, as lutas vêm uma atrás da outra.
  static bool _inLeague(FactoryData data, Json run) {
    final leaders = _leaders(data, run);
    final step = _int(run['boss']['step']);
    return step > 0 && ['elite', 'champion'].contains(leaders[step]['kind']) && leaders[step - 1]['kind'] == 'elite';
  }

  /// Onde está: 0 é o primeiro andar da rota depois da última cidade (run.leg); de routeLength em diante, a cidade
  /// (cityBoss é o líder). Os andares feitos num lugar (run.detour) não contam: depois dele, você volta para o andar em
  /// que entrou.
  static int routePos(Json run) {
    final floor = _int(run['floor']);
    return floor - ((run['leg'] as num?)?.toInt() ?? floor - (floor - 1) % (routeLength + cityLength)) - _n(run, 'detour');
  }

  /// Chegou no líder (o último andar da cidade) ou na Liga: o chefe dela é o próximo andar (dentro de um lugar, não).
  static bool atCity(FactoryData data, Json run) =>
      run['dungeon'] == null && _cityKinds.contains(bossOf(data, run)['kind']) && (_inLeague(data, run) || routePos(run) >= cityBoss);

  /// As regiões de lugares que se ligam (a rota seguinte começa num lugar que faz sentido depois da anterior: da caverna
  /// não se vai direto para o mar). Grama e cidade se ligam a tudo. Igual ao site.
  static const biomeZones = [
    ['grass', 'flowers', 'forest', 'bamboo', 'swamp', 'city', 'plant', 'ruins', 'temple', 'sky', 'poisoncave'],
    ['beach', 'water', 'underwater', 'swamp', 'grass', 'city', 'seacave'],
    ['mountain', 'cave', 'icecave', 'crystal', 'volcano', 'snow', 'sky', 'temple', 'ruins', 'lavacave'],
    ['desert', 'dunes', 'volcano', 'ruins', 'beach', 'lavacave'],
    ['city', 'sewer', 'tower', 'plant'],
  ];
  /// O id de um lugar pelo nome ("Mt. Moon" → "mt-moon").
  static String _placeId(String name) => name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  static ({String id, String name, String scene})? _placeOf(Object? row) =>
      row is List ? (id: _placeId('${row[0]}'), name: '${row[0]}', scene: '${row[1]}') : null;

  /// A rota até a próxima cidade, como nos jogos (tool/factory_routes.py): o lugar dela, o nome, o lugar no caminho
  /// (side) e os da cidade (towns: esgoto, museu, a praia dela...). null se a cidade não estiver no mapa. Igual ao site.
  static ({String biome, String name, ({String id, String name, String scene})? side, List<({String id, String name, String scene})> towns})?
      routeInfo(FactoryData data, Json run) {
    final region = data.bosses[_int(run['boss']['region'])]['region'];
    final city = '${targetOf(data, run)['city'] ?? ''}';
    final cities = (data.routes['cities'] as Map?) ?? const {};
    final row = (cities['$region:$city'] ?? cities[city]) as List?;
    if (row == null) return null;
    return (
      biome: '${row[0]}',
      name: '${row[1]}',
      side: switch (_placeOf(row[2])) { final p? => (id: p.id, name: p.name, scene: _caveScene(p.scene, '${row[0]}')), _ => null },
      towns: [for (final t in (row.length > 3 ? row[3] as List? : null) ?? const []) _placeOf(t)!],
    );
  }

  /// A água, em ordem (não dá para pular): da praia (a rota ou a da cidade) para o mar, dele para o fundo do mar e
  /// dali para a caverna aquática. Cada um é um lugar de 10 andares com um chefe; vencendo, dá para seguir ou voltar.
  static const waterChain = [('beach', 'Praia', 'beach'), ('sea', 'Mar', 'water'), ('deep', 'Fundo do mar', 'underwater'), ('seacave', 'Caverna aquática', 'seacave')];

  /// Numa rota de mar, os primeiros andares são a praia (a água começa por ela); depois, o mar.
  static const shore = 5;

  /// Os lugares sem treinadores: só selvagens, e o chefe é um selvagem forte de lá (dá para capturar).
  static const wildOnly = ['water', 'underwater', 'seacave', 'icecave', 'lavacave', 'poisoncave', 'crystal'];

  /// A caverna combina com o lugar em volta: no gelo, de gelo; no pântano, venenosa; no vulcão, de lava; no mar, aquática.
  static const caveOf = {
    'snow': 'icecave', 'icecave': 'icecave', 'swamp': 'poisoncave', 'volcano': 'lavacave', 'beach': 'seacave', 'water': 'seacave', 'underwater': 'seacave',
  };
  static String _caveScene(String scene, String around) => scene == 'cave' ? caveOf[around] ?? 'cave' : scene;

  /// O lugar da água depois deste cenário (null se não tem: a caverna aquática é o fim).
  static ({String id, String name, String scene})? waterNext(Object? scene) {
    final k = waterChain.indexWhere((w) => w.$3 == scene);
    return k >= 0 && k < waterChain.length - 1 ? (id: waterChain[k + 1].$1, name: waterChain[k + 1].$2, scene: waterChain[k + 1].$3) : null;
  }

  /// O nome e o cenário de um lugar (os genéricos, os da água ou os do mapa da região).
  static ({String name, String scene}) placeInfo(FactoryData data, Json run, String id) {
    final generic = dungeons[id];
    if (generic != null) return (name: generic.name, scene: generic.scene);
    for (final w in waterChain) {
      if (w.$1 == id) return (name: w.$2, scene: w.$3);
    }
    final info = routeInfo(data, run);
    for (final p in [info?.side, ...?info?.towns]) {
      if (p != null && p.id == id) return (name: p.name, scene: p.scene);
    }
    return (name: id, scene: 'cave');
  }

  /// Sai do lugar (venceu o chefe ou usou a Escape Rope): volta para o andar em que entrou (na rota ou na cidade).
  static void _leavePlace(Json run, Json out) {
    final start = _int(run['dungeon']['entry'] ?? run['dungeon']['start']);
    out['back'] = routePos({...run, 'floor': start});
    out['detour'] = _n(run, 'detour') + _int(out['floor']) - start;
    out['dungeon'] = null;
  }

  static bool biomesLinked(Object? a, String b) =>
      a == null || a == b || a == 'grass' || a == 'city' || b == 'grass' || b == 'city' || biomeZones.any((z) => z.contains(a) && z.contains(b));

  /// Os lugares com batalha perto das cidades (10 andares e um chefe no fim; depois volta para a cidade). A base da
  /// equipe vilã também é um lugar desses (o vilão é o chefe dela). Igual ao site.
  static const dungeonLength = 10;
  static const dungeons = <String, ({String scene, String name})>{
    'sewer': (scene: 'sewer', name: 'Esgoto'),
    'haunted': (scene: 'tower', name: 'Casa assombrada'),
    'cave': (scene: 'cave', name: 'Caverna'),
    'plant': (scene: 'plant', name: 'Usina abandonada'),
    'ruins': (scene: 'ruins', name: 'Ruínas'),
    'mine': (scene: 'crystal', name: 'Mina de cristal'),
    'temple': (scene: 'temple', name: 'Templo'),
    'icecave': (scene: 'icecave', name: 'Caverna de gelo'),
    'volcano': (scene: 'volcano', name: 'Vulcão'),
  };
  static final dungeonIds = dungeons.keys.toList();

  /// O andar do lugar (0 a dungeonLength − 1; o último é o do chefe).
  static int dungeonPos(Json run) => run['dungeon'] == null ? -1 : _int(run['floor']) - _int(run['dungeon']['start']);

  /// Nos andares da cidade (fora da Liga): o Poké Mart, o Centro Pokémon, a Creche e os lugares dela; o líder no último.
  static bool townHub(FactoryData data, Json run) => run['dungeon'] == null && !_inLeague(data, run) && routePos(run) >= routeLength;

  /// Na cidade: entra no Poké Mart (o estoque dela; CONTINUAR volta para a cidade). Igual ao site.
  static Json townShop(Json run) {
    if (run['town'] == null || run['encounter'] != null || run['pending'] != null) return run;
    return {...run, 'pending': {'shop': run['town']['shop']}};
  }

  /// Na cidade: o Centro Pokémon cura o time todo, até quem desmaiou (de graça). Igual ao site.
  static Json townCenter(Json run) {
    if (run['town'] == null || run['encounter'] != null || run['pending'] != null) return run;
    return {...run, 'scene': 'center', 'team': [for (final m in teamOf(run)) {...m, 'hp': 1}], 'pending': {'center': true, 'town': true}};
  }

  /// O bioma da rota até a próxima cidade: o do tipo do ginásio; para a Liga, um fixo da região. Igual ao site.
  /// As equipes vilãs (pelo nome de quem aparece nos jogos). Enquanto o próximo chefe é um vilão, a rota é a base da
  /// equipe dele: só capangas, com os Pokémon da equipe (teamPokemon). Igual ao site.
  static const villainTeams = <String, String>{
    'Giovanni': 'rocket', 'Executiva': 'rocket', 'Executivo': 'rocket', 'Proton': 'rocket', 'Ariana': 'rocket', 'Archer': 'rocket', 'Petrel': 'rocket',
    'Archie': 'aqua', 'Shelly': 'aqua', 'Matt': 'aqua', 'Maxie': 'magma', 'Tabitha': 'magma', 'Courtney': 'magma',
    'Mars': 'galactic', 'Cyrus': 'galactic', 'Jupiter': 'galactic', 'Saturn': 'galactic', 'N': 'plasma', 'Zinzolin': 'plasma', 'Colress': 'plasma', 'Ghetsis': 'plasma',
    'Lysandre': 'flare', 'Bryony': 'flare', 'Mable': 'flare', 'Plumeria': 'skull', 'Guzma': 'skull', 'Faba': 'aether', 'Soliera': 'aether', 'Dulse': 'aether',
    'Giacomo': 'star', 'Ortega': 'star',
  };
  static String villainTeam(Object? name) => villainTeams['$name'] ?? 'rocket';

  /// Os Pokémon dos capangas de cada equipe (os evoluídos só a partir do nível em que evoluem).
  static const teamPokemon = <String, List<int>>{
    'rocket': [19, 20, 23, 24, 41, 42, 109, 110, 88, 89, 52, 53, 96, 97, 198, 228, 229],
    'aqua': [318, 319, 261, 262, 72, 73, 41, 42, 320, 340],
    'magma': [322, 323, 261, 262, 218, 219, 41, 42, 324, 74, 75],
    'galactic': [431, 432, 434, 435, 41, 42, 169, 198, 436, 437],
    'plasma': [509, 510, 504, 505, 551, 552, 559, 560, 519, 520, 524],
    'flare': [667, 668, 659, 660, 686, 687, 228, 229, 674],
    'skull': [757, 758, 451, 452, 41, 42, 88, 89, 742, 743],
    'aether': [79, 80, 96, 97, 436, 437, 137, 233, 122],
    'star': [198, 430, 41, 42, 559, 560, 434, 435, 109, 110, 966],
  };

  /// O tipo do líder de ginásio (o que mais aparece no time dele): o ginásio dele tem o cenário desse tipo.
  static String leaderType(FactoryData data, Map boss) {
    final count = <String, int>{};
    for (final id in (boss['team'] as List?) ?? const []) {
      for (final t in (data.speciesOf(_int(id))?.elementAtOrNull(4) as List?) ?? const []) {
        count['$t'] = (count['$t'] ?? 0) + 1;
      }
    }
    final keys = count.keys.toList();
    final order = [for (var i = 0; i < keys.length; i++) i]..sort((a, b) {
        final d = count[keys[b]]!.compareTo(count[keys[a]]!);
        return d != 0 ? d : a.compareTo(b);
      });
    return order.isEmpty ? 'normal' : keys[order.first];
  }

  /// O cenário da luta com o chefe: o líder no ginásio do tipo dele, a Elite Four na Liga, o Campeão na sala dele (uma
  /// por região) e o vilão na base da equipe. Igual ao site.
  static String bossScene(FactoryData data, Map? boss, [String fallback = 'grass']) {
    if (boss == null) return fallback;
    switch (boss['kind']) {
      case 'gym':
        final full = data.bosses.expand((g) => g['leaders'] as List).cast<Map>().where((l) => l['id'] == boss['id']).firstOrNull;
        return 'gym-${full != null ? leaderType(data, full) : 'normal'}';
      case 'champion':
        return 'champion-${'${boss['region'] ?? ''}'.toLowerCase()}';
      case 'elite':
        return 'league';
      case 'villain':
        return 'base-${villainTeam(boss['name'])}';
    }
    return fallback;
  }

  static String routeBiome(FactoryData data, Json run) {
    // Dentro de um lugar (esgoto, casa assombrada, base da equipe vilã...): o cenário dele.
    if (run['dungeon'] != null) return '${run['dungeon']['scene']}';
    // A rota do jogo (o mapa da região, tool/factory_routes.py).
    final info = routeInfo(data, run);
    if (info != null) return info.biome == 'water' && routePos(run) < shore ? 'beach' : info.biome;
    final boss = targetOf(data, run);
    if (boss['kind'] == 'gym') {
      final count = <String, int>{};
      for (final id in boss['team'] as List) {
        for (final t in (data.speciesOf(_int(id))?.elementAtOrNull(4) as List?) ?? const []) {
          count['$t'] = (count['$t'] ?? 0) + 1;
        }
      }
      final keys = count.keys.toList();
      // Ordenação estável (como a do site).
      final order = [for (var i = 0; i < keys.length; i++) i]..sort((a, b) {
          final d = count[keys[b]]!.compareTo(count[keys[a]]!);
          return d != 0 ? d : a.compareTo(b);
        });
      // Um dos lugares do tipo, o mesmo na rota inteira (pela semente e o começo da rota), que se ligue ao da rota anterior.
      final all = order.isEmpty ? null : _typeBiomes[keys[order.first]];
      final linked = all?.where((b) => biomesLinked(run['prevBiome'], b)).toList();
      final list = linked != null && linked.isNotEmpty ? linked : all;
      if (list != null) return list[(_imul((run['leg'] as num?)?.toInt() ?? 1, 2654435761) ^ _int(run['seed'])) % list.length];
    }
    return biomeIds[(_int(run['boss']['region']) * 7 + _int(boss['step']) * 3) % biomeIds.length];
  }

  /// Os pontos do mapa (o peso de cada um nas bifurcações). O Centro Pokémon é raro.
  static const nodeWeights = [('wild', 34), ('trainer', 28), ('ace', 12), ('mart', 10), ('event', 11), ('center', 5), ('trade', 8)];
  static const _battleNodes = ['wild', 'trainer', 'ace', 'boss', 'wildboss', 'rematch', 'rival', 'dboss'];
  static bool isBattleNode(Map? node) => _battleNodes.contains(node?['kind']);

  /// O que tem no andar. A rota tem routeLength andares (o último é o chefe dela); depois vem a cidade, com cityLength
  /// andares (o último é o líder; na Liga, a Elite Four e o Campeão um atrás do outro). O rival da história pode
  /// aparecer em qualquer andar antes do líder. Fora isso, o caminho segue (um ponto só) e só nas bifurcações (na rota
  /// e na cidade) dá para escolher entre 2 ou 3 caminhos ou entrar num lugar. Num lugar não há desvio. Igual ao site.
  static Json routeOptions(Json run, FactoryData data, double Function() rand) {
    final floor = _int(run['floor']);
    final boss = bossOf(data, run);
    final inside = run['dungeon'] != null;
    final city = !inside && townHub(data, run);
    final biome = city ? 'city' : routeBiome(data, run);
    final pos = inside ? dungeonPos(run) : routePos(run);
    Json only(Json node) => {'floor': floor, 'biome': biome, if (city) 'town': true, 'options': [node]};
    // Venceu o chefe de um lugar da água: segue para o próximo (o mar depois da praia...) ou volta.
    if (inside && run['dungeon']['cleared'] == true) {
      final next = waterNext(run['dungeon']['scene'])!;
      return {
        'floor': floor,
        'biome': biome,
        'options': [
          {'kind': 'dungeon', 'place': next.id, 'scene': next.scene, 'deeper': true},
          {'kind': 'leave'},
        ],
      };
    }
    // Lugares sem treinadores (mar, fundo do mar, cavernas de gelo, lava, veneno, cristal): só selvagens, e o chefe é um
    // selvagem forte (dá para capturar).
    final onlyWild = inside && wildOnly.contains(biome);
    // Num lugar (esgoto, base vilã...): no último andar, o chefe (na base, o vilão).
    if (inside && pos >= dungeonLength - 1) {
      return only(onlyWild ? {'kind': 'wildboss', 'area': true} : {'kind': run['dungeon']['place'] == 'base' ? 'boss' : 'dboss'});
    }
    // O último andar da cidade: o líder (com a equipe vilã na cidade, primeiro a base dela).
    if (city && pos >= cityBoss) {
      return only(boss['kind'] == 'villain' ? {'kind': 'dungeon', 'place': 'base', 'scene': 'base-${villainTeam(boss['name'])}'} : {'kind': 'boss'});
    }
    if (atCity(data, run)) return only({'kind': 'boss'});
    // O último andar da rota: o chefe dela.
    if (!inside && !city && pos == routeLength - 1) return only({'kind': 'dboss'});
    if (!inside && boss['kind'] == 'rival') {
      // O rival da história: quantos ainda faltam e quantos andares livres sobram até o líder (sem os chefes).
      final leaders = _leaders(data, run);
      final step = _int(run['boss']['step']);
      var pending = 0;
      while (step + pending < leaders.length && leaders[step + pending]['kind'] == 'rival') {
        pending++;
      }
      final free = cityBoss - pos - (pos < routeLength - 1 ? 1 : 0);
      if (free <= pending || (pos >= 2 && rand() < ambushChance)) return only({'kind': 'boss'});
    }
    // Os selvagens são do lugar (o cenário da batalha é ele). Na base de uma equipe vilã, só capangas.
    final base = biome.startsWith('base-');
    Json wild() => base ? {'kind': 'trainer'} : {'kind': 'wild', 'biome': biome};
    // Só a rota e a cidade se dividem (num lugar, não; nem no andar em que você voltou de um lugar).
    if (inside || !forks.contains(pos % routeLength) || run['back'] == pos) {
      // O rival te seguiu: aparece de surpresa (uma vez por rota, só no caminho para um ginásio).
      if (!inside && !city && floor >= rivalFloor && pos >= 2 && !base && boss['kind'] == 'gym' && run['rivalLeg'] != legOf(run) && rivalBoss(data, run) != null && rand() < rivalChance) {
        return only({'kind': 'rival'});
      }
      // Evento raro: chuva de meteoros (Clefairy) ou um Pokémon mítico.
      if (!inside && !city && !base && floor >= rareFloor && rand() < rareChance) {
        final available = [for (final id in mythics) if (data.species.containsKey(id)) id];
        final meteor = rand() < 0.5;
        if (meteor || available.isNotEmpty) {
          return only(meteor ? {'kind': 'wild', 'biome': biome, 'meteor': true} : {'kind': 'wildboss', 'legend': _pick(available, rand), 'mythic': true});
        }
      }
      final r = rand();
      // Intimidate em quem vai na frente: às vezes os selvagens fogem (vem um treinador no lugar).
      if (r < 0.55 && !base && !onlyWild && intimidate.contains(_leadOf(run)?['id']) && rand() < intimidateChance) return only({'kind': 'trainer'});
      if (onlyWild) return only(r < 0.9 ? wild() : {'kind': 'event'});
      return only(r < 0.55 ? wild() : r < 0.9 || floor <= 2 ? {'kind': 'trainer'} : {'kind': 'event'});
    }
    final options = <Json>[rand() < 0.55 ? wild() : {'kind': 'trainer'}];
    final count = floor <= 2 ? 2 : 3;
    // Na cidade, o Poké Mart e o Centro ficam nela (não no caminho).
    final allowed = [
      for (final w in nodeWeights)
        if ((floor > 2 || w.$1 == 'wild' || w.$1 == 'trainer') && !(city && const ['mart', 'center'].contains(w.$1))) w
    ];
    final total = allowed.fold(0, (int sum, w) => sum + w.$2);
    for (var guard = 0; options.length < count && guard < 20; guard++) {
      var roll = rand() * total;
      var kind = allowed.first.$1;
      for (final w in allowed) {
        roll -= w.$2;
        if (roll < 0) {
          kind = w.$1;
          break;
        }
      }
      final node = kind == 'wild' ? wild() : <String, dynamic>{'kind': kind};
      if (options.any((o) => o['kind'] == node['kind'] && o['biome'] == node['biome'])) continue;
      options.add(node);
    }
    if (!city) {
      // Na rota para a Liga, o lendário da região espera num dos caminhos.
      if (pos == forks[1] && targetOf(data, run)['kind'] == 'elite') {
        final legend = regionLegend(data, run);
        if (legend != null) options[options.length - 1] = {'kind': 'wildboss', 'legend': legend};
      }
      if (pos == forks[1] && !options.any((o) => o['legend'] != null) && rand() < wildBossChance) options[options.length - 1] = {'kind': 'wildboss'};
      // Depois de virar Campeão: o Campeão vencido quer revanche (num dos caminhos da primeira bifurcação).
      if (run['rematch'] != null && pos == forks[0]) options[options.length - 1] = {'kind': 'rematch'};
    }
    // Os lugares (enquanto não forem vencidos nesta rota): na cidade, os dela (e a base vilã, se a equipe estiver lá);
    // na rota, o mar (numa rota de praia) e o lugar no caminho (Mt. Moon, Rock Tunnel...).
    final info = routeInfo(data, run);
    final done = (run['places'] as List?) ?? const [];
    void add(({String id, String name, String scene})? place) {
      if (place != null && !done.contains(place.id)) options.add({'kind': 'dungeon', 'place': place.id, 'scene': place.scene});
    }

    if (city) {
      for (final place in info?.towns ?? const <({String id, String name, String scene})>[]) {
        add(place);
      }
      if (boss['kind'] == 'villain') options.add({'kind': 'dungeon', 'place': 'base', 'scene': 'base-${villainTeam(boss['name'])}'});
    } else {
      // Numa rota de praia, o mar é opcional; numa rota de mar, o fundo do mar.
      final sea = info?.biome == 'water';
      if (pos == forks[sea ? 2 : 1]) add(waterNext(biome));
      if (pos == forks[2]) add(info?.side);
    }
    return {'floor': floor, 'biome': biome, if (city) 'town': true, 'options': options};
  }

  /// A cidade da rota (o destino) e a de onde ela começa (null no começo de uma região). Na Liga, as duas são a Liga.
  static ({String? from, String to}) routeCities(FactoryData data, Json run) {
    final leaders = _leaders(data, run);
    final to = '${targetOf(data, run)['city'] ?? ''}';
    if (_inLeague(data, run)) return (from: to, to: to);
    var k = _int(run['boss']['step']) - 1;
    while (k >= 0 && !_cityKinds.contains(leaders[k]['kind'])) {
      k--;
    }
    // No começo da região: a cidade inicial do jogo (Pallet Town, New Bark Town...).
    final game = data.bosses[_int(run['boss']['region'])];
    final start = (data.routes['start'] as Map?) ?? const {};
    return (from: k >= 0 ? leaders[k]['city'] as String? : (start[game['game']] ?? start[game['region']]) as String?, to: to);
  }

  /// O que o treinador forte deixa (sempre): bolas e remédios na Bolsa, os de segurar guardados.
  static final aceRewards = ['great-ball', 'ultra-ball', 'hyper-potion', 'max-potion', 'revive', 'move-tutor', 'escape-rope', ...heldBoost.keys];

  /// Os eventos do mapa.
  static const events = ['items', 'money', 'berries', 'tutor'];

  /// Chance de o evento ser uma escolha (choiceEvents).
  static const choiceChance = 0.4;

  /// Escolhas na rota: ajudar alguém (paga e ganha um item), seguir um Pokémon ferido (selvagem raro) ou entrar numa
  /// caverna secreta (com Flash, sempre acha algo). Igual ao site.
  static const choiceEvents = ['help', 'follow', 'secret'];

  /// Os lendários de cada região: as pistas aparecem ao longo da história e, na rota para a Liga, um deles espera.
  static const regionLegends = <String, List<int>>{
    'Kanto': [150, 144, 145, 146], 'Johto': [249, 250, 243, 244, 245], 'Hoenn': [382, 383, 384, 380, 381], 'Sinnoh': [483, 484, 487, 480, 481, 482],
    'Unova': [643, 644, 646, 638, 639, 640], 'Kalos': [716, 717, 718], 'Alola': [791, 792, 800, 785], 'Galar': [888, 889, 890], 'Paldea': [1007, 1008, 1001, 1002],
  };

  /// O lendário da região da corrida (sempre o mesmo para a mesma corrida e região).
  static int? regionLegend(FactoryData data, Json run) {
    final list = regionLegends['${data.bosses[_int(run['boss']['region'])]['region']}'] ?? const <int>[];
    return list.isEmpty ? null : list[((_int(run['seed']) & 0xFFFFFFFF) + _int(run['boss']['region'])) % list.length];
  }

  /// A linha evolutiva de um inicial: [ele, a 1ª evolução, a 2ª].
  static List<int> starterLine(FactoryData data, int id) {
    final line = [id];
    for (var k = 0; k < 2; k++) {
      final next = data.evolutions[line.last]?.firstOrNull?.first;
      if (next == null) break;
      line.add(_int(next));
    }
    return line;
  }

  /// O inicial que tem vantagem sobre o seu (Grama → Fogo → Água → Grama), da mesma geração; null se o seu não é um inicial.
  static int? rivalStarter(FactoryData data, Object? starter) {
    final i = data.starters.indexOf(_int(starter ?? -1));
    if (i < 0) return null;
    return data.starters[i - (i % 3) + ((i % 3) + 1) % 3];
  }

  /// Missão da rota: derrotar 3 de um tipo do lugar ou capturar 1 (na base de uma equipe vilã, derrotar 3 capangas).
  static const missionMoney = 150;
  static Json newMission(Json run, FactoryData data, double Function() rand) {
    final biome = routeBiome(data, run);
    final leg = _int(run['leg'] ?? 1);
    if (biome.startsWith('base-')) return {'leg': leg, 'kind': 'grunts', 'type': '', 'need': 3, 'done': 0};
    final type = _pick(biomes[biome] ?? const ['normal'], rand);
    return rand() < 0.6 ? {'leg': leg, 'kind': 'defeat', 'type': type, 'need': 3, 'done': 0} : {'leg': leg, 'kind': 'catch', 'type': type, 'need': 1, 'done': 0};
  }

  /// Um item ganho: bolas e remédios na Bolsa, ficha de Move Tutor, os de segurar guardados.
  static void _giveItem(Json out, String item) {
    if (bagItems.contains(item)) {
      final bag = Map<String, dynamic>.from(out['bag'] as Map);
      bag[item] = ((bag[item] as num?) ?? 0).toInt() + 1;
      out['bag'] = bag;
    } else if (tokens.contains(item)) {
      final t = Map<String, dynamic>.from((out['tokens'] as Map?) ?? const {});
      t[item] = ((t[item] as num?) ?? 0).toInt() + 1;
      out['tokens'] = t;
    } else {
      out['stash'] = [...((out['stash'] as List?) ?? const []), item];
    }
  }

  /// Resolve a escolha da rota (accept: aceitou). Igual ao site.
  static Json resolveChoice(Json run, FactoryData data, bool accept) {
    final choice = pendingOf(run)?['choice'] as Map?;
    if (choice == null) return run;
    final out = _copy(run)..['pending'] = null;
    final rand = _dice(out);
    if (!accept) return out..['pending'] = {'event': {'kind': 'declined'}};
    if (choice['kind'] == 'help') {
      final cost = _int(choice['cost']);
      if (_int(out['money']) < cost) return out..['pending'] = {'event': {'kind': 'declined'}};
      out['money'] = _int(out['money']) - cost;
      final item = _pick(aceRewards, rand);
      _giveItem(out, item);
      out['pending'] = {'event': {'kind': 'helped', 'item': item}};
    } else if (choice['kind'] == 'follow') {
      // O Pokémon ferido leva a um selvagem raro do lugar (a batalha é neste andar).
      out['floor'] = _int(out['floor']) - 1;
      final scene = '${out['scene'] ?? 'grass'}';
      out['encounter'] = {
        ...encounterFor(data, _int(out['floor']), rand, null, false, {'kind': 'wild', 'biome': scene, 'rare': true, 'shiny': run['shinyRate'] ?? 1}),
        'scene': scene,
      };
    } else {
      final found = hasHm(run, 'flash') || rand() < 0.5;
      if (found) {
        final item = _pick(aceRewards, rand);
        final money = (80 * priceScale(_int(out['floor']) - 1)).round();
        _giveItem(out, item);
        out['money'] = _int(out['money']) + money;
        out['pending'] = {'event': {'kind': 'secretFound', 'item': item, 'money': money}};
      } else {
        out['pending'] = {'event': {'kind': 'secretEmpty'}};
      }
    }
    return out;
  }

  /// Escolhe o caminho: batalha (o encontro do andar) ou, sem batalha, Poké Mart, Centro Pokémon e eventos. Igual ao site.
  static Json chooseNode(Json run, FactoryData data, int index, [({bool night, String season})? clock]) {
    final options = (run['route']?['options'] as List?) ?? const [];
    if (index < 0 || index >= options.length || run['encounter'] != null || run['pending'] != null) return run;
    final node = Map<String, dynamic>.from(options[index] as Map);
    if (nodeBlocked(run, node)) return run;
    final out = _copy(run)..['route'] = null;
    // Entra no lugar perto da cidade (esgoto, casa assombrada, base vilã...): 10 andares e o chefe dele; depois volta para a cidade.
    if (node['kind'] == 'dungeon') {
      out['leg'] = run['leg'] ?? legOf(run);
      out['dungeon'] = {
        'place': node['place'],
        'scene': node['scene'],
        'start': run['floor'],
        if (run['dungeon'] != null) 'entry': run['dungeon']['entry'] ?? run['dungeon']['start'],
      };
      out['route'] = routeOptions(out, data, _dice(out));
      return out;
    }
    // Sai da água (depois de vencer o chefe do lugar): de volta para onde entrou.
    if (node['kind'] == 'leave') {
      if (run['dungeon'] != null) _leavePlace(run, out);
      out['route'] = routeOptions(out, data, _dice(out));
      return out;
    }
    final rand = _dice(out);
    final floor = _int(out['floor']);
    final routeBiomeNow = '${run['route']?['biome'] ?? 'grass'}';
    if (isBattleNode(node)) {
      // O cenário da batalha: o bioma do selvagem, a cidade do ginásio, a Liga (torre) ou a rota.
      final city = node['kind'] == 'boss' && atCity(data, run);
      final scene = (node['biome'] as String?) ?? (city ? (bossOf(data, run)['kind'] == 'gym' ? 'city' : 'tower') : routeBiomeNow);
      out['scene'] = scene;
      final when = clock == null ? const <String, dynamic>{} : {'night': clock.night, 'season': clock.season};
      out['encounter'] = {
        ...encounterFor(data, floor, rand, node['kind'] == 'boss' ? bossOf(data, out) : null, node['kind'] == 'wildboss', {...node, 'biome': scene, 'shiny': run['shinyRate'] ?? 1, ...when}),
        'scene': scene,
      };
      // A revanche: o Campeão vencido, com o time do andar de agora (e mais forte).
      if (node['kind'] == 'rematch') {
        out['encounter'] = {...encounterFor(data, floor + rematchFloors, rand, rematchBoss(data, run)), 'kind': 'rematch', 'scene': scene};
      }
      // O chefe do lugar: um treinador forte do lugar, alguns andares à frente (sempre deixa um item).
      if (node['kind'] == 'dboss') {
        out['encounter'] = {
          ...encounterFor(data, floor + 3, rand, null, false, {'kind': 'ace', 'biome': scene, 'shiny': run['shinyRate'] ?? 1}),
          'kind': 'dboss',
          'scene': scene,
        };
        // O mais forte dele usa uma mecânica: Mega, Gigantamax ou Tera.
        final foes = [...(out['encounter']['foes'] as List)];
        foes[foes.length - 1] = bossGimmick(data, Map<String, dynamic>.from(foes.last as Map), rand);
        out['encounter'] = {...out['encounter'] as Map, 'foes': foes};
      }
      // O rival de surpresa: o time dele no andar de agora (não conta como o da história).
      if (node['kind'] == 'rival') {
        out['encounter'] = {...encounterFor(data, floor, rand, rivalBoss(data, run)), 'kind': 'rival', 'scene': scene};
        out['rivalLeg'] = legOf(run);
      }
      // Dupla de treinadores: dois treinadores juntos (os dois times na mesma batalha).
      if (node['kind'] == 'trainer' && !scene.startsWith('base-') && rand() < doubleChance) {
        final second = encounterFor(data, floor, rand, null, false, {...node, 'biome': scene, 'shiny': run['shinyRate'] ?? 1, ...when});
        out['encounter'] = {
          ...out['encounter'] as Map<String, dynamic>,
          'foes': [...out['encounter']['foes'] as List, ...second['foes'] as List],
          'pair': true,
        };
      }
      // O rival leva o inicial que tem vantagem sobre o seu (no lugar do inicial dele ou do mais forte).
      final counter = (node['kind'] == 'boss' || node['kind'] == 'rival') && out['encounter']['boss']?['kind'] == 'rival' ? rivalStarter(data, run['starter']) : null;
      if (counter != null) {
        final lines = [for (final id in data.starters) ...starterLine(data, id)];
        final foes = foesOf(out);
        final found = foes.indexWhere((f) => lines.contains(_int(f['id'])));
        final slot = found >= 0 ? found : foes.length - 1;
        final line = starterLine(data, counter);
        foes[slot] = {...foes[slot], 'id': devolve(data, line.last, _int(foes[slot]['level']))};
        out['encounter'] = {...out['encounter'] as Map<String, dynamic>, 'foes': foes};
      }
      return out;
    }
    out['floor'] = floor + 1;
    // O cenário de onde você está (Poké Mart e Centro na cidade).
    // Na rota não tem Poké Mart nem Centro: o vendedor ambulante e quem cura ficam no próprio lugar.
    out['scene'] = routeBiomeNow;
    if (node['kind'] == 'mart') {
      out['pending'] = {'mart': true, 'shop': _pickShop(rand, data, floor, 10, run['townMap'] == true)};
    } else if (node['kind'] == 'trade') {
      // Troca: alguém da rota oferece um Pokémon (você escolhe quem dar; ele vem tradeLevels acima).
      final offer = (encounterFor(data, floor + 1, rand, null, false, {'kind': 'wild', 'biome': run['route']?['biome'], 'shiny': run['shinyRate'] ?? 1})['foes'] as List).first as Map;
      out['pending'] = {'trade': {'id': offer['id'], if (offer['shiny'] == true) 'shiny': true}};
    } else if (node['kind'] == 'center') {
      out['team'] = [for (final m in teamOf(out)) {...m, 'hp': 1}];
      out['pending'] = {'center': true};
    } else if (rand() < choiceChance) {
      // Uma escolha na rota: ajudar alguém, seguir um Pokémon ferido ou entrar numa caverna secreta.
      final kind = _pick(choiceEvents, rand);
      out['pending'] = {
        'choice': {'kind': kind, if (kind == 'help') 'cost': (80 * priceScale(floor)).round()},
      };
    } else {
      final kind = _pick(events, rand);
      final event = <String, dynamic>{'kind': kind};
      if (kind == 'items') {
        // Bolas ou remédios, melhores conforme o andar.
        final item = rand() < 0.5 ? tierPick(ballTiers, floor, 25, rand) : tierPick(healTiers.sublist(0, 3), floor, 20, rand);
        event['item'] = item;
        event['count'] = 2;
        final bag = Map<String, dynamic>.from(out['bag'] as Map);
        bag[item] = ((bag[item] as num?) ?? 0).toInt() + (event['count'] as int);
        out['bag'] = bag;
      } else if (kind == 'money') {
        event['money'] = (60 * priceScale(floor) * (0.5 + rand())).round();
        out['money'] = _int(out['money']) + (event['money'] as int);
      } else if (kind == 'berries') {
        out['team'] = [for (final m in teamOf(out)) hpOf(m) > 0 ? {...m, 'hp': math.min(1, _round3(hpOf(m) + 0.3))} : m];
      } else {
        final t = Map<String, dynamic>.from((out['tokens'] as Map?) ?? const {});
        t['move-tutor'] = ((t['move-tutor'] as num?) ?? 0).toInt() + 1;
        out['tokens'] = t;
      }
      out['pending'] = {'event': event};
    }
    return out;
  }

  /// A captura na batalha (input.capture do motor): só com selvagens. Igual ao site.
  static Json? captureFor(Json run, FactoryData data) {
    final encounter = run['encounter'] as Map?;
    final kind = encounter?['kind'];
    if (kind != 'wild' && kind != 'wildboss') return null;
    // Nuzlocke: um capturado por rota.
    if (run['nuzlocke'] == true && run['caughtLeg'] == legOf(run)) return null;
    return {
      'rates': [for (final f in foesOf(run)) ((data.speciesOf(_int(f['id']))?.elementAtOrNull(5) as num?) ?? 45).toInt()],
      'dusk': darkBiomes.contains(encounter?['biome']),
    };
  }

  /// O que aparece no andar: chefe da história, chefe sem treinador (wild: Mega, Gigantamax ou lendário), selvagem ou treinador.
  /// node: o caminho escolhido no mapa (selvagem do bioma, treinador ou treinador forte). Igual ao site.
  static Json encounterFor(FactoryData data, int floor, double Function() rand, [Json? boss, bool wild = false, Json? node]) {
    final level = math.max(2, foeLevelAt(floor) + (rand() * 2).floor());
    final iv = foeIvsAt(floor), ev = foeEvsAt(floor), boost = foeBoostAt(floor);
    // Evoluídos só a partir do nível em que evoluem (abaixo dele, a forma anterior).
    Json foe(int id, int lvl, [Json extra = const {}]) =>
        {'id': devolve(data, id, math.max(2, lvl)), 'level': math.max(2, lvl), 'iv': iv, 'ev': ev, if (boost != 0) 'boost': boost, ...extra};
    // O chefe de um lugar sem treinadores (mar, cavernas de gelo, lava...): o Pokémon forte de lá, raro e acima do nível
    // (dá para capturar).
    if (wild && node?['area'] == true) {
      final f = Map<String, dynamic>.from(
          (encounterFor(data, floor + 3, rand, null, false, {'kind': 'wild', 'biome': node!['biome'], 'rare': true, 'shiny': node['shiny']})['foes'] as List).first as Map);
      return {
        'kind': 'wildboss',
        'area': true,
        'foes': [
          bossGimmick(data, {...f, 'iv': math.max(31, _int(f['iv'])), 'ev': (_int(f['ev']) * 1.25).round()}, rand)
        ],
      };
    }
    if (wild) {
      // Chefe sem treinador: dá para capturar; a Mega deixa a Mega Pedra.
      final r = rand();
      final strong = {'iv': math.max(31, iv), 'ev': (ev * 1.25).round()};
      int id;
      Json extra;
      // Mega e Gigantamax só dos que já chegaram ao nível em que evoluem; senão, um lendário.
      bool fits(int sid) => minLevelOf(data, sid) <= _bossLevel(data, floor, sid, level + 3);
      final megas = (data.megas.keys.toList()..sort()).where(fits).toList();
      final gmax = data.gmax.where(fits).toList();
      if (node?['legend'] != null) {
        // O lendário da região (na rota para a Liga) ou o mítico (evento raro).
        id = _int(node!['legend']);
        extra = {'title': 'legend', if (node['mythic'] == true) 'mythic': true};
      } else if (r < 0.4 && megas.isNotEmpty) {
        id = _pick(megas, rand);
        final stone = _pick(data.megas[id]!, rand)[0] as String;
        extra = {'item': stone, 'gimmick': 'mega', 'title': 'mega'};
      } else if (r >= 0.4 && r < 0.7 && gmax.isNotEmpty) {
        id = _pick(gmax, rand);
        extra = {'gimmick': 'dmax', 'title': 'gmax'};
      } else {
        final legends = [for (final e in data.species.entries) if (_int(e.value[2]) == 1 || _int(e.value[2]) == 2) e.key];
        id = _pick(legends, rand);
        extra = {'title': 'legend'};
      }
      final lvl = _bossLevel(data, floor, id, level + 3);
      return {'kind': 'wildboss', 'foes': [foe(id, lvl, {...strong, ...extra, if (rand() < shinyChance * _shinyRate(node)) 'shiny': true})]};
    }
    if (boss != null) {
      // Os times dos chefes são de Pokémon evoluídos: quem é mais forte que as espécies do andar vem com nível menor.
      // Antes do andar 10, sem o bônus de nível (o rival aparece cedo, como no começo dos jogos).
      // Antes do andar 10, o rival vem só com um Pokémon, sem IVs e EVs a mais (como no começo dos jogos).
      final early = floor < 10;
      final bonus = early ? 0 : const {'gym': 2, 'rival': 2, 'villain': 3, 'elite': 4, 'champion': 5}[boss['kind']] ?? 2;
      final full = bossTeam(boss, floor);
      final team = early && boss['kind'] == 'rival' ? full.sublist(full.length - 1) : full;
      int levelOf(int id, int i) => _bossLevel(data, floor, id, level + bonus + (i == team.length - 1 && !early ? 1 : 0));

      final foes = [
        for (var i = 0; i < team.length; i++) foe(team[i], levelOf(team[i], i), early ? const <String, dynamic>{} : {'iv': math.max(31, iv), 'ev': (ev * 1.25).round()})
      ];
      // A partir do andar 10, cada Pokémon do chefe segura um item de verdade (Leftovers, Life Orb, Choice...).
      if (floor >= 10) {
        for (final f in foes) {
          f['item'] = _pick(foeItems, rand);
        }
      }
      return {
        'kind': 'boss', 'foes': foes,
        'boss': {'id': boss['id'], 'name': boss['name'], 'trainer': boss['trainer'], 'kind': boss['kind'], 'region': boss['region'], 'game': boss['game']},
      };
    }
    // Lendários só aparecem como chefes (wild).
    final kind = (node?['kind'] as String?) ?? (rand() < 0.35 ? 'trainer' : 'wild');
    // Nos primeiros andares, nada de Fantasma (imune aos golpes Normal que os iniciais têm no começo).
    final entries = [
      for (final e in data.species.entries)
        if ((floor >= 8 || !(e.value.length > 4 && (e.value[4] as List).contains('ghost'))) && minLevelOf(data, e.key) <= level)
          (id: e.key, bst: _int(e.value[1]), rarity: _int(e.value[2]), rate: _int(e.value.elementAtOrNull(5) ?? 45))
    ];
    final budget = speciesBudget(floor);
    // A chance de cada espécie segue a raridade dela (a taxa de captura); os treinadores com menos diferença (raiz).
    // Os tipos do lugar aparecem bem mais (routeTypeWeight; nos treinadores, routeTypeTrainer).
    // À noite, mais Fantasma e Sombrio; em cada estação, os tipos dela (node.night, node.season: o relógio de quem joga).
    final types = biomes[node?['biome']] == null
        ? null
        : [...biomes[node!['biome']]!, if (node['night'] == true) ...nightTypes, ...?seasonTypes[node['season']]];
    bool local(int id) => types != null && ((data.species[id]?.elementAtOrNull(4) as List?) ?? const []).any(types.contains);
    int pick(List<({int id, int bst, int rarity, int rate})> pool, [bool trainer = false]) {
      final fit = [for (final p in pool) if (p.bst <= budget && p.bst >= math.min(budget, 600) - 160) p];
      final near = [...pool]..sort((a, b) {
          final d = (a.bst - budget).abs().compareTo((b.bst - budget).abs());
          return d != 0 ? d : a.id.compareTo(b.id);
        });
      final list = fit.isNotEmpty ? fit : near.take(20).toList();
      return _pickWeighted(list, [
        for (final p in list) trainer ? math.sqrt(p.rate) * (local(p.id) ? routeTypeTrainer : 1) : p.rate.toDouble() * (local(p.id) ? routeTypeWeight : 1)
      ], rand).id;
    }

    final common = [for (final p in entries) if (p.rarity == 0 || p.rarity == 3) p];
    if (kind == 'trainer' || kind == 'ace') {
      // O treinador forte: um Pokémon a mais, 2 níveis acima, mais EVs; sempre deixa um item.
      final ace = kind == 'ace';
      final count = math.min(maxTeam, 1 + floor ~/ 12 + (rand() < 0.3 ? 1 : 0) + (ace ? 1 : 0));
      final Json extra = ace ? {'iv': math.max(iv, 20), 'ev': (ev * 1.15).round()} : const {};
      // Na base de uma equipe vilã: capangas com os Pokémon da equipe.
      final nodeBiome = '${node?['biome'] ?? ''}';
      final grunt = nodeBiome.startsWith('base-') ? nodeBiome.substring(5) : null;
      final gruntPool = grunt == null ? null : teamPokemon[grunt];
      final foes = <Json>[];
      for (var i = 0; i < count; i++) {
        final id = gruntPool != null ? _pick(gruntPool, rand) : pick(common, true);
        foes.add(foe(id, level + (ace ? 2 : 0) - (rand() * 3).floor(), extra));
      }
      // O mais forte do treinador forte segura um item de verdade (a partir do andar 15).
      if (ace && floor >= 15) foes.last['item'] = _pick(foeItems, rand);
      return {'kind': kind, 'foes': foes, 'trainerSeed': (rand() * 1e9).floor(), if (ace) 'reward': _pick(aceRewards, rand), if (grunt != null) 'grunt': grunt};
    }
    // Selvagem: só os que vivem no lugar (o habitat de cada espécie: dos locais de encontro dos jogos; no fundo do mar,
    // só quem vive debaixo d'água); sem habitat nos dados, pelos tipos do lugar; sem nenhum, qualquer um.
    final place = node?['biome'];
    final lives = place == null ? const <({int id, int bst, int rarity, int rate})>[] : [for (final p in common) if (((data.species[p.id]?.elementAtOrNull(6) as List?) ?? const []).contains(place)) p];
    final native = lives.isNotEmpty ? lives : types == null ? const <({int id, int bst, int rarity, int rate})>[] : [for (final p in common) if (local(p.id)) p];
    // Seguindo o Pokémon ferido: um raro do lugar (taxa de captura baixa).
    final rare = node?['rare'] == true ? [for (final p in (native.isNotEmpty ? native : common)) if (p.rate <= 75) p] : const <({int id, int bst, int rarity, int rate})>[];
    // Chuva de meteoros: um Clefairy (da linha dele, pelo nível), com mais chance de ser shiny.
    final meteor = node?['meteor'] == true;
    final id = meteor ? devolve(data, 36, level) : pick(rare.isNotEmpty ? rare : native.isNotEmpty ? native : common);
    return {
      'kind': kind, 'foes': [foe(id, level, rand() < shinyChance * _shinyRate(node) * (meteor ? 8 : 1) ? {'shiny': true} : const {})],
      if (node?['biome'] != null) 'biome': node!['biome'],
      if (meteor) 'meteor': true,
    };
  }

  static Json? startRun(Json factory, FactoryData data, int id, int seed, {bool shiny = false, bool nuzlocke = false, String? weekly, String? rule}) {
    // Na corrida da semana, o inicial é o da semana (o mesmo para todos).
    if (weekly == null && (!startersOf(factory, data).contains(id) || (shiny && !shiniesOf(factory).contains(id)))) return null;
    // As melhorias compradas com moedas.
    int up(String k) => upgradeValue(factory, k);
    final run = <String, dynamic>{
      'seed': seed & 0xFFFFFFFF, 'floor': 1, 'money': up('money'), 'defeated': 0, 'bosses': 0,
      'bag': {
        ...startBag, 'poke-ball': startBag['poke-ball']! + up('balls'), 'potion': startBag['potion']! + up('potions'), 'revive': startBag['revive']! + up('revive'),
        if (up('greatBalls') > 0) 'great-ball': up('greatBalls'),
        if (up('rope') > 0) 'escape-rope': up('rope'),
      },
      'team': <Json>[], 'teamBoost': _zero(), 'mult': {'money': 1, 'exp': _round3(1 + up('exp') / 100), 'shop': _round3(1 - up('shop') / 100)},
      'cards': <String>[], 'boss': {'region': 0, 'step': 0}, 'played': <String>[],
      if (up('cards') > 0) 'cardCount': 3 + up('cards'),
      if (up('reroll') > 0) 'rerolls': up('reroll'),
      if (up('shiny') > 0) 'shinyRate': 1 + up('shiny'),
      'tms': <String, dynamic>{}, 'tokens': {'move-tutor': 0, 'move-reminder': 0}, 'stash': <String>[], 'dmax': up('dmax') > 0, 'tera': up('tera') > 0, 'expShare': up('expShare') > 0,
      'leg': 1, 'route': null, 'encounter': null, 'pending': null,
      if (up('map') > 0) 'townMap': true,
      // O inicial (o rival escolhe o que tem vantagem sobre ele).
      'starter': id,
      // Nuzlocke: quem desmaia vai embora e só um capturado por rota.
      if (nuzlocke) 'nuzlocke': true,
      // A corrida da semana (a semana e a regra dela).
      if (weekly != null) ...{'weekly': weekly, 'rule': rule ?? 'normal'},
    };
    // Regra da semana "sem itens": começa com a Bolsa vazia.
    // A árvore grande: itens, bônus, XP, dinheiro e fichas (na ordem das melhorias). Igual ao site.
    for (final e in upgradeFx.entries) {
      final v = up(e.key);
      if (v == 0) continue;
      final (kind, arg) = e.value;
      switch (kind) {
        case 'bag':
          run['bag'] = {...Map<String, dynamic>.from(run['bag'] as Map), arg: (((run['bag'] as Map)[arg] as num?) ?? 0).toInt() + v};
        case 'stash':
          run['stash'] = [...run['stash'] as List, arg];
        case 'token':
          run['tokens'] = {...Map<String, dynamic>.from(run['tokens'] as Map), arg: (((run['tokens'] as Map)[arg] as num?) ?? 0).toInt() + v};
        case 'boost':
          run['teamBoost'] = {...Map<String, dynamic>.from(run['teamBoost'] as Map), arg: _round3(((run['teamBoost'] as Map)[arg] as num) + v / 100)};
        case 'boostAll':
          run['teamBoost'] = {for (final st in stats) st: _round3(((run['teamBoost'] as Map)[st] as num) + v / 100)};
        case 'mult':
          run['mult'] = {...Map<String, dynamic>.from(run['mult'] as Map), arg: _round3(((run['mult'] as Map)[arg] as num) + v / 100)};
      }
    }
    if (rule == 'noItems') run['bag'] = {for (final k in (run['bag'] as Map).keys) k: 0};
    final rand = _dice(run);
    // O inicial vem com IVs bons (15 a 31; com a Genética, mais).
    run['team'] = [newMon(id, startLevel + up('level'), rand, math.min(31, 15 + up('ivs')), shiny)];
    run['boss'] = {'region': (rand() * data.bosses.length).floor(), 'step': 0};
    run['played'] = [data.bosses[_int(run['boss']['region'])]['region']];
    run['route'] = routeOptions(run, data, rand);
    run['mission'] = newMission(run, data, rand);
    return run;
  }

  static List<Json> teamOf(Json run) => [for (final m in run['team'] as List) Map<String, dynamic>.from(m as Map)];
  static List<Json> foesOf(Json run) => [for (final f in (run['encounter']?['foes'] as List?) ?? const []) Map<String, dynamic>.from(f as Map)];
  static double _mult(Json run, String k) => ((run['mult'] as Map)[k] as num).toDouble();
  static double hpOf(Map mon) => ((mon['hp'] as num?) ?? 1).toDouble();
  static Map<String, int> bagOf(Json run) => {for (final id in bagItems) id: (((run['bag'] as Map?)?[id] as num?) ?? 0).toInt()};
  static Json? routeOf(Json run) => run['route'] == null ? null : Map<String, dynamic>.from(run['route'] as Map);

  /// O próximo chefe: depois do Campeão, a história de outra região (uma que ainda não saiu). Igual ao site.
  static (Json, List<String>) _nextBoss(Json run, FactoryData data, double Function() rand) {
    final region = _int(run['boss']['region']);
    final step = _int(run['boss']['step']) + 1;
    var played = [for (final x in (run['played'] as List?) ?? const []) '$x'];
    if (step < (data.bosses[region]['leaders'] as List).length) return ({'region': region, 'step': step}, played);
    var options = [for (var i = 0; i < data.bosses.length; i++) if (!played.contains(data.bosses[i]['region'])) i];
    if (options.isEmpty) {
      played = [];
      options = [for (var i = 0; i < data.bosses.length; i++) if (data.bosses[i]['region'] != data.bosses[region]['region']) i];
    }
    if (options.isEmpty) options = [region];
    final next = _pick(options, rand);
    return ({'region': next, 'step': 0}, [...played, '${data.bosses[next]['region']}']);
  }

  /// O texto da história para a região e o momento ({0}: o nome do chefe).
  static String storyLine(FactoryData data, String region, String key, [String name = '']) => (data.stories[region]?[key] ?? '').replaceFirst('{0}', name);

  /// Venceu o andar. hp: a parte do HP de cada um do time (na ordem da
  /// corrida) no fim da batalha; bag: a Bolsa que sobrou; captured: capturou o
  /// selvagem na batalha (entra no time). Igual ao site.
  static Json winFloor(Json run, FactoryData data,
      {List<double>? hp, Map<String, int>? bag, bool captured = false, List<List<int>>? fought, List<int>? gained, String? ball, bool night = false}) {
    final out = _copy(run);
    final team0 = teamOf(out);
    out['team'] = [for (var i = 0; i < team0.length; i++) {...team0[i], 'hp': hp != null && i < hp.length ? hp[i] : hpOf(team0[i])}];
    // A Escape Rope não entra na batalha: fica a da Bolsa.
    out['bag'] = {...(bag ?? Map<String, dynamic>.from(run['bag'] as Map)), 'escape-rope': ((run['bag'] as Map)['escape-rope'] as num?)?.toInt() ?? 0};
    final rand = _dice(out);
    final kind = run['encounter']['kind'] as String;
    final foes = foesOf(run);
    final factor = expFactor(kind);
    final moneyFactor = kind == 'boss' || kind == 'wildboss' || kind == 'rematch' || kind == 'rival' || kind == 'dboss' ? 3 : kind == 'ace' ? 2.5 : kind == 'trainer' ? 2 : 1;
    var money = 0;
    // XP e EVs de cada derrotado: para quem lutou contra ele (fought[j]: posições na corrida) e, com o Exp. Share, para o resto do time.
    final team = teamOf(out);
    final gains = List.filled(team.length, 0);
    final evs = [for (final _ in team) _zero()];
    for (var j = 0; j < foes.length; j++) {
      final f = foes[j];
      money += ((_int(f['level']) * 6 + 10) * moneyFactor * _mult(out, 'money') * earlyMoney(_int(run['floor']))).floor();
      final yields = (data.speciesOf(_int(f['id'])))?.elementAtOrNull(3) as List? ?? const [0, 0, 0, 0, 0, 0];
      final shares = expShares(out, data, f, fought != null && j < fought.length ? fought[j] : null, factor);
      for (var i = 0; i < team.length; i++) {
        if (shares[i] == 0) continue;
        gains[i] += shares[i];
        for (var k = 0; k < stats.length; k++) {
          evs[i][stats[k]] = (evs[i][stats[k]] as int) + _int(yields[k]) * 3;
        }
      }
    }
    // O XP que cada um já ganhou na luta (a batalha dá na hora, ao derrubar cada adversário): vale esse. Igual ao site.
    if (gained != null) {
      for (var i = 0; i < gained.length && i < gains.length; i++) {
        gains[i] = gained[i];
      }
    }
    final levels = <Json>[];
    final exp = gains.fold(0, math.max);
    for (var i = 0; i < team.length; i++) {
      final m = team[i];
      if (gains[i] == 0) continue;
      final (mon, from, evolved) = _gainExp({...m, 'evs': _add(m['evs'] as Map?, evs[i])}, gains[i], data, rand);
      if (_int(mon['level']) > from || evolved != null) levels.add({'index': i, 'from': from, 'to': mon['level'], 'evolved': evolved});
      team[i] = mon;
    }
    // Amizade: quem está de pé ganha um ponto; com friendEvolve, os que evoluem por amizade evoluem.
    for (var i = 0; i < team.length; i++) {
      final m = team[i];
      if (hpOf(m) <= 0) continue;
      final friendship = _int(m['friendship'] ?? 0) + 1;
      final to = friendEvos[_int(m['id'])];
      if (to == null || friendship < friendEvolve) {
        team[i] = {...m, 'friendship': friendship};
        continue;
      }
      final id = to is List ? to[night ? 1 : 0] as int : to as int;
      out['friendEvos'] = ((out['friendEvos'] as num?) ?? 0).toInt() + 1;
      levels.add({'index': i, 'from': m['level'], 'to': m['level'], 'evolved': id, 'friend': true});
      team[i] = {...m, 'id': id, 'friendship': friendship};
    }
    // Pickup: quem tem acha um item de vez em quando (melhor conforme o andar).
    final picked = <Json>[];
    for (final m in team) {
      if (hpOf(m) > 0 && pickup.contains(_int(m['id'])) && rand() < pickupChance) {
        final item = pickupItems[math.min(pickupItems.length - 1, (rand() * math.min(pickupItems.length.toDouble(), 2 + _int(run['floor']) / 10)).floor())];
        final bagNow = Map<String, dynamic>.from(out['bag'] as Map);
        out['bag'] = {...bagNow, item: ((bagNow[item] as num?) ?? 0).toInt() + 1};
        picked.add({'id': m['id'], 'item': item});
      }
    }
    // Nuzlocke: quem desmaiou vai embora (para sempre).
    final lost = run['nuzlocke'] == true ? [for (final m in team) if (hpOf(m) <= 0) m['id']] : const [];
    if (lost.isNotEmpty && lost.length < team.length) team.removeWhere((m) => hpOf(m) <= 0);
    if (run['encounter']['meteor'] == true) out['meteors'] = ((run['meteors'] as num?) ?? 0).toInt() + 1;
    out['team'] = team;
    out['money'] = _int(out['money']) + money;
    out['defeated'] = _int(out['defeated']) + foes.length;
    out['floor'] = _int(out['floor']) + 1;
    String? drop, story;
    if (kind == 'boss' || kind == 'wildboss') out['bosses'] = ((out['bosses'] as num?) ?? 0).toInt() + 1;
    var champion = false;
    String? hm;
    // Venceu a revanche: o Campeão some (até o próximo).
    if (kind == 'rival') out['rivalRaces'] = ((run['rivalRaces'] as num?) ?? 0).toInt() + 1;
    // Venceu o chefe do lugar (ou o vilão na base): volta para a cidade.
    if (run['dungeon'] != null && (kind == 'dboss' || kind == 'boss' || run['encounter']['area'] == true)) {
      out['dungeons'] = ((run['dungeons'] as num?) ?? 0).toInt() + 1;
      final place = run['dungeon']['place'];
      if (place != 'base') out['places'] = [...(run['places'] as List? ?? const []), place];
      // Num lugar da água, dá para seguir para o próximo (o mar depois da praia...); nos outros, volta.
      if (place != 'base' && waterNext(run['dungeon']['scene']) != null) {
        out['dungeon'] = {...Map<String, dynamic>.from(run['dungeon'] as Map), 'cleared': true};
      } else {
        _leavePlace(run, out);
      }
    }
    if (kind == 'rematch') {
      out['rematch'] = null;
      out['rematches'] = ((run['rematches'] as num?) ?? 0).toInt() + 1;
    }
    if (kind == 'boss') {
      final beaten = run['encounter']['boss'] as Map;
      // As conquistas (progress): insígnias, ginásio só com o inicial, Campeões.
      if (beaten['kind'] == 'gym') {
        out['badges'] = ((run['badges'] as num?) ?? 0).toInt() + 1;
        if ((run['team'] as List).length == 1) out['soloGym'] = true;
        // As MOs vêm com as insígnias (Cut, Flash e Surf).
        hm = hmBadges[out['badges']];
        if (hm != null && !hasHm(run, hm)) {
          out['hms'] = [...(run['hms'] as List? ?? const []), hm];
        } else {
          hm = null;
        }
      }
      if (beaten['kind'] == 'champion') {
        out['champions'] = ((run['champions'] as num?) ?? 0).toInt() + 1;
        champion = true;
        // O Campeão vencido vai querer revanche na região seguinte.
        out['rematch'] = {'region': run['boss']['region']};
      }
      // O rival: as falas mudam conforme ele perde.
      if (beaten['kind'] == 'rival') out['rivalWins'] = ((run['rivalWins'] as num?) ?? 0).toInt() + 1;
      // Venceu o chefe da cidade (ou da Liga): começa a rota seguinte (num lugar que se liga ao da rota que acabou).
      if (_cityKinds.contains(beaten['kind'])) {
        out['prevBiome'] = routeBiome(data, {...run, 'dungeon': null});
        out['leg'] = out['floor'];
        out.remove('detour');
        out.remove('back');
        out.remove('places');
        out['town'] = null;
      }
      final (boss, played) = _nextBoss(out, data, rand);
      // Acabou a história da região: o fim dela e o começo da próxima.
      if (boss['step'] == 0) {
        story = '${storyLine(data, '${beaten['region']}', 'end')}\n\n${storyLine(data, '${data.bosses[_int(boss['region'])]['region']}', 'intro')}';
      }
      out['boss'] = boss;
      out['played'] = played;
      // Em Alola (onde existem os Z-Moves), o chefe deixa o Cristal Z do tipo do Pokémon mais forte dele.
      final ace = foes.last;
      final types = data.speciesOf(_int(ace['id']))?.elementAtOrNull(4) as List?;
      final crystal = types == null || types.isEmpty || run['encounter']['boss']['region'] != 'Alola' ? null : data.zcrystals['${types.first}'];
      if (crystal != null && !_hasItem(out, crystal)) drop = crystal;
    }
    // A Mega deixa a Mega Pedra (derrotando ou capturando).
    if (kind == 'wildboss' && foes.first['item'] != null && !_hasItem(out, '${foes.first['item']}')) drop = '${foes.first['item']}';
    if (drop != null) out['stash'] = [...((out['stash'] as List?) ?? const []), drop];
    // O treinador forte deixa um item: bolas e remédios na Bolsa, ficha de Move Tutor, os de segurar guardados.
    final reward = kind == 'ace' || kind == 'dboss' ? run['encounter']['reward'] as String? : null;
    if (reward != null && bagItems.contains(reward)) {
      (out['bag'] as Map)[reward] = (((out['bag'] as Map)[reward] as num?) ?? 0).toInt() + 1;
    } else if (reward != null && tokens.contains(reward)) {
      final t = Map<String, dynamic>.from((out['tokens'] as Map?) ?? const {});
      t[reward] = ((t[reward] as num?) ?? 0).toInt() + 1;
      out['tokens'] = t;
    } else if (reward != null) {
      out['stash'] = [...((out['stash'] as List?) ?? const []), reward];
    }
    // A missão da rota: os derrotados (e o capturado) do tipo contam; completa, dá dinheiro e um item.
    Json? mission;
    final m = run['mission'] as Map?;
    if (m != null && _int(m['done']) < _int(m['need'])) {
      bool fits(Map f) => ((data.speciesOf(_int(f['id']))?.elementAtOrNull(4) as List?) ?? const []).contains(m['type']);
      final add = m['kind'] == 'grunts'
          ? (run['encounter']['grunt'] != null ? 1 : 0)
          : m['kind'] == 'defeat'
              ? foes.where(fits).length
              : captured && fits(foes.first)
                  ? 1
                  : 0;
      if (add > 0) {
        final next = {...Map<String, dynamic>.from(m), 'done': math.min(_int(m['need']), _int(m['done']) + add)};
        out['mission'] = next;
        if (_int(next['done']) >= _int(m['need'])) {
          final item = _pick(aceRewards, rand);
          final cash = (missionMoney * priceScale(_int(run['floor']))).round();
          _giveItem(out, item);
          out['money'] = _int(out['money']) + cash;
          mission = {...next, 'item': item, 'money': cash};
        }
      }
    }
    final joy = rand() < joyChance;
    if (joy) out['team'] = [for (final m in teamOf(out)) {...m, 'hp': 1}];
    final cardsPick = kind == 'boss' ? _pickCards(rand, ((run['cardCount'] as num?) ?? 3).toInt()) : null;
    // A loja da cidade: chegando nela, logo antes do chefe (no resto da rota, os Poké Marts do mapa).
    final cityWin = kind == 'boss' && _cityKinds.contains(run['encounter']['boss']['kind']);
    final shopPick = !cityWin && atCity(data, out) && !_inLeague(data, out) && !townHub(data, out) ? _pickShop(rand, data, _int(run['floor']), 8, run['townMap'] == true) : null;
    out['pending'] = {
      'exp': exp, 'gains': gains, 'money': money, 'levels': levels, 'joy': joy, 'drop': drop, 'story': story, 'reward': reward,
      if (champion) 'champion': true,
      if (picked.isNotEmpty) 'picked': picked,
      if (lost.isNotEmpty) 'lost': lost,
      'capture': captured && (kind == 'wild' || kind == 'wildboss') ? foes.first : null,
      // A Poké Ball em que ele foi capturado (o sprite dela na tela da captura). Igual ao site.
      if (captured && ball != null) 'ball': ball,
      'cards': cardsPick,
      'shop': shopPick,
      // O chefe que acabou de perder (as falas depois da luta) e a missão completa.
      if (kind == 'boss' || kind == 'rival')
        'beat': {'kind': run['encounter']['boss']['kind'], 'name': run['encounter']['boss']['name'], 'region': run['encounter']['boss']['region']},
      if (mission != null) 'mission': mission,
      if (hm != null) 'hm': hm,
    };
    out['encounter'] = null;
    return out;
  }

  static List<String> _pickCards(double Function() rand, [int count = 3]) {
    final ids = cards.keys.toList();
    final out = <String>[];
    while (out.length < count) {
      final id = _pick(ids, rand);
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  /// Alguém do time (ou guardado) já tem esse item.
  static bool _hasItem(Json run, String id) =>
      ((run['stash'] as List?) ?? const []).contains(id) || teamOf(run).any((m) => m['item'] == id || ((m['extras'] as List?) ?? const []).contains(id));

  /// As bolas e os remédios em escada (do pior ao melhor) e as bolas especiais.
  static const ballTiers = ['poke-ball', 'great-ball', 'ultra-ball'];
  static const healTiers = ['potion', 'super-potion', 'hyper-potion', 'max-potion'];
  static const specialBalls = ['quick-ball', 'net-ball', 'dusk-ball', 'timer-ball'];

  /// Um item da escada: conforme o andar, os melhores ficam mais prováveis (um degrau a cada [step] andares). Igual ao site.
  /// Um da lista, com a chance de cada um proporcional ao peso. Igual ao site.
  static T _pickWeighted<T>(List<T> list, List<double> weights, double Function() rand) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var roll = rand() * total;
    for (var i = 0; i < list.length; i++) {
      roll -= weights[i];
      if (roll < 0) return list[i];
    }
    return list.last;
  }

  static String tierPick(List<String> list, int floor, int step, double Function() rand) {
    final p = math.min(list.length - 1, floor / step);
    final weights = <double>[for (var i = 0; i < list.length; i++) math.max(0.08, 1 - (i - p).abs()).toDouble()];
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var roll = rand() * total;
    for (var i = 0; i < list.length; i++) {
      roll -= weights[i];
      if (roll < 0) return list[i];
    }
    return list.last;
  }

  static List<String> _pickShop(double Function() rand, FactoryData data, int floor, [int size = 8, bool hasMap = false]) {
    final out = <String>[];
    void add(String id) {
      if (!out.contains(id)) out.add(id);
    }

    // Dois tipos de bola (melhores conforme o andar), às vezes uma especial; a Master Ball é rara.
    for (var k = 0; k < 4 && out.length < 2; k++) {
      add(tierPick(ballTiers, floor, 25, rand));
    }
    if (floor >= 5 && rand() < 0.6) add(_pick(specialBalls, rand));
    if (rand() < math.min(0.08, 0.01 + floor / 1500)) add('master-ball');
    // Dois remédios (melhores conforme o andar) e, às vezes, Revive.
    final before = out.length;
    for (var k = 0; k < 4 && out.length < before + 2; k++) {
      add(tierPick(healTiers, floor, 20, rand));
    }
    if (rand() < 0.5) add('revive');
    // O Mapa aparece fácil (até ser comprado).
    if (!hasMap && rand() < townMapChance) add('town-map');
    final ids = [for (final id in shop.keys) if (!ballIds.contains(id) && !healTiers.contains(id) && id != 'revive' && id != 'town-map') id];
    // TM e pedra de evolução, às vezes.
    if (data.tms.isNotEmpty && rand() < 0.6) out.add('tm:${_pick(data.tms, rand)}');
    if (data.stones.isNotEmpty && rand() < 0.45) out.add('evo:${_pick(data.stones, rand)}');
    while (out.length < size) {
      final id = _pick(ids, rand);
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  static Json? pendingOf(Json run) => run['pending'] == null ? null : Map<String, dynamic>.from(run['pending'] as Map);

  /// O Pokémon capturado na batalha entra no time (replace: posição a trocar com o time cheio).
  static Json capture(Json run, [int? replace]) {
    final foe = pendingOf(run)?['capture'];
    if (foe == null) return run;
    final out = _copy(run);
    final rand = _dice(out);
    var mon = newMon(_int(foe['id']), _int(foe['level']), rand, foe['egg'] == true ? eggIvs : 0, foe['shiny'] == true);
    // Synchronize em quem vai na frente: metade das vezes, o capturado vem com a Nature dele.
    final lead = _leadOf(run);
    if (foe['egg'] != true && lead != null && synchronize.contains(_int(lead['id'])) && rand() < 0.5) mon = {...mon, 'nature': lead['nature']};
    if (foe['mythic'] == true) out['mythics'] = ((run['mythics'] as num?) ?? 0).toInt() + 1;
    // Nuzlocke: só um capturado por rota.
    if (run['nuzlocke'] == true && foe['egg'] != true) out['caughtLeg'] = legOf(run);
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
    _addDex(out, _int(foe['id']));
    return out;
  }

  /// A Pokédex da corrida: quem você já teve (o inicial, os capturados, os trocados e os chocados). A cada marca, um prêmio.
  /// Igual ao site.
  static const dexRewards = <Json>[
    {'at': 5, 'item': 'great-ball', 'count': 3, 'money': 200},
    {'at': 10, 'item': 'ultra-ball', 'count': 3, 'money': 400},
    {'at': 15, 'item': 'max-potion', 'count': 2, 'money': 700},
    {'at': 20, 'item': 'revive', 'count': 3, 'money': 1000},
    {'at': 30, 'item': 'master-ball', 'count': 1, 'money': 2000},
  ];
  static List<int> dexOf(Json run) =>
      run['dex'] != null ? [for (final id in run['dex'] as List) _int(id)] : (run['starter'] != null ? [_int(run['starter'])] : <int>[]);

  /// O prêmio que entrar com id daria (null se ele já está na Pokédex ou não chega numa marca).
  static Json? dexRewardFor(Json run, int id) {
    final dex = dexOf(run);
    if (dex.contains(id)) return null;
    return dexRewards.where((r) => r['at'] == dex.length + 1).firstOrNull;
  }

  static void _addDex(Json out, int id) {
    final reward = dexRewardFor(out, id);
    if (dexOf(out).contains(id)) return;
    out['dex'] = [...dexOf(out), id];
    if (reward == null) return;
    final bag = Map<String, dynamic>.from(out['bag'] as Map);
    bag['${reward['item']}'] = ((bag[reward['item']] as num?) ?? 0).toInt() + (reward['count'] as int);
    out['bag'] = bag;
    out['money'] = _int(out['money']) + (reward['money'] as int);
  }

  /// As MOs (HMs): vêm com a 1ª, a 2ª e a 3ª insígnia. Cut abre um caminho escondido; Flash ilumina cavernas; Surf deixa
  /// mergulhar. Igual ao site.
  static const hmBadges = {1: 'cut', 2: 'flash', 3: 'surf'};
  static bool hasHm(Json run, String hm) => (run['hms'] as List? ?? const []).contains(hm);

  /// Sem Surf, não dá para mergulhar.
  static bool nodeBlocked(Json run, Map? node) =>
      ((node?['biome'] == 'underwater' && (run['route'] as Map?)?['biome'] != 'underwater') ||
          (node?['kind'] == 'dungeon' && const ['water', 'underwater'].contains(node?['scene']))) &&
      !hasHm(run, 'surf');

  /// Cut: uma vez por rota, corta a árvore e abre um caminho escondido (um selvagem raro do lugar). null se não dá.
  static Json? cutPath(Json run) {
    final route = run['route'] as Map?;
    final options = route?['options'] as List? ?? const [];
    if (!hasHm(run, 'cut') || route == null || options.length < 2 || run['encounter'] != null || run['pending'] != null) return null;
    if (run['cutLeg'] == (run['leg'] ?? 1)) return null;
    return {
      ...run,
      'cutLeg': run['leg'] ?? 1,
      'route': {
        ...Map<String, dynamic>.from(route),
        'options': [...options, {'kind': 'wild', 'biome': route['biome'], 'rare': true, 'cut': true}],
      },
    };
  }

  /// Dupla de treinadores: chance de um treinador vir acompanhado.
  static const doubleChance = 0.2;

  /// A partir deste andar, a dupla de treinadores é batalha dupla de verdade (2 contra 2), se você tem 2 de pé. Igual ao site.
  static const doubleFloor = 15;
  static bool isDoubleBattle(Json run) =>
      run['encounter']?['pair'] == true && _int(run['floor']) >= doubleFloor && teamOf(run).where((m) => hpOf(m) > 0).length >= 2;

  /// A revanche: o Campeão vencido vem com o time de alguns andares à frente.
  static const rematchFloors = 5;
  /// O começo da rota de agora (o andar depois da última cidade).
  static int legOf(Json run) => _int(run['floor']) - routePos(run) - _n(run, 'detour');

  /// O rival da região que aparece de surpresa: o último que você já enfrentou na história (ou o primeiro). null se a região
  /// não tem rival. Igual ao site.
  static Json? rivalBoss(FactoryData data, Json run) {
    final game = data.bosses[_int(run['boss']['region'])];
    final leaders = (game['leaders'] as List).cast<Map>();
    final step = _int(run['boss']['step']);
    final rivals = [for (var k = 0; k < leaders.length; k++) if (leaders[k]['kind'] == 'rival') k];
    if (rivals.isEmpty) return null;
    final met = rivals.where((k) => k < step).toList();
    return {'region': game['region'], 'game': game['game'], ...Map<String, dynamic>.from(leaders[met.isNotEmpty ? met.last : rivals.first])};
  }

  static Json rematchBoss(FactoryData data, Json run) {
    final game = data.bosses[_int(run['rematch']?['region'] ?? run['boss']['region'])];
    final leaders = (game['leaders'] as List).cast<Map>();
    final champ = leaders.where((l) => l['kind'] == 'champion').firstOrNull ?? leaders.last;
    return {'region': game['region'], 'game': game['game'], ...Map<String, dynamic>.from(champ)};
  }

  /// A Creche (na cidade): deixa um Pokémon, ele ganha um nível por andar; buscando depois de daycareEgg andares, vem junto
  /// um ovo (a forma básica dele, com IVs bons). Igual ao site.
  static const daycareEgg = 4;
  static const eggIvs = 20;
  static const eggLevel = 5;
  static Json? leaveDaycare(Json run, int index) {
    final team = teamOf(run);
    if (run['daycare'] != null || team.length < 2 || index < 0 || index >= team.length) return null;
    final mon = team.removeAt(index);
    return {...run, 'team': team, 'daycare': {'mon': mon, 'floor': run['floor']}};
  }

  static Json? takeDaycare(Json run, FactoryData data) {
    final care = run['daycare'] as Map?;
    if (care == null || teamOf(run).length >= maxTeam) return null;
    final out = _copy(run)..['daycare'] = null;
    final rand = _dice(out);
    final steps = math.max(0, _int(run['floor']) - _int(care['floor']));
    final mon = Map<String, dynamic>.from(care['mon'] as Map);
    final (grown, _) = levelTo(mon, _int(mon['level']) + steps, data, rand);
    out['team'] = [...teamOf(run), grown];
    if (steps >= daycareEgg) {
      out['pending'] = {
        ...Map<String, dynamic>.from(run['pending'] as Map? ?? const {}),
        'capture': {'id': baseForm(data, _int(mon['id'])), 'level': eggLevel, 'egg': true},
      };
    }
    return out;
  }

  /// Solta o capturado (o time está cheio e você não quer trocar ninguém).
  static Json skipCapture(Json run) {
    if (run['pending'] == null) return run;
    final out = _copy(run);
    (out['pending'] as Map)['capture'] = null;
    return out;
  }

  /// A troca: quem está na posição index vai e vem o oferecido, tradeLevels níveis acima (evolui se der), com o item dele. Igual ao site.
  static const tradeLevels = 3;
  static Json tradeMon(Json run, int index, FactoryData data) {
    final offer = pendingOf(run)?['trade'] as Map?;
    final team = teamOf(run);
    if (offer == null || index < 0 || index >= team.length) return run;
    final mon = team[index];
    final out = _copy(run);
    (out['pending'] as Map)['trade'] = null;
    out['trades'] = ((run['trades'] as num?) ?? 0).toInt() + 1;
    final rand = _dice(out);
    final level = _int(mon['level']);
    final fresh = newMon(devolve(data, _int(offer['id']), level), level, rand, 10, offer['shiny'] == true);
    final (grown, _) = levelTo(fresh, level + tradeLevels, data, rand);
    team[index] = {...grown, 'item': mon['item'], 'extras': mon['extras'] ?? <String>[]};
    out['team'] = team;
    _addDex(out, _int(grown['id']));
    return out;
  }

  /// Sorteia os caminhos do andar de novo (melhoria "reroll": algumas vezes por corrida). null se não dá. Igual ao site.
  static Json? rerollRoute(Json run, FactoryData data) {
    final left = ((run['rerolls'] as num?) ?? 0).toInt();
    if (left <= 0 || run['route'] == null || run['encounter'] != null || run['pending'] != null) return null;
    final out = _copy(run)..['rerolls'] = left - 1;
    out['route'] = routeOptions(out, data, _dice(out));
    return out;
  }

  /// Recusa a troca.
  /// O clima de cada lugar (chances): sol e areia no deserto, chuva no mar e no pântano, neve na neve e na caverna de gelo,
  /// sol no vulcão; às vezes sol ou chuva na grama, na floresta e na cidade. Lugares fechados sem clima. Igual ao site.
  static const sceneWeather = <String, List<(String, double)>>{
    'desert': [('sand', 0.45), ('sun', 0.25)], 'volcano': [('sun', 0.6)], 'snow': [('snow', 0.65)], 'icecave': [('snow', 0.5)], 'lavacave': [('sun', 0.4)], 'seacave': [('rain', 0.2)],
    'beach': [('sun', 0.35), ('rain', 0.15)], 'water': [('rain', 0.35), ('sun', 0.15)], 'swamp': [('rain', 0.45)],
    'grass': [('sun', 0.15), ('rain', 0.15)], 'forest': [('rain', 0.2), ('sun', 0.1)], 'mountain': [('sand', 0.15), ('snow', 0.15), ('sun', 0.1)],
    'sky': [('sun', 0.2), ('rain', 0.2)], 'city': [('rain', 0.12), ('sun', 0.12)],
    'ruins': [('sand', 0.2), ('sun', 0.15)], 'flowers': [('sun', 0.25), ('rain', 0.1)], 'dunes': [('sand', 0.3)], 'bamboo': [('rain', 0.2), ('sun', 0.1)],
  };

  /// A música de cada lugar (selvagens e treinadores da rota; os chefes têm a deles): temas originais por grupo. Igual ao site.
  static const placeMusicGroups = {
    'field': ['grass', 'flowers', 'bamboo'], 'forest': ['forest', 'swamp'], 'sea': ['water', 'beach', 'underwater'],
    'cave': ['cave', 'icecave', 'crystal', 'sewer', 'lavacave', 'poisoncave', 'seacave'], 'mountain': ['mountain', 'snow', 'ruins', 'temple', 'sky'], 'desert': ['desert', 'dunes', 'volcano'],
    'city': ['city', 'plant'], 'spooky': ['tower'],
  };
  static String placeMusic(String scene) {
    if (scene.startsWith('base-')) return 'place_city';
    final group = placeMusicGroups.entries.where((e) => e.value.contains(scene)).firstOrNull?.key;
    return group != null ? 'place_$group' : 'battle_music';
  }

  /// Quem cura fora da cidade (a Enfermeira Joy só fica no Centro Pokémon da cidade): um por andar. Igual ao site.
  static const healers = [('sd-pokemonbreederf', 'Pokémon Breeder'), ('sd-doctor', 'Doctor'), ('sd-pokemonrangerf', 'Pokémon Ranger'), ('sd-aromalady', 'Aroma Lady')];
  static (String, String) healerOf(Json run) => healers[(_int(run['seed'] ?? 0) + _int(run['floor'])) % healers.length];

  /// Os lugares da cidade (onde ficam o Poké Mart e a Enfermeira Joy).
  static bool inTown(String scene) => scene == 'city' || scene == 'center' || scene == 'tower' || scene.startsWith('gym-') || scene.startsWith('champion-');

  /// As estações (como no Black & White: mudam a cada mês) e a noite (pelo relógio de verdade). Igual ao site.
  static const seasons = ['spring', 'summer', 'autumn', 'winter'];

  /// Os tipos que aparecem mais em cada estação e à noite.
  static const seasonTypes = {'spring': ['grass', 'fairy'], 'summer': ['fire', 'water'], 'autumn': ['bug', 'ground'], 'winter': ['ice']};
  static const nightTypes = ['ghost', 'dark'];

  /// No inverno, neva nos lugares abertos.
  static const winterSnow = ['grass', 'forest', 'flowers', 'bamboo', 'mountain', 'city', 'ruins', 'beach'];

  /// A hora e a estação de agora: noite das 19h às 6h; a estação pelo mês (jan primavera, fev verão, mar outono, abr inverno...).
  static ({bool night, String season}) clockOf([DateTime? date]) {
    final now = date ?? DateTime.now();
    return (night: now.hour >= 19 || now.hour < 6, season: seasons[(now.month - 1) % 4]);
  }

  /// O clima com que a batalha do andar começa ('' sem clima): pelo lugar, sempre o mesmo para a mesma corrida e andar.
  static String weatherOf(Json run, String scene, [String? season]) {
    final table = season == 'winter' && winterSnow.contains(scene) ? [('snow', 0.35), ...?sceneWeather[scene]] : sceneWeather[scene];
    if (table == null) return '';
    final mixed = (_int(run['seed'] ?? 0) ^ ((_int(run['floor']) * 40503) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    var roll = ((mixed * 2246822519) & 0xFFFFFFFF) / 4294967296;
    for (final (weather, chance) in table) {
      if (roll < chance) return weather;
      roll -= chance;
    }
    return '';
  }

  /// O efeito de cada lugar (chances): terrenos de verdade, os efeitos do lugar que ferem ou curam por turno e, no céu,
  /// ventos fortes (Delta Stream). Os ginásios têm o terreno do tipo. Igual ao site.
  static const sceneField = <String, List<(String, double)>>{
    'cave': [('diamonds', 0.3)], 'mountain': [('rockfall', 0.25)], 'volcano': [('ashes', 0.4)], 'swamp': [('miasma', 0.35)], 'sewer': [('miasma', 0.25)],
    'icecave': [('chill', 0.35), ('aurora', 0.1)], 'snow': [('chill', 0.2), ('aurora', 0.2)], 'tower': [('haunt', 0.35), ('psychic', 0.15)], 'underwater': [('current', 0.4)], 'water': [('current', 0.15)],
    'grass': [('grassy', 0.2)], 'forest': [('grassy', 0.3), ('misty', 0.1)], 'city': [('electric', 0.25)], 'beach': [('misty', 0.1)], 'sky': [('wind', 0.3), ('storm', 0.15)],
    'desert': [('quicksand', 0.2)], 'ruins': [('psychic', 0.2), ('haunt', 0.15)], 'flowers': [('spores', 0.3), ('misty', 0.15)], 'plant': [('storm', 0.35), ('electric', 0.25)],
    'crystal': [('diamonds', 0.4)], 'lavacave': [('ashes', 0.4)], 'poisoncave': [('miasma', 0.4)], 'seacave': [('current', 0.3)], 'dunes': [('quicksand', 0.35), ('haunt', 0.1)], 'bamboo': [('spores', 0.2), ('grassy', 0.2)], 'temple': [('psychic', 0.3)],
    'gym-grass': [('grassy', 0.6)], 'gym-electric': [('electric', 0.6)], 'gym-psychic': [('psychic', 0.6)], 'gym-fairy': [('misty', 0.6)], 'gym-ghost': [('haunt', 0.6)],
    'gym-rock': [('rockfall', 0.4)], 'gym-fire': [('ashes', 0.4)], 'gym-poison': [('miasma', 0.4)], 'gym-ice': [('chill', 0.4)], 'gym-water': [('current', 0.4)],
  };

  /// O efeito com que a batalha do andar começa ('' sem efeito): pelo lugar, sempre o mesmo para a mesma corrida e andar.
  static String fieldOf(Json run, String scene) {
    final table = sceneField[scene];
    if (table == null) return '';
    final mixed = (_int(run['seed'] ?? 0) ^ ((_int(run['floor']) * 69069) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    var roll = ((mixed * 2654435761) & 0xFFFFFFFF) / 4294967296;
    for (final (effect, chance) in table) {
      if (roll < chance) return effect;
      roll -= chance;
    }
    return '';
  }

  /// Chance de o Mapa estar na loja (até ser comprado).
  static const townMapChance = 0.75;

  /// Sem o Mapa, na bifurcação você não vê os caminhos: segue por um deles às cegas (sempre o mesmo para a mesma corrida e
  /// andar). Igual ao site (blindPick).
  static int blindPick(Json run) {
    final n = ((run['route'] as Map?)?['options'] as List?)?.length ?? 1;
    final mixed = (_int(run['seed'] ?? 0) ^ ((_int(run['floor']) * 2654435761) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    final first = ((mixed * 1597334677) & 0xFFFFFFFF) % n;
    // Sem Surf, não mergulha: o próximo caminho.
    final options = (run['route'] as Map?)?['options'] as List?;
    for (var k = 0; k < n; k++) {
      if (!nodeBlocked(run, options?[(first + k) % n] as Map?)) return (first + k) % n;
    }
    return first;
  }

  /// Quem abre a batalha: passa o Pokémon da posição para a frente do time (para treinar os mais fracos). Igual ao site.
  static Json setLead(Json run, int index) {
    final team = teamOf(run);
    if (index <= 0 || index >= team.length) return run;
    final mon = team.removeAt(index);
    return {...run, 'team': [mon, ...team]};
  }

  static Json skipTrade(Json run) {
    if (run['pending'] == null) return run;
    final out = _copy(run);
    (out['pending'] as Map)['trade'] = null;
    return out;
  }

  /// Perdeu com uma Escape Rope na Bolsa: gasta ela e o time foge com pouco HP (escapeHp), no mesmo andar, com o mapa
  /// de novo. hp e bag: como a batalha terminou (factoryAfter). null sem a corda. Igual ao site.
  static Json? escapeRope(Json run, FactoryData data, {List<double>? hp, Map<String, int>? bag}) {
    final ropes = (((run['bag'] as Map?)?['escape-rope'] as num?) ?? 0).toInt();
    if (ropes <= 0) return null;
    final out = _copy(run);
    out['bag'] = {...Map<String, dynamic>.from(run['bag'] as Map), ...?bag, 'escape-rope': ropes - 1};
    final team = teamOf(run);
    out['team'] = [for (var i = 0; i < team.length; i++) {...team[i], 'hp': math.max(hp != null && i < hp.length ? hp[i] : 0.0, escapeHp)}];
    out['encounter'] = null;
    out['pending'] = null;
    out['ropes'] = ((run['ropes'] as num?) ?? 0).toInt() + 1;
    // Dentro de um lugar (esgoto, base vilã...), a corda leva de volta para onde você entrou (a rota ou a cidade).
    if (run['dungeon'] != null) _leavePlace(run, out);
    out['route'] = routeOptions(out, data, _dice(out));
    return out;
  }

  /// Conquistas da Battle Factory: cada uma dá moedas uma vez só (fica na conta). Igual ao site.
  static final achievements = <String, ({String label, int coins, bool Function(Json run) done})>{
    'badge': (label: 'Primeira insígnia', coins: 50, done: (r) => _n(r, 'badges') >= 1),
    'badges8': (label: '8 insígnias numa corrida', coins: 300, done: (r) => _n(r, 'badges') >= 8),
    'solo': (label: 'Vencer um ginásio só com o inicial', coins: 250, done: (r) => r['soloGym'] == true),
    'champion': (label: 'Vencer um Campeão (Hall da Fama)', coins: 600, done: (r) => _n(r, 'champions') >= 1),
    'champion2': (label: 'Vencer o Campeão de duas regiões', coins: 1500, done: (r) => _n(r, 'champions') >= 2),
    'floor25': (label: 'Chegar ao andar 25', coins: 100, done: (r) => _n(r, 'floor') > 25),
    'floor50': (label: 'Chegar ao andar 50', coins: 300, done: (r) => _n(r, 'floor') > 50),
    'floor100': (label: 'Chegar ao andar 100', coins: 1000, done: (r) => _n(r, 'floor') > 100),
    'full': (label: 'Time completo (6 Pokémon)', coins: 80, done: (r) => teamOf(r).length >= maxTeam),
    'shiny': (label: 'Um shiny no time', coins: 200, done: (r) => teamOf(r).any((m) => m['shiny'] == true)),
    'level50': (label: 'Um Pokémon no nível 50', coins: 150, done: (r) => teamOf(r).any((m) => _int(m['level']) >= 50)),
    'level100': (label: 'Um Pokémon no nível 100', coins: 400, done: (r) => teamOf(r).any((m) => _int(m['level']) >= 100)),
    'trade': (label: 'Fazer uma troca', coins: 40, done: (r) => _n(r, 'trades') >= 1),
    'rope': (label: 'Escapar com a Escape Rope', coins: 40, done: (r) => _n(r, 'ropes') >= 1),
    'dungeon': (label: 'Vencer o chefe de um lugar (esgoto, casa assombrada...)', coins: 120, done: (r) => _n(r, 'dungeons') >= 1),
    'dungeon5': (label: 'Vencer 5 lugares numa corrida', coins: 400, done: (r) => _n(r, 'dungeons') >= 5),
    'rival3': (label: 'Vencer o rival de surpresa 3 vezes', coins: 150, done: (r) => _n(r, 'rivalRaces') >= 3),
    'dex30': (label: '30 na Pokédex da corrida', coins: 300, done: (r) => dexOf(r).length >= 30),
    'friend': (label: 'Evoluir um Pokémon pela amizade', coins: 150, done: (r) => _n(r, 'friendEvos') >= 1),
    'mythic': (label: 'Capturar um Pokémon mítico', coins: 500, done: (r) => _n(r, 'mythics') >= 1),
    'meteor': (label: 'Ver uma chuva de meteoros', coins: 100, done: (r) => _n(r, 'meteors') >= 1),
    'nuzlocke': (label: 'Ganhar uma insígnia no Nuzlocke', coins: 300, done: (r) => r['nuzlocke'] == true && _n(r, 'badges') >= 1),
  };
  static int _n(Json r, String k) => ((r[k] as num?) ?? 0).toInt();

  /// As conquistas novas da corrida (com as moedas delas) e o Hall da Fama (o time que venceu o Campeão). Igual ao site.
  static (Json, List<String>) progress(Json factory, Json? run) {
    if (run == null) return (factory, const []);
    final have = [for (final x in (factory['achievements'] as List?) ?? const []) '$x'];
    final earned = [for (final e in achievements.entries) if (!have.contains(e.key) && e.value.done(run)) e.key];
    var out = factory;
    if (earned.isNotEmpty) {
      out = {...out, 'achievements': [...have, ...earned], 'coins': _int(out['coins']) + earned.fold<int>(0, (s, id) => s + achievements[id]!.coins)};
    }
    if (pendingOf(run)?['champion'] == true) {
      final key = '${run['seed']}-${run['floor']}';
      final hall = [for (final h in (out['hall'] as List?) ?? const []) Map<String, dynamic>.from(h as Map)];
      if (!hall.any((h) => h['key'] == key)) {
        final entry = {
          'key': key, 'floor': _int(run['floor']) - 1, 'champions': _n(run, 'champions') == 0 ? 1 : _n(run, 'champions'),
          'team': [for (final m in teamOf(run)) {'id': m['id'], 'level': m['level'], if (m['shiny'] == true) 'shiny': true}],
        };
        out = {...out, 'hall': [entry, ...hall].take(20).toList()};
      }
    }
    return (out, earned);
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
    if (card.balls > 0) {
      final bag = Map<String, dynamic>.from(out['bag'] as Map);
      bag['poke-ball'] = ((bag['poke-ball'] as num?) ?? 0).toInt() + card.balls;
      out['bag'] = bag;
    }
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
    // O Rare Candy sobe com o nível do time (e não com o tamanho dos times dos treinadores).
    final candy = id == 'rare-candy';
    final top = candy ? teamOf(run).fold(startLevel, (int a, m) => math.max(a, _int(m['level']))) : startLevel;
    final base = id.startsWith('tm:') ? tmPrice : id.startsWith('evo:') ? evoPrice : shop[id] ?? 0;
    final scale = candy ? 1 + (_int(run['floor']) - 1) / 20 : priceScale(_int(run['floor']));
    return math.max(1, (base * scale * (top / startLevel) * _mult(run, 'shop')).round());
  }

  /// Evoluções que o Pokémon faz com o item (pedra).
  static List<int> canEvolveWith(FactoryData data, Map mon, String item) =>
      [for (final e in data.evolutions[_int(mon['id'])] ?? const <List>[]) if (e.length > 2 && e[2] == item) e[0] as int];

  /// Dynamax Band e Tera Orb são uma vez só.
  static bool shopOwned(Json run, String id) => (id == 'dynamax-band' && run['dmax'] == true) || (id == 'tera-orb' && run['tera'] == true) || (id == 'exp-share' && run['expShare'] == true) || (id == 'town-map' && run['townMap'] == true);

  /// Compra um item da loja (index: o Pokémon que recebe; itens da Bolsa e Poké Ball não precisam). null se não dá.
  static Json? buyItem(Json run, String id, int index, FactoryData data) {
    if (!shop.containsKey(id) && !id.startsWith('tm:') && !id.startsWith('evo:')) return null;
    final price = shopPrice(run, id);
    if (!((pendingOf(run)?['shop'] as List?)?.contains(id) ?? false) || (run['money'] as num) < price || shopOwned(run, id)) return null;
    final out = _copy(run);
    out['money'] = _int(out['money']) - price;
    if (id == 'dynamax-band') return out..['dmax'] = true;
    if (id == 'tera-orb') return out..['tera'] = true;
    if (id == 'exp-share') return out..['expShare'] = true;
    if (id == 'town-map') return out..['townMap'] = true;
    if (tokens.contains(id)) {
      final t = Map<String, dynamic>.from((out['tokens'] as Map?) ?? const {});
      t[id] = ((t[id] as num?) ?? 0).toInt() + 1;
      return out..['tokens'] = t;
    }
    if (id.startsWith('tm:')) {
      final tms = Map<String, dynamic>.from((out['tms'] as Map?) ?? const {});
      final move = id.substring(3);
      tms[move] = ((tms[move] as num?) ?? 0).toInt() + 1;
      return out..['tms'] = tms;
    }
    if (bagItems.contains(id)) {
      final bag = Map<String, dynamic>.from(out['bag'] as Map);
      bag[id] = ((bag[id] as num?) ?? 0).toInt() + 1;
      return out..['bag'] = bag;
    }
    final team = teamOf(out);
    if (index < 0 || index >= team.length) return null;
    final mon = team[index];
    if (id.startsWith('evo:')) {
      // Pedra de evolução: evolui na hora (se ele evolui com ela).
      final to = canEvolveWith(data, mon, id.substring(4));
      if (to.isEmpty) return null;
      team[index] = {...mon, 'id': to.first};
    } else if (id == 'rare-candy') {
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
  /// Tira o item (extra: a posição de um extra; sem ela, o principal) e guarda: dá para equipar em outro. Igual ao site.
  static Json unequipItem(Json run, int index, [int? extra]) {
    final team = teamOf(run);
    if (index < 0 || index >= team.length) return run;
    final mon = team[index];
    final extras = [for (final x in (mon['extras'] as List?) ?? const []) '$x'];
    final id = extra == null ? mon['item'] as String? : (extra >= 0 && extra < extras.length ? extras[extra] : null);
    if (id == null) return run;
    if (extra == null) {
      team[index] = {...mon, 'item': null};
    } else {
      extras.removeAt(extra);
      team[index] = {...mon, 'extras': extras};
    }
    return {...run, 'team': team, 'stash': [...(run['stash'] as List? ?? const []), id]};
  }

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

  /// Ensina um golpe (TM, Move Tutor ou Move Reminder): gasta o TM ou a ficha e troca o golpe da posição slot (ou acrescenta). Igual ao site.
  static Json? teachMove(Json run, int index, String move, List<String> current, int slot, String source) {
    final team = teamOf(run);
    if (index < 0 || index >= team.length || move.isEmpty || current.contains(move)) return null;
    final out = {...run};
    if (source == 'tm') {
      final tms = Map<String, dynamic>.from((run['tms'] as Map?) ?? const {});
      if (!(((tms[move] as num?) ?? 0) > 0)) return null;
      tms[move] = _int(tms[move]) - 1;
      out['tms'] = tms;
    } else if (tokens.contains(source)) {
      final t = Map<String, dynamic>.from((run['tokens'] as Map?) ?? const {});
      if (!(((t[source] as num?) ?? 0) > 0)) return null;
      t[source] = _int(t[source]) - 1;
      out['tokens'] = t;
    } else {
      return null;
    }
    final moves = [...current];
    if (moves.length < 4) {
      moves.add(move);
    } else if (slot >= 0 && slot < moves.length) {
      moves[slot] = move;
    } else {
      return null;
    }
    team[index] = {...team[index], 'moves': moves};
    return out..['team'] = team;
  }

  /// Dá um item guardado (Mega Pedra, Cristal Z) para um Pokémon: vira o principal (o antigo vai para os extras).
  static Json equipFromStash(Json run, int stashIndex, int index) {
    final stash = [for (final x in (run['stash'] as List?) ?? const []) '$x'];
    final team = teamOf(run);
    if (stashIndex < 0 || stashIndex >= stash.length || index < 0 || index >= team.length) return run;
    final id = stash.removeAt(stashIndex);
    final mon = team[index];
    final extras = [for (final x in (mon['extras'] as List?) ?? const []) '$x', if (mon['item'] != null) '${mon['item']}'];
    team[index] = {...mon, 'item': id, 'extras': extras};
    return {...run, 'team': team, 'stash': stash};
  }

  /// As mecânicas que ele pode usar: Mega (com a Mega Pedra dele), Z (com Cristal Z), Dynamax (Band) e Tera (Orb).
  static List<String> gimmicksOf(FactoryData data, Json run, Map mon) {
    final out = <String>[];
    final item = mon['item'];
    final species = data.forms[_int(mon['id'])] ?? _int(mon['id']);
    if (item != null && (data.megas[species] ?? const []).any((m) => m[0] == item)) out.add('mega');
    if (item != null && data.zcrystals.values.contains(item)) out.add('z');
    if (run['dmax'] == true) out.add('dmax');
    if (run['tera'] == true) out.add('tera');
    return out;
  }

  /// A mecânica dele na batalha: a escolhida (se ainda pode) ou a primeira que tiver.
  static String gimmickOf(FactoryData data, Json run, Map mon) {
    final options = gimmicksOf(data, run, mon);
    final chosen = mon['gimmick'];
    if (options.contains(chosen)) return '$chosen';
    if (chosen == 'none') return '';
    return options.isEmpty ? '' : options.first;
  }

  static Json setGimmick(Json run, int index, String gimmick) {
    final team = teamOf(run);
    team[index] = {...team[index], 'gimmick': gimmick};
    return {...run, 'team': team};
  }

  /// O time inteiro desmaiado (não dá para seguir).
  static bool teamDown(Json run) => teamOf(run).every((m) => !(hpOf(m) > 0));

  /// Sai da loja (ou não tinha): os caminhos do próximo andar no mapa.
  static Json nextFloor(Json run, FactoryData data) {
    final out = _copy(run)
      ..['pending'] = null
      ..['encounter'] = null;
    final rand = _dice(out);
    // Chegou na cidade: o estoque do Poké Mart dela e o lugar com batalha perto dela.
    if (townHub(data, out) && out['town']?['leg'] != legOf(out)) {
      out['town'] = {'leg': legOf(out), 'shop': _pickShop(rand, data, _int(out['floor']), 8, run['townMap'] == true)};
    }
    out['route'] = routeOptions(out, data, rand);
    // Começo de uma rota nova: a missão dela.
    if (routePos(out) == 0 && !atCity(data, out) && run['mission']?['leg'] != _int(out['leg'] ?? 1)) out['mission'] = newMission(out, data, rand);
    return out;
  }

  /// Perdeu: a corrida acaba; a pontuação vira moedas e o recorde fica salvo.
  /// A corrida da semana (o torneio entre amigos): a mesma semente, o mesmo inicial e uma regra para todo mundo na semana
  /// ({week}: a segunda-feira, "AAAA-MM-DD"); o ranking é o andar alcançado. Igual ao site.
  static const weeklyRules = ['normal', 'nuzlocke', 'noItems'];
  static ({String week, int seed, int starter, String rule}) weeklyOf(FactoryData data, String week) {
    var h = 2166136261;
    for (final ch in week.codeUnits) {
      h = ((h ^ ch) * 16777619) & 0xFFFFFFFF;
    }
    return (week: week, seed: h, starter: data.starters[h % data.starters.length], rule: weeklyRules[(h >> 8) % weeklyRules.length]);
  }

  static Json? startWeekly(Json factory, FactoryData data, String week) {
    final w = weeklyOf(data, week);
    return startRun(factory, data, w.starter, w.seed, weekly: week, rule: w.rule, nuzlocke: w.rule == 'nuzlocke');
  }

  /// A loja de cosméticos (com as moedas da Factory): a Poké Ball que você joga nas batalhas e a moldura da caixa de texto.
  /// Igual ao site.
  static const cosmeticBalls = {
    'premier-ball': 300, 'luxury-ball': 600, 'heal-ball': 300, 'friend-ball': 400, 'love-ball': 500, 'moon-ball': 500,
    'fast-ball': 400, 'dusk-ball': 400, 'dream-ball': 1000, 'beast-ball': 1200, 'cherish-ball': 1500,
  };
  static const cosmeticFrames = {'gold': 500, 'crystal': 600, 'night': 400, 'sakura': 600};
  static bool hasCosmetic(Json factory, String kind, String id) => ((factory['cosmetics']?[kind] as List?) ?? const []).contains(id);

  /// Compra (com moedas) e já usa; null sem moedas ou se não existe.
  static Json? buyCosmetic(Json factory, String kind, String id) {
    final price = (kind == 'ball' ? cosmeticBalls : cosmeticFrames)[id];
    if (price == null || hasCosmetic(factory, kind, id) || _int(factory['coins']) < price) return null;
    final cosmetics = {...Map<String, dynamic>.from((factory['cosmetics'] as Map?) ?? const {}), kind: [...((factory['cosmetics']?[kind] as List?) ?? const []), id]};
    return {...factory, 'coins': _int(factory['coins']) - price, 'cosmetics': cosmetics, kind == 'ball' ? 'ball' : 'frame': id};
  }

  /// Usa um que já tem (null volta para o padrão).
  static Json equipCosmetic(Json factory, String kind, String? id) {
    if (id != null && !hasCosmetic(factory, kind, id)) return factory;
    return {...factory, kind == 'ball' ? 'ball' : 'frame': id};
  }

  static Json endRun(Json factory, Json run) {
    // A melhoria de moedas soma uma porcentagem ao que a corrida rendeu.
    // Moedas a mais: a melhoria Moedas e todas as de efeito 'coins' (Tesouro e os nós pequenos).
    var bonus = upgradeValue(factory, 'coins');
    for (final e in upgradeFx.entries) {
      if (e.value.$1 == 'coins') bonus += upgradeValue(factory, e.key);
    }
    final coins = (runCoins(run) * (1 + bonus / 100)).round();
    return {
      ...factory,
      'coins': _int(factory['coins']) + coins,
      'best': math.max(_int(factory['best']), _int(run['floor']) - 1),
      'run': null,
      'last': {'floor': _int(run['floor']) - 1, 'coins': coins, if (run['weekly'] != null) 'weekly': run['weekly']},
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

  /// A Bolsa de cada lado: a sua é a da corrida; só os chefes da história usam itens. Igual ao site.
  static List<Map<String, int>?> bagsFor(Json run) {
    final floor = _int(run['floor']);
    final kind = run['encounter']?['kind'];
    final none = {for (final id in bagItems) id: 0};
    final foe = kind == 'boss'
        ? {...none, 'hyper-potion': 1 + floor ~/ 40, 'max-potion': floor >= 60 ? 1 : 0, 'revive': floor >= 100 ? 1 : 0}
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
  static (int, Json) memberOf(Json run, Json mon, List<String> moveList, [FactoryData? data]) {
    final gimmick = data == null ? '' : gimmickOf(data, run, mon);
    final own = [for (final m in (mon['moves'] as List?) ?? const []) '$m'];
    return (
        _int(mon['id']),
        {
          'level': mon['level'], 'levelCap': 'none', 'nature': mon['nature'], 'ivs': _cap(mon['ivs'] as Map?, 31), 'evs': _cap(mon['evs'] as Map?, 252),
          'item': mon['item'] ?? '', 'moves': own.isNotEmpty ? own : moveList, 'lockMoves': true, 'shiny': mon['shiny'] == true,
          if (gimmick.isNotEmpty) 'gimmick': gimmick,
          'bonus': overflowPoints(mon['ivs'] as Map?, mon['evs'] as Map?, _int(mon['level'])), 'boost': boostOf(run, mon), 'hpRatio': hpOf(mon),
        }
      );
  }

  /// Os tipos para o Terastal dos chefes dos lugares.
  static const teraTypes = ['normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy'];

  /// Os chefes dos lugares (fim da rota, cavernas, mar...): Mega (se ele tiver), senão Gigantamax (se tiver), senão Tera de um tipo ao acaso.
  static Json bossGimmick(FactoryData data, Json f, double Function() rand) {
    final megas = data.megas[_int(f['id'])] ?? const [];
    if (megas.isNotEmpty) return {...f, 'item': _pick(megas, rand)[0], 'gimmick': 'mega'};
    if (data.gmax.contains(_int(f['id']))) return {...f, 'gimmick': 'dmax'};
    return {...f, 'gimmick': 'tera', 'tera': _pick(teraTypes, rand)};
  }

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
        if (foe['item'] != null) 'item': foe['item'],
        if (foe['gimmick'] != null) 'gimmick': foe['gimmick'],
        if (foe['tera'] != null) 'tera': foe['tera'],
      }
    );
  }
}
