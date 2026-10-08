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
  const FactoryData(this.species, this.evolutions, this.starters,
      [this.bosses = const [], this.forms = const {}, this.megas = const {}, this.gmax = const [], this.zcrystals = const {},
      this.tms = const [], this.stones = const [], this.stories = const {}]);

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
  static const bagItems = [...ballIds, 'potion', 'super-potion', 'hyper-potion', 'max-potion', 'revive'];

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
  static double _pow14(double x) {
    final x2 = x * x, x4 = x2 * x2, x8 = x4 * x4;
    return x8 * x4 * x2;
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

  static Json empty() => {'best': 0, 'coins': 0, 'owned': <int>[], 'shinies': <int>[], 'run': null};
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

  /// Compra um Pokémon com as moedas (null se não dá). roll (0 a 1): 1 em 4096 de vir shiny.
  static Json? buyPokemon(Json factory, FactoryData data, int id, [double roll = 1]) {
    final info = data.species[id];
    final owned = ownedOf(factory);
    if (info == null || owned.contains(id) || freePick(factory)) return null;
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

  /// Sobe para o nível (com as evoluções que ele alcançar): (mon, evoluiu para).
  static (Json, int?) levelTo(Json mon, int level, FactoryData data, double Function() rand) {
    var out = {...mon, 'level': math.max(1, level)};
    out['exp'] = math.max(((out['exp'] as num?) ?? 0).toInt(), expAt(out['level'] as int));
    int? evolved;
    for (var guard = 0; guard < 3; guard++) {
      // Evoluções por item (pedras) só com o item: canEvolveWith/buyItem.
      final options = [for (final e in data.evolutions[_int(out['id'])] ?? const <List>[]) if (e.length < 3 && (out['level'] as int) >= (e[1] as int)) e];
      if (options.isEmpty) break;
      final to = _pick(options, rand)[0] as int;
      out = {...out, 'id': to};
      evolved = to;
    }
    return (out, evolved);
  }

  /// XP de derrotar um adversário (a conta está no site). Igual ao site.
  static int expFor(int baseExp, int foeLevel, int level, [double factor = 1]) {
    final scale = math.min(50.0, _pow14((foeLevel + 10) / (level + 10)));
    final species = math.min(1.6, math.max(0.6, math.sqrt(baseExp / 100)));
    return (3.5 * foeLevel * foeLevel * species * scale * factor).floor();
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

  /// Nível de um chefe: quem é mais forte que as espécies do andar vem com nível menor.
  static int _bossLevel(FactoryData data, int floor, int id, int lvl) => math.max(2, (lvl * _pow15(math.min(1, speciesBudget(floor) / data.bstOf(id)))).round());

  // ------------------------------------------------------------ mapa

  /// Biomas das rotas: os tipos dos Pokémon selvagens que aparecem nelas. Igual ao site.
  static const biomes = <String, List<String>>{
    'grass': ['normal', 'grass', 'bug', 'flying'],
    'forest': ['bug', 'grass', 'poison', 'fairy'],
    'water': ['water', 'ice', 'flying'],
    'cave': ['rock', 'ground', 'dark', 'poison'],
    'mountain': ['rock', 'fighting', 'ground', 'steel', 'dragon'],
    'volcano': ['fire', 'rock', 'ground'],
    'city': ['electric', 'steel', 'psychic', 'normal'],
    'snow': ['ice', 'water'],
    'tower': ['ghost', 'psychic', 'dark'],
    'sky': ['flying', 'dragon', 'fairy'],
  };
  static final biomeIds = biomes.keys.toList();
  static const _typeBiome = {
    'normal': 'grass', 'fire': 'volcano', 'water': 'water', 'grass': 'forest', 'electric': 'city', 'ice': 'snow', 'fighting': 'mountain', 'poison': 'forest',
    'ground': 'mountain', 'flying': 'sky', 'psychic': 'tower', 'bug': 'forest', 'rock': 'cave', 'ghost': 'tower', 'dragon': 'sky', 'dark': 'cave', 'steel': 'mountain', 'fairy': 'sky',
  };

  /// Na Dusk Ball (3×): as rotas escuras.
  static const darkBiomes = ['cave', 'tower'];

  /// Os chefes de cidade (líder no ginásio dele; Elite Four e Campeão na Liga). Rival e vilões aparecem na rota.
  static const _cityKinds = ['gym', 'elite', 'champion'];

  /// Andares de rota antes de cada cidade; onde a rota se divide (só ali dá para escolher); chance do rival em cada andar.
  static const routeLength = 9, forks = [1, 4, 7], ambushChance = 0.3;

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

  /// Onde está na rota: 0 é o primeiro andar depois da última cidade (run.leg); routeLength é a cidade.
  static int routePos(Json run) {
    final floor = _int(run['floor']);
    return floor - ((run['leg'] as num?)?.toInt() ?? floor - (floor - 1) % 10);
  }

  /// Chegou na cidade (ou na Liga): o chefe dela é o próximo andar.
  static bool atCity(FactoryData data, Json run) =>
      _cityKinds.contains(bossOf(data, run)['kind']) && (_inLeague(data, run) || routePos(run) >= routeLength);

  /// O bioma da rota até a próxima cidade: o do tipo do ginásio; para a Liga, um fixo da região. Igual ao site.
  static String routeBiome(FactoryData data, Json run) {
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
      final top = order.isEmpty ? null : _typeBiome[keys[order.first]];
      if (top != null) return top;
    }
    return biomeIds[(_int(run['boss']['region']) * 7 + _int(boss['step']) * 3) % biomeIds.length];
  }

  /// Os pontos do mapa (o peso de cada um nas bifurcações). O Centro Pokémon é raro.
  static const nodeWeights = [('wild', 34), ('trainer', 28), ('ace', 12), ('mart', 10), ('event', 11), ('center', 5)];
  static const _battleNodes = ['wild', 'trainer', 'ace', 'boss', 'wildboss'];
  static bool isBattleNode(Map? node) => _battleNodes.contains(node?['kind']);

  /// O que tem no andar: o chefe da cidade (na Liga, um atrás do outro), o rival e os vilões em qualquer andar da
  /// rota, o caminho que segue (um ponto só) ou, nas bifurcações, 2 ou 3 caminhos. Igual ao site.
  static Json routeOptions(Json run, FactoryData data, double Function() rand) {
    final floor = _int(run['floor']);
    final biome = routeBiome(data, run);
    final pos = routePos(run);
    final boss = bossOf(data, run);
    Json only(Json node) => {'floor': floor, 'biome': biome, 'options': [node]};
    if (atCity(data, run)) return only({'kind': 'boss'});
    if (!_cityKinds.contains(boss['kind'])) {
      // Rival e vilões: quantos ainda faltam antes da cidade e quantos andares de rota sobram.
      final leaders = _leaders(data, run);
      final step = _int(run['boss']['step']);
      var pending = 0;
      while (step + pending < leaders.length && !_cityKinds.contains(leaders[step + pending]['kind'])) {
        pending++;
      }
      if (routeLength - pos <= pending || (pos >= 2 && rand() < ambushChance)) return only({'kind': 'boss'});
    }
    String wildBiome() => rand() < 0.7 ? biome : _pick(biomeIds, rand);
    if (!forks.contains(pos)) {
      final r = rand();
      return only(r < 0.55 ? {'kind': 'wild', 'biome': wildBiome()} : r < 0.9 || floor <= 2 ? {'kind': 'trainer'} : {'kind': 'event'});
    }
    final options = <Json>[rand() < 0.55 ? {'kind': 'wild', 'biome': wildBiome()} : {'kind': 'trainer'}];
    final count = floor <= 2 ? 2 : 3;
    final allowed = [for (final w in nodeWeights) if (floor > 2 || w.$1 == 'wild' || w.$1 == 'trainer') w];
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
      final node = kind == 'wild' ? {'kind': kind, 'biome': wildBiome()} : {'kind': kind};
      if (options.any((o) => o['kind'] == node['kind'] && o['biome'] == node['biome'])) continue;
      options.add(node);
    }
    if (pos == forks[1] && rand() < wildBossChance) options[options.length - 1] = {'kind': 'wildboss'};
    return {'floor': floor, 'biome': biome, 'options': options};
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
    return (from: k >= 0 ? leaders[k]['city'] as String? : null, to: to);
  }

  /// O que o treinador forte deixa (sempre): bolas e remédios na Bolsa, os de segurar guardados.
  static final aceRewards = ['great-ball', 'ultra-ball', 'hyper-potion', 'max-potion', 'revive', 'move-tutor', ...heldBoost.keys];

  /// Os eventos do mapa.
  static const events = ['items', 'money', 'berries', 'tutor'];

  /// Escolhe o caminho: batalha (o encontro do andar) ou, sem batalha, Poké Mart, Centro Pokémon e eventos. Igual ao site.
  static Json chooseNode(Json run, FactoryData data, int index) {
    final options = (run['route']?['options'] as List?) ?? const [];
    if (index < 0 || index >= options.length || run['encounter'] != null || run['pending'] != null) return run;
    final node = Map<String, dynamic>.from(options[index] as Map);
    final out = _copy(run)..['route'] = null;
    final rand = _dice(out);
    final floor = _int(out['floor']);
    if (isBattleNode(node)) {
      out['encounter'] = encounterFor(data, floor, rand, node['kind'] == 'boss' ? bossOf(data, out) : null, node['kind'] == 'wildboss', node);
      return out;
    }
    out['floor'] = floor + 1;
    if (node['kind'] == 'mart') {
      out['pending'] = {'mart': true, 'shop': _pickShop(rand, data, 10)};
    } else if (node['kind'] == 'center') {
      out['team'] = [for (final m in teamOf(out)) {...m, 'hp': 1}];
      out['pending'] = {'center': true};
    } else {
      final kind = _pick(events, rand);
      final event = <String, dynamic>{'kind': kind};
      if (kind == 'items') {
        final item = _pick(const ['potion', 'super-potion', 'poke-ball', 'great-ball', 'revive'], rand);
        event['item'] = item;
        event['count'] = item == 'revive' ? 1 : 2;
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
    Json foe(int id, int lvl, [Json extra = const {}]) => {'id': id, 'level': math.max(2, lvl), 'iv': iv, 'ev': ev, if (boost != 0) 'boost': boost, ...extra};
    if (wild) {
      // Chefe sem treinador: dá para capturar; a Mega deixa a Mega Pedra.
      final r = rand();
      final strong = {'iv': math.max(31, iv), 'ev': (ev * 1.25).round()};
      int id;
      Json extra;
      if (r < 0.4) {
        final species = data.megas.keys.toList()..sort();
        id = _pick(species, rand);
        final stone = _pick(data.megas[id]!, rand)[0] as String;
        extra = {'item': stone, 'gimmick': 'mega', 'title': 'mega'};
      } else if (r < 0.7) {
        id = _pick(data.gmax, rand);
        extra = {'gimmick': 'dmax', 'title': 'gmax'};
      } else {
        final legends = [for (final e in data.species.entries) if (_int(e.value[2]) == 1 || _int(e.value[2]) == 2) e.key];
        id = _pick(legends, rand);
        extra = {'title': 'legend'};
      }
      final lvl = _bossLevel(data, floor, id, level + 3);
      return {'kind': 'wildboss', 'foes': [foe(id, lvl, {...strong, ...extra, if (rand() < shinyChance) 'shiny': true})]};
    }
    if (boss != null) {
      // Os times dos chefes são de Pokémon evoluídos: quem é mais forte que as espécies do andar vem com nível menor.
      // Antes do andar 10, sem o bônus de nível (o rival aparece cedo, como no começo dos jogos).
      final bonus = floor < 10 ? 0 : const {'gym': 2, 'rival': 2, 'villain': 3, 'elite': 4, 'champion': 5}[boss['kind']] ?? 2;
      final team = bossTeam(boss, floor);
      int levelOf(int id, int i) => _bossLevel(data, floor, id, level + bonus + (i == team.length - 1 ? 1 : 0));

      final foes = [for (var i = 0; i < team.length; i++) foe(team[i], levelOf(team[i], i), {'iv': math.max(31, iv), 'ev': (ev * 1.25).round()})];
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
    if (kind == 'trainer' || kind == 'ace') {
      // O treinador forte: um Pokémon a mais, 2 níveis acima, mais EVs; sempre deixa um item.
      final ace = kind == 'ace';
      final count = math.min(maxTeam, 1 + floor ~/ 12 + (rand() < 0.3 ? 1 : 0) + (ace ? 1 : 0));
      final Json extra = ace ? {'iv': math.max(iv, 20), 'ev': (ev * 1.15).round()} : const {};
      final foes = <Json>[];
      for (var i = 0; i < count; i++) {
        final id = pick(common);
        foes.add(foe(id, level + (ace ? 2 : 0) - (rand() * 3).floor(), extra));
      }
      return {'kind': kind, 'foes': foes, 'trainerSeed': (rand() * 1e9).floor(), if (ace) 'reward': _pick(aceRewards, rand)};
    }
    // Selvagem: os do bioma da rota (se não tiver nenhum do tamanho certo, qualquer um).
    final types = biomes[node?['biome']];
    final local = types == null ? common : [for (final p in common) if (((data.species[p.id]?.elementAtOrNull(4) as List?) ?? const []).any(types.contains)) p];
    final id = pick(local.isNotEmpty ? local : common);
    return {
      'kind': kind, 'foes': [foe(id, level, rand() < shinyChance ? {'shiny': true} : const {})],
      if (node?['biome'] != null) 'biome': node!['biome'],
    };
  }

  static Json? startRun(Json factory, FactoryData data, int id, int seed, [bool shiny = false]) {
    if (!startersOf(factory, data).contains(id) || (shiny && !shiniesOf(factory).contains(id))) return null;
    final run = <String, dynamic>{
      'seed': seed & 0xFFFFFFFF, 'floor': 1, 'money': 0, 'defeated': 0, 'bosses': 0, 'bag': {...startBag},
      'team': <Json>[], 'teamBoost': _zero(), 'mult': {'money': 1, 'exp': 1, 'shop': 1}, 'cards': <String>[], 'boss': {'region': 0, 'step': 0}, 'played': <String>[],
      'tms': <String, dynamic>{}, 'tokens': {'move-tutor': 0, 'move-reminder': 0}, 'stash': <String>[], 'dmax': false, 'tera': false,
      'leg': 1, 'route': null, 'encounter': null, 'pending': null,
    };
    final rand = _dice(run);
    // O inicial vem com IVs bons (15 a 31).
    run['team'] = [newMon(id, startLevel, rand, 15, shiny)];
    run['boss'] = {'region': (rand() * data.bosses.length).floor(), 'step': 0};
    run['played'] = [data.bosses[_int(run['boss']['region'])]['region']];
    run['route'] = routeOptions(run, data, rand);
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
  static Json winFloor(Json run, FactoryData data, {List<double>? hp, Map<String, int>? bag, bool captured = false}) {
    final out = _copy(run);
    final team0 = teamOf(out);
    out['team'] = [for (var i = 0; i < team0.length; i++) {...team0[i], 'hp': hp != null && i < hp.length ? hp[i] : hpOf(team0[i])}];
    out['bag'] = {...(bag ?? Map<String, dynamic>.from(run['bag'] as Map))};
    final rand = _dice(out);
    final kind = run['encounter']['kind'] as String;
    final foes = foesOf(run);
    final factor = kind == 'ace' ? 1.75 : kind == 'boss' || kind == 'wildboss' || kind == 'trainer' ? 1.5 : 1.0;
    final moneyFactor = kind == 'boss' || kind == 'wildboss' ? 3 : kind == 'ace' ? 2.5 : kind == 'trainer' ? 2 : 1;
    var money = 0;
    final evs = _zero();
    for (final f in foes) {
      money += ((_int(f['level']) * 6 + 10) * moneyFactor * _mult(out, 'money') * earlyMoney(_int(run['floor']))).floor();
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
    out['floor'] = _int(out['floor']) + 1;
    String? drop, story;
    if (kind == 'boss' || kind == 'wildboss') out['bosses'] = ((out['bosses'] as num?) ?? 0).toInt() + 1;
    if (kind == 'boss') {
      final beaten = run['encounter']['boss'] as Map;
      // Venceu o chefe da cidade (ou da Liga): começa a rota seguinte.
      if (_cityKinds.contains(beaten['kind'])) out['leg'] = out['floor'];
      final (boss, played) = _nextBoss(out, data, rand);
      // Acabou a história da região: o fim dela e o começo da próxima.
      if (boss['step'] == 0) {
        story = '${storyLine(data, '${beaten['region']}', 'end')}\n\n${storyLine(data, '${data.bosses[_int(boss['region'])]['region']}', 'intro')}';
      }
      out['boss'] = boss;
      out['played'] = played;
      // O chefe deixa o Cristal Z do tipo do Pokémon mais forte dele.
      final ace = foes.last;
      final types = data.speciesOf(_int(ace['id']))?.elementAtOrNull(4) as List?;
      final crystal = types == null || types.isEmpty ? null : data.zcrystals['${types.first}'];
      if (crystal != null && !_hasItem(out, crystal)) drop = crystal;
    }
    // A Mega deixa a Mega Pedra (derrotando ou capturando).
    if (kind == 'wildboss' && foes.first['item'] != null && !_hasItem(out, '${foes.first['item']}')) drop = '${foes.first['item']}';
    if (drop != null) out['stash'] = [...((out['stash'] as List?) ?? const []), drop];
    // O treinador forte deixa um item: bolas e remédios na Bolsa, ficha de Move Tutor, os de segurar guardados.
    final reward = kind == 'ace' ? run['encounter']['reward'] as String? : null;
    if (reward != null && bagItems.contains(reward)) {
      (out['bag'] as Map)[reward] = (((out['bag'] as Map)[reward] as num?) ?? 0).toInt() + 1;
    } else if (reward != null && tokens.contains(reward)) {
      final t = Map<String, dynamic>.from((out['tokens'] as Map?) ?? const {});
      t[reward] = ((t[reward] as num?) ?? 0).toInt() + 1;
      out['tokens'] = t;
    } else if (reward != null) {
      out['stash'] = [...((out['stash'] as List?) ?? const []), reward];
    }
    final joy = rand() < joyChance;
    if (joy) out['team'] = [for (final m in teamOf(out)) {...m, 'hp': 1}];
    final cardsPick = kind == 'boss' ? _pickCards(rand) : null;
    // A loja da cidade: chegando nela, logo antes do chefe (no resto da rota, os Poké Marts do mapa).
    final cityWin = kind == 'boss' && _cityKinds.contains(run['encounter']['boss']['kind']);
    final shopPick = !cityWin && atCity(data, out) && !_inLeague(data, out) ? _pickShop(rand, data) : null;
    out['pending'] = {
      'exp': exp, 'money': money, 'levels': levels, 'joy': joy, 'drop': drop, 'story': story, 'reward': reward,
      'capture': captured && (kind == 'wild' || kind == 'wildboss') ? foes.first : null,
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

  /// Alguém do time (ou guardado) já tem esse item.
  static bool _hasItem(Json run, String id) =>
      ((run['stash'] as List?) ?? const []).contains(id) || teamOf(run).any((m) => m['item'] == id || ((m['extras'] as List?) ?? const []).contains(id));

  static List<String> _pickShop(double Function() rand, FactoryData data, [int size = 8]) {
    final ids = [for (final id in shop.keys) if (!ballIds.contains(id)) id];
    // Sempre Poké Ball, uma bola melhor e um remédio; a Master Ball é rara.
    final out = ['poke-ball', _pick(ballIds.sublist(1, ballIds.length - 1), rand), _pick(const ['potion', 'super-potion', 'hyper-potion', 'max-potion', 'revive'], rand)];
    if (rand() < 0.03) out.add('master-ball');
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

  /// Solta o capturado (o time está cheio e você não quer trocar ninguém).
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
  static bool shopOwned(Json run, String id) => (id == 'dynamax-band' && run['dmax'] == true) || (id == 'tera-orb' && run['tera'] == true);

  /// Compra um item da loja (index: o Pokémon que recebe; itens da Bolsa e Poké Ball não precisam). null se não dá.
  static Json? buyItem(Json run, String id, int index, FactoryData data) {
    if (!shop.containsKey(id) && !id.startsWith('tm:') && !id.startsWith('evo:')) return null;
    final price = shopPrice(run, id);
    if (!((pendingOf(run)?['shop'] as List?)?.contains(id) ?? false) || (run['money'] as num) < price || shopOwned(run, id)) return null;
    final out = _copy(run);
    out['money'] = _int(out['money']) - price;
    if (id == 'dynamax-band') return out..['dmax'] = true;
    if (id == 'tera-orb') return out..['tera'] = true;
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
    out['route'] = routeOptions(out, data, _dice(out));
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
      }
    );
  }
}
