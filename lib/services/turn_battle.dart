// Production battles use the shared offline Pokémon Showdown simulator.
// The callback-based path is retained for legacy test fixtures without simulator sets.
import 'dart:math';

import 'damage_calc.dart';
import 'local_database.dart';
import 'team_battle.dart';
import 'battle_simulator.dart';

class BattleMove {
  final String slug, name, type, category;
  final int power, maxPp, priority;
  final int? accuracy;

  /// Regras do Pokémon Showdown (move_rules.json): efeitos, recuo, dreno, status...
  final Map<String, dynamic>? rules;
  int pp;
  bool disabled = false;
  BattleMove(this.slug, this.name, this.type, this.power, this.accuracy, this.pp, this.maxPp, this.priority,
      {this.category = 'physical', this.rules});
  BattleMove copy() => BattleMove(slug, name, type, power, accuracy, maxPp, maxPp, priority, category: category, rules: rules);
}

/// Atributos que mudam na batalha e o nome deles nas falas (em português; a tela traduz).
const battleStats = ['atk', 'def', 'spa', 'spd', 'spe'];
const statNames = {'atk': 'Ataque', 'def': 'Defesa', 'spa': 'Ataque Especial', 'spd': 'Defesa Especial', 'spe': 'Velocidade'};

/// A forma Mega de um Pokémon (atributos, tipos e calculadora dela).
class BattleMega {
  final int id;
  final String name;
  final List<String> types;
  final int spe;
  final CalcPokemon? calc;
  final String ability;
  const BattleMega(this.id, this.name, this.types, this.spe, {this.calc, this.ability = ''});
}

class BattleMon {
  final String name;
  final int level;
  final List<BattleMove> moves;
  final bool shiny;
  final List<BattleMove> _initialMoves;
  Map<String, dynamic>? _simSet;
  String? simulationSpecies;
  String? simulationAbility;
  String? simulationItem;
  int? effectiveSpe;

  /// Id, tipos, velocidade, vida máxima e calculadora: mudam na Mega,
  /// Terastal e Dinamax (e voltam ao original na próxima batalha).
  int id, maxHp, spe;
  List<String> types;

  /// Pokémon da calculadora (com Nature, EVs, IVs, item e habilidade).
  CalcPokemon? calc;

  /// Habilidade (as de clima e de velocidade no clima valem no motor).
  String ability;

  /// Mecânicas: forma Mega, id da forma Gigantamax, Tera Type e a que usa
  /// na batalha (escolhida no montador: '' | mega | z | dmax | tera).
  BattleMega? mega;
  final int? gmax;
  final String teraType, gimmick;

  /// Tipo do Cristal Z que segura ('' = nenhum) e se não pode dinamaxizar
  /// (Zacian, Zamazenta, Eternatus).
  final String zType;
  final bool noDmax;
  int hp;
  bool faintShown = false;
  bool trapped = false;

  /// Status ('', brn, par, psn, tox, slp, frz), turnos de sono, contador do
  /// veneno grave, estágios de atributo (−6 a +6) e se recuou neste turno.
  String status = '';
  int sleep = 0, toxic = 0;
  bool flinch = false;
  Map<String, int> boosts = {for (final s in battleStats) s: 0};

  /// Terastalizado e turnos de Dinamax que faltam.
  bool terastal = false;
  int dmax = 0;

  final ({int id, List<String> types, int spe, int maxHp, CalcPokemon? calc, BattleMega? mega, String ability}) _orig;
  BattleMon(this.id, this.name, this.level, this.maxHp, this.spe, this.types, this.moves,
      {this.calc,
      this.shiny = false,
      this.mega,
      this.gmax,
      String? teraType,
      this.gimmick = '',
      this.zType = '',
      this.noDmax = false,
      this.ability = ''})
      : hp = maxHp,
        _initialMoves = [for (final move in moves) move.copy()],
        teraType = teraType ?? (types.isEmpty ? '' : types.first),
        _orig = (id: id, types: types, spe: spe, maxHp: maxHp, calc: calc, mega: mega, ability: ability);

  /// Volta ao original (antes da Mega, Terastal e Dinamax).
  void restore() {
    id = _orig.id;
    types = _orig.types;
    spe = _orig.spe;
    maxHp = _orig.maxHp;
    calc = _orig.calc;
    mega = _orig.mega;
    ability = _orig.ability;
    hp = min(hp, maxHp);
  }

  /// Com HP e PP cheios (para "batalhar de novo").
  BattleMon fresh() => BattleMon(_orig.id, name, level, _orig.maxHp, _orig.spe, _orig.types, [for (final m in _initialMoves) m.copy()],
      calc: _orig.calc,
      shiny: shiny,
      mega: _orig.mega,
      gmax: gmax,
      teraType: teraType,
      gimmick: gimmick,
      zType: zType,
      noDmax: noDmax,
      ability: _orig.ability).._simSet = _simSet..simulationSpecies = simulationSpecies..simulationAbility = simulationAbility..simulationItem = simulationItem;
}

/// Resultado de um golpe: os danos possíveis de cada acerto e a eficácia (0 = não afeta).
typedef HitResult = ({List<List<int>> rolls, double eff});
/// [power]: poder do Z-Move / Max Move (o golpe vira um acerto só).
/// [weather]: o clima da batalha (rain | sun | sand | hail | snow; '' = nenhum).
typedef BattleHit = HitResult? Function(BattleMon att, BattleMon def, String slug, bool crit, [int? power, String weather]);

/// Evento para a tela ir mostrando: texto, HP, troca, desmaio, a animação
/// do golpe (attack, com o tipo, a categoria e o golpe) / do erro (miss), o
/// item usado num Pokémon do time (heal: [index] e o HP em [value]) ou o
/// status novo (status: em [type]; '' = curou).
class BattleEvent {
  final String t; // text | hp | switch | faint | attack | miss | heal | status | mega | tera | dmax | weather
  final String key;
  final List<Object> args;
  final int side, value, index;
  final String type, category, slug;
  BattleEvent.viewFor(BattleEvent event, int viewer)
      : t = event.t, key = event.key,
        side = event.side < 0 ? event.side : event.side == viewer ? 0 : 1,
        value = event.value, index = event.index, type = event.type, category = event.category, slug = event.slug,
        args = [for (final v in event.args) v is (int, String) ? (v.$1 == viewer ? 0 : 1, v.$2) : v];
  const BattleEvent.text(this.key, this.args)
      : t = 'text',
        side = -1,
        value = 0,
        index = 0,
        type = '',
        category = '',
        slug = '';
  const BattleEvent.attack(this.side, this.type, this.category, this.slug)
      : t = 'attack',
        key = '',
        args = const [],
        value = 0,
        index = 0;
  const BattleEvent.miss(this.side)
      : t = 'miss',
        key = '',
        args = const [],
        value = 0,
        index = 0,
        type = '',
        category = '',
        slug = '';
  const BattleEvent.hp(this.side, this.value)
      : t = 'hp',
        key = '',
        args = const [],
        index = 0,
        type = '',
        category = '',
        slug = '';
  const BattleEvent.switched(this.side, this.value)
      : t = 'switch',
        key = '',
        args = const [],
        index = 0,
        type = '',
        category = '',
        slug = '';
  const BattleEvent.faint(this.side)
      : t = 'faint',
        key = '',
        args = const [],
        value = 0,
        index = 0,
        type = '',
        category = '',
        slug = '';
  const BattleEvent.status(this.side, this.type)
      : t = 'status',
        key = '',
        args = const [],
        value = 0,
        index = 0,
        category = '',
        slug = '';
  /// Megaevoluiu: a forma nova em [value].
  const BattleEvent.mega(this.side, this.value)
      : t = 'mega',
        key = '',
        args = const [],
        index = 0,
        type = '',
        category = '',
        slug = '';

  /// Terastalizou no tipo [type].
  const BattleEvent.tera(this.side, this.type)
      : t = 'tera',
        key = '',
        args = const [],
        value = 0,
        index = 0,
        category = '',
        slug = '';

  /// Dinamax: começou ([index] 1) ou acabou (0); a forma (Gigantamax) em [value].
  const BattleEvent.dmax(this.side, this.index, this.value)
      : t = 'dmax',
        key = '',
        args = const [],
        type = '',
        category = '',
        slug = '';
  /// Clima novo em [type] (rain | sun | sand | hail | snow; '' = acabou).
  const BattleEvent.weather(this.type)
      : t = 'weather',
        key = '',
        args = const [],
        side = -1,
        value = 0,
        index = 0,
        category = '',
        slug = '';
  const BattleEvent.heal(this.side, this.index, this.value)
      : t = 'heal',
        key = '',
        args = const [],
        type = '',
        category = '',
        slug = '';
}

final struggle = BattleMove('struggle', 'Struggle', 'normal', 50, null, 1, 1, 0, category: 'physical');

/// Chance de crítico por estágio (geração 7 em diante).
const _critChance = [1 / 24, 1 / 8, 1 / 2, 1.0];

/// Tipos imunes a cada status.
const _statusImmune = {
  'brn': ['fire'],
  'par': ['electric'],
  'psn': ['poison', 'steel'],
  'tox': ['poison', 'steel'],
  'frz': ['ice'],
  'slp': <String>[],
};

/// Multiplicador de um estágio de atributo (−6 a +6).
double _stageMult(int s) => s >= 0 ? (2 + s) / 2 : 2 / (2 - s);

/// Velocidade na hora da ordem: estágio, paralisia (metade) e as habilidades do clima (dobro).
int speedOf(BattleMon mon, [String weather = '']) {
  if (mon.effectiveSpe != null) return mon.effectiveSpe!;
  var spe = (mon.spe * _stageMult(mon.boosts['spe'] ?? 0)).floor();
  if (weather.isNotEmpty && (_speedAbilities[mon.ability]?.contains(weather) ?? false)) spe *= 2;
  return mon.status == 'par' ? spe ~/ 2 : spe;
}

/// Climas: rain | sun | sand | hail | snow. Golpes de status que mudam o clima.
const weatherMoves = {'rain-dance': 'rain', 'sunny-day': 'sun', 'sandstorm': 'sand', 'hail': 'hail', 'snowscape': 'snow'};

/// Max Moves que mudam o clima (pelo tipo).
const _maxWeather = {'water': 'rain', 'fire': 'sun', 'rock': 'sand', 'ice': 'hail'};

/// Habilidades que mudam o clima quando o Pokémon entra (ou megaevolui).
const _weatherAbilities = {'Drizzle': 'rain', 'Drought': 'sun', 'Orichalcum Pulse': 'sun', 'Sand Stream': 'sand', 'Snow Warning': 'snow'};

/// Habilidades que dobram a velocidade no clima.
const _speedAbilities = {
  'Swift Swim': ['rain'],
  'Chlorophyll': ['sun'],
  'Sand Rush': ['sand'],
  'Slush Rush': ['hail', 'snow'],
};

/// Nome do clima na calculadora do Showdown.
const calcWeather = {'rain': 'Rain', 'sun': 'Sun', 'sand': 'Sand', 'hail': 'Hail', 'snow': 'Snow'};

/// Quem não sofre com a areia e o granizo.
const _weatherImmune = {
  'sand': ['rock', 'ground', 'steel'],
  'hail': ['ice'],
};

/// Um item da Bolsa: cura [heal] de HP ou revive com metade da vida.
class BattleItem {
  final String slug, name;
  final int heal, count;
  final bool revive;
  const BattleItem(this.slug, this.name, {this.heal = 0, this.revive = false, required this.count});
}

/// Itens da Bolsa (os mesmos dos dois lados) e quantos cada um começa. Igual ao site.
const battleItems = [
  BattleItem('potion', 'Potion', heal: 20, count: 3),
  BattleItem('super-potion', 'Super Potion', heal: 60, count: 2),
  BattleItem('hyper-potion', 'Hyper Potion', heal: 120, count: 1),
  BattleItem('revive', 'Revive', revive: true, count: 1),
];
BattleItem? _itemOf(String slug) => battleItems.where((i) => i.slug == slug).firstOrNull;

class TurnBattle {
  TurnBattle(List<BattleMon> mine, List<BattleMon> theirs, this.random) : teams = [mine, theirs] {
    for (final mon in [...mine, ...theirs]) {
      mon
        ..restore()
        ..terastal = false
        ..dmax = 0
        ..status = ''
        ..sleep = 0
        ..toxic = 0
        ..flinch = false
        ..boosts = {for (final s in battleStats) s: 0};
    }
    if (BattleSimulator.ready && [...mine, ...theirs].every((mon) => mon.calc != null)) {
      final created = BattleSimulator.call('create', [{
        'teams': [for (final team in teams) [for (final mon in team) _simMon(mon)]],
        'seed': List.generate(4, (_) => (random() * 65536).floor()),
      }]);
      _simHandle = created['handle'] as int;
      _opening = _simSync(created);
    }
  }

  int? _simHandle;
  Map<String, dynamic>? _simState;
  List<BattleEvent> _opening = [];
  BattleHit? _lastHit;
  final List<bool> forceSwitch = [false, false];
  bool canSwitch(int side, int index) => _simState != null
      ? (_simState!['sides'][side]['switchOptions'] as List).contains(index)
      : index != activeIndex[side] && teams[side][index].hp > 0;
  void dispose() {
    if (_simHandle != null) BattleSimulator.release(_simHandle!);
    _simHandle = null;
  }

  static Map<String, dynamic> _simMon(BattleMon mon) {
    final p = mon.calc!;
    return {
      'id': mon.id, 'name': mon.name, 'mega': mon.mega == null ? null : {'id': mon.mega!.id},
      'gmax': mon.gmax, 'teraType': mon.teraType, 'gimmick': mon.gimmick, 'noDmax': mon.noDmax,
      'set': mon._simSet ??= {'species': mon.simulationSpecies ?? p.name, 'moves': [for (final m in mon._initialMoves) m.slug], 'level': p.level,
        'ability': mon.simulationAbility ?? p.ability, 'item': mon.simulationItem ?? p.item, 'nature': p.nature, 'gender': p.gender,
        'ivs': p.ivs, 'evs': p.evs, 'shiny': mon.shiny},
    };
  }

  List<BattleEvent> _simSync(Map<String, dynamic> result) {
    final state = Map<String, dynamic>.from(result['state'] as Map);
    _simState = state;
    turn = state['turn'] as int;
    winner = state['winner'] as int?;
    weather = const {'raindance': 'rain', 'sunnyday': 'sun', 'sandstorm': 'sand', 'hail': 'hail', 'snow': 'snow'}[state['weather']] ?? '';
    for (var side = 0; side < 2; side++) {
      final s = state['sides'][side] as Map;
      activeIndex[side] = s['active'] as int;
      forceSwitch[side] = s['forceSwitch'] == true;
      bags[side] = Map<String, int>.from(state['bags'][side] as Map);
      usedGimmicks[side] = {for (final e in (s['used'] as Map).entries) if (e.value == true) e.key as String};
      for (final dynamic raw in s['team'] as List) {
        final p = raw as Map;
        final mon = teams[side][p['index'] as int];
        if ('${p['species']}'.toLowerCase().contains('-mega') && mon.mega != null) {
          mon.id = mon.mega!.id;
          mon.calc = mon.mega!.calc;
        } else mon.id = mon._orig.id;
        mon.hp = p['hp'] as int;
        mon.maxHp = p['maxHp'] as int;
        mon.spe = p['spe'] as int;
        mon.effectiveSpe = p['actionSpeed'] as int?;
        mon.types = [for (final type in p['types'] as List) '$type'.toLowerCase()];
        mon.status = p['status'] as String;
        mon.boosts = Map<String, int>.from(p['boosts'] as Map);
        mon.ability = p['ability'] as String;
        mon.terastal = '${p['tera']}'.isNotEmpty;
        mon.dmax = p['dmax'] as int;
        mon.trapped = p['index'] == s['active'] && s['trapped'] == true;
        if (mon.calc != null) {
          mon.calc!.item = p['item'] as String;
          mon.calc!.ability = mon.ability;
        }
        final req = p['index'] == s['active'] ? ((s['request'] as Map?)?['moves'] as List?) : null;
        final slots = req ?? p['moves'] as List;
        mon.moves.clear();
        for (final dynamic rawSlot in slots) {
          final slot = rawSlot as Map;
          final data = BattleSimulator.call('move', [slot['id'] ?? slot['slug']]);
          final original = (p['moves'] as List).cast<Map>().where((m) => m['slug'] == (slot['id'] ?? slot['slug'])).firstOrNull;
          final move = BattleMove(data['slug'] as String, data['name'] as String, data['type'] as String,
            data['power'] as int, data['accuracy'] as int?, (slot['pp'] as int?) ?? 1,
            (slot['maxpp'] ?? slot['maxPp'] ?? original?['maxPp'] ?? 1) as int, data['priority'] as int,
            category: data['category'] as String)..disabled = slot['disabled'] == true;
          mon.moves.add(move);
        }
      }
    }
    needSwitch = winner == null && forceSwitch[0];
    return [for (final dynamic raw in result['events'] as List) _simEvent(Map<String, dynamic>.from(raw as Map))];
  }

  static BattleEvent _simEvent(Map<String, dynamic> e) {
    final side = (e['side'] as int?) ?? 0;
    switch (e['t']) {
      case 'hp': return BattleEvent.hp(side, e['hp'] as int);
      case 'switch': return BattleEvent.switched(side, e['index'] as int);
      case 'faint': return BattleEvent.faint(side);
      case 'attack': return BattleEvent.attack(side, e['type'] as String, e['category'] as String, e['slug'] as String);
      case 'miss': return BattleEvent.miss(side);
      case 'status': return BattleEvent.status(side, e['status'] as String);
      case 'heal': return BattleEvent.heal(side, e['index'] as int, e['hp'] as int);
      case 'mega': return BattleEvent.mega(side, e['id'] as int);
      case 'tera': return BattleEvent.tera(side, e['type'] as String);
      case 'dmax': return BattleEvent.dmax(side, e['on'] == true ? 1 : 0, e['id'] as int);
      case 'weather': return BattleEvent.weather(e['weather'] as String);
      default: return BattleEvent.text(e['key'] as String, [for (final dynamic arg in e['args'] as List) arg is Map ? (side: arg['side'] as int, name: arg['name'] as String) : arg as Object]);
    }
  }

  List<BattleEvent> _simChoose(List<Map<String, dynamic>> actions) => _simSync(BattleSimulator.call('choose', [_simHandle, actions]));

  void _completeCpuSwitches(BattleHit hit, List<BattleEvent> events) {
    var attempts = 0;
    while (winner == null && forceSwitch[1] && !forceSwitch[0]) {
      if (++attempts > 12) throw StateError('Não foi possível resolver a substituição');
      events.addAll(_simChoose([{'kind': 'wait'}, {'kind': 'switch', 'index': _cpuReplacement(hit)}]));
    }
  }

  // Visão da partida sem restaurar HP, formas ou status.
  TurnBattle._view(this.teams, this.random);
  TurnBattle viewFor(int side) {
    final order = [side, 1 - side];
    final view = TurnBattle._view([for (final s in order) teams[s]], random);
    for (var i = 0; i < 2; i++) {
      view.activeIndex[i] = activeIndex[order[i]];
      view.bags[i] = bags[order[i]];
      view.gimmicks[i] = gimmicks[order[i]];
      view.usedGimmicks[i] = usedGimmicks[order[i]];
      view.forceSwitch[i] = forceSwitch[order[i]];
    }
    view.turn = turn;
    view.cpuSwitchTurn = cpuSwitchTurn;
    view.weather = weather;
    view.weatherTurns = weatherTurns;
    view.winner = winner == null ? null : winner == -1 ? -1 : winner == side ? 0 : 1;
    view.needSwitch = winner == null && (_simHandle != null ? forceSwitch[side] : active(side).hp <= 0);
    view._simState = _simState == null ? null : {..._simState!, 'sides': [for (final s in order) _simState!['sides'][s]]};
    return view;
  }

  final List<List<BattleMon>> teams;
  final List<int> activeIndex = [0, 0];
  final double Function() random;
  final List<Map<String, int>> bags = [
    for (var i = 0; i < 2; i++) {for (final item in battleItems) item.slug: item.count},
  ];
  int turn = 1;
  int cpuSwitchTurn = -2;

  /// Mecânica que cada lado já usou ('mega' | 'z' | 'dmax' | 'tera').
  final List<String?> gimmicks = [null, null];
  final List<Set<String>> usedGimmicks = [{}, {}];

  /// Clima (rain | sun | sand | hail | snow; '' = nenhum) e turnos que faltam.
  String weather = '';
  int weatherTurns = 0;

  /// Começa um clima (5 turnos). Se já estava, o golpe de [side] falha.
  void _setWeather(String w, List<BattleEvent> events, [int side = -1]) {
    if (weather == w) {
      if (side >= 0) _say(events, 'failed', [_label(side)]);
      return;
    }
    weather = w;
    weatherTurns = 5;
    events.add(BattleEvent.weather(w));
    _say(events, '${w}Start');
  }

  /// Habilidade de clima de quem acabou de entrar (ou megaevoluir).
  void _weatherAbility(int side, List<BattleEvent> events) {
    final mon = active(side);
    final w = _weatherAbilities[mon.ability];
    if (w != null && mon.hp > 0 && weather != w) _setWeather(w, events);
  }

  /// Precisão do golpe no clima (Thunder e Hurricane na chuva/sol, Blizzard no granizo/neve).
  int? _accuracyOf(BattleMove move) {
    if (move.slug == 'thunder' || move.slug == 'hurricane') {
      if (weather == 'rain') return null;
      if (weather == 'sun') return 50;
    }
    if (move.slug == 'blizzard' && (weather == 'hail' || weather == 'snow')) return null;
    return move.accuracy;
  }

  /// Cura que muda com o clima: Moonlight, Synthesis e Morning Sun (sol 2/3, outro clima 1/4), Shore Up (areia 2/3).
  List<num>? _weatherHeal(String slug) {
    if (weather.isEmpty) return null;
    if (slug == 'shore-up') return weather == 'sand' ? const [2, 3] : null;
    if (!const ['moonlight', 'synthesis', 'morning-sun'].contains(slug)) return null;
    return weather == 'sun' ? const [2, 3] : const [1, 4];
  }
  int? winner; // 0 = você ganhou, 1 = o computador
  bool needSwitch = false; // seu Pokémon desmaiou: escolha outro

  BattleMon active(int side) => teams[side][activeIndex[side]];
  int _alive(int side) => teams[side].where((p) => p.hp > 0).length;
  void _say(List<BattleEvent> events, String key, [List<Object> args = const []]) => events.add(BattleEvent.text(key, args));
  (int, String) _label(int side) => (side, active(side).name);

  /// As mecânicas especiais, na ordem dos botões.
  static const gimmickList = ['mega', 'z', 'dmax', 'tera'];

  /// Z-Move de cada tipo.
  static const zMoves = {
    'normal': 'Breakneck Blitz', 'fire': 'Inferno Overdrive', 'water': 'Hydro Vortex', 'grass': 'Bloom Doom',
    'electric': 'Gigavolt Havoc', 'ice': 'Subzero Slammer', 'fighting': 'All-Out Pummeling', 'poison': 'Acid Downpour',
    'ground': 'Tectonic Rage', 'flying': 'Supersonic Skystrike', 'psychic': 'Shattered Psyche', 'bug': 'Savage Spin-Out',
    'rock': 'Continental Crush', 'ghost': 'Never-Ending Nightmare', 'dragon': 'Devastating Drake',
    'dark': 'Black Hole Eclipse', 'steel': 'Corkscrew Crash', 'fairy': 'Twinkle Tackle',
  };

  /// Max Move de cada tipo.
  static const maxMoves = {
    'normal': 'Max Strike', 'fire': 'Max Flare', 'water': 'Max Geyser', 'grass': 'Max Overgrowth',
    'electric': 'Max Lightning', 'ice': 'Max Hailstorm', 'fighting': 'Max Knuckle', 'poison': 'Max Ooze',
    'ground': 'Max Quake', 'flying': 'Max Airstream', 'psychic': 'Max Mindstorm', 'bug': 'Max Flutterby',
    'rock': 'Max Rockfall', 'ghost': 'Max Phantasm', 'dragon': 'Max Wyrmwind', 'dark': 'Max Darkness',
    'steel': 'Max Steelspike', 'fairy': 'Max Starfall',
  };

  /// Poder do Z-Move pelo poder do golpe (tabela dos jogos).
  static int zPower(int power) {
    const table = [(55, 100), (65, 120), (75, 140), (85, 160), (95, 175), (100, 180), (110, 185), (125, 190), (130, 195)];
    for (final (top, value) in table) {
      if (power <= top) return value;
    }
    return 200;
  }

  /// Poder do Max Move (Lutador e Venenoso têm uma tabela mais fraca).
  static int maxPower(int power, String type) {
    final weak = type == 'fighting' || type == 'poison';
    final table = weak
        ? const [(40, 70), (50, 75), (60, 80), (70, 85), (100, 90), (140, 95)]
        : const [(40, 90), (50, 100), (60, 110), (70, 120), (100, 130), (140, 140)];
    for (final (top, value) in table) {
      if (power <= top) return value;
    }
    return weak ? 100 : 150;
  }

  /// Dá para usar essa mecânica agora? Regras dos jogos: uma por batalha; Mega
  /// só com a Mega Pedra ([BattleMon.mega]), Z-Move só com o Cristal Z do tipo
  /// do golpe [moveIndex] ([BattleMon.zType]), Dinamax menos quem não pode.
  bool canGimmick(int side, String gimmick, [int moveIndex = -1]) {
    if (_simState != null) {
      final req = _simState!['sides'][side]['request'] as Map?;
      if (req == null) return false;
      if (gimmick == 'mega') return req['canMegaEvo'] == true;
      if (gimmick == 'tera') return req['canTerastallize'] != null;
      if (gimmick == 'dmax') return req['canDynamax'] == true;
      final z = req['canZMove'] as List?;
      return gimmick == 'z' && z != null && moveIndex >= 0 && moveIndex < z.length && z[moveIndex] != null;
    }
    final mon = active(side);
    if (usedGimmicks[side].contains(gimmick) || mon.hp <= 0) return false;
    if (mon.gimmick.isNotEmpty && mon.gimmick != gimmick) return false;
    if (gimmick == 'mega') return mon.mega != null;
    if (gimmick == 'tera') return mon.teraType.isNotEmpty;
    if (gimmick == 'z') {
      if (moveIndex < 0 || moveIndex >= mon.moves.length) return false;
      final move = mon.moves[moveIndex];
      return move.category != 'status' && move.pp > 0 && mon.dmax == 0 && move.type == mon.zType;
    }
    return gimmick == 'dmax' && !mon.noDmax;
  }

  /// Mega, Terastal e Dinamax acontecem no começo do turno (o Z-Move, no golpe).
  void _applyGimmick(int side, String gimmick, List<BattleEvent> events) {
    final mon = active(side);
    gimmicks[side] = gimmick;
    usedGimmicks[side].add(gimmick);
    if (gimmick == 'mega') {
      final mega = mon.mega!;
      _say(events, 'megaReact', [_label(side)]);
      mon
        ..id = mega.id
        ..types = mega.types
        ..spe = mega.spe
        ..calc = mega.calc ?? mon.calc
        ..ability = mega.ability
        ..mega = null;
      events.add(BattleEvent.mega(side, mega.id));
      _say(events, 'megaEvolved', [_label(side), mega.name]);
      _weatherAbility(side, events);
    } else if (gimmick == 'tera') {
      mon
        ..terastal = true
        ..types = [mon.teraType];
      events.add(BattleEvent.tera(side, mon.teraType));
      _say(events, 'terastallized', [_label(side), mon.teraType.toUpperCase()]);
    } else if (gimmick == 'dmax') {
      mon
        ..dmax = 3
        ..maxHp = mon.maxHp * 2
        ..hp = mon.hp * 2;
      events.add(BattleEvent.dmax(side, 1, mon.gmax ?? mon.id));
      events.add(BattleEvent.hp(side, mon.hp));
      _say(events, mon.gmax != null ? 'gigantamaxed' : 'dynamaxed', [_label(side)]);
    }
  }

  /// Fim do Dinamax: volta ao tamanho e à vida de antes (proporcional).
  void _endDmax(int side, List<BattleEvent> events, [bool quiet = false]) {
    final mon = active(side);
    if (mon.dmax == 0) return;
    mon
      ..dmax = 0
      ..maxHp = mon.maxHp ~/ 2
      ..hp = mon.hp > 0 ? max(1, (mon.hp + 1) >> 1) : 0;
    if (quiet) return;
    events.add(BattleEvent.dmax(side, 0, mon.id));
    events.add(BattleEvent.hp(side, mon.hp));
    _say(events, 'dmaxEnd', [_label(side)]);
  }

  /// O computador usa a mecânica dele uma vez: a do set (no primeiro ataque,
  /// como a sua) ou, sem set (time aleatório), num turno qualquer.
  String? _cpuGimmick(int moveIndex) {
    final mon = active(1);
    if (mon.gimmick.isNotEmpty) return canGimmick(1, mon.gimmick, moveIndex) ? mon.gimmick : null;
    if (random() >= 0.35) return null;
    if (canGimmick(1, 'mega')) return 'mega';
    final options = ['tera', 'dmax'].where((g) => canGimmick(1, g)).toList();
    if (canGimmick(1, 'z', moveIndex)) options.add('z');
    return options.isEmpty ? null : options[(random() * options.length).floor()];
  }

  /// Golpes que dá para usar; sem PP em nenhum, só Struggle.
  static List<int> usableMoves(BattleMon mon) => [
        for (var i = 0; i < mon.moves.length; i++)
          if (mon.moves[i].pp > 0 && !mon.moves[i].disabled) i,
      ];

  static double _expected(BattleHit hit, BattleMon att, BattleMon def, BattleMove move, String weather) {
    if (move.category == 'status') return 0;
    final r = hit(att, def, move.slug, false, null, weather);
    if (r == null || r.eff == 0) return 0;
    var avg = 0.0;
    for (final rolls in r.rolls) {
      avg += rolls.fold<int>(0, (a, b) => a + b) / rolls.length;
    }
    return (avg < def.hp ? avg : def.hp.toDouble()) * (move.accuracy == null ? 1 : move.accuracy! / 100);
  }

  /// Efetividade de um golpe (×0 a ×4), a mesma da conta de dano; null para golpe de status.
  static double? moveEffect(BattleHit hit, BattleMon att, BattleMon def, BattleMove move) {
    if (move.category == 'status') return null;
    return hit(att, def, move.slug, false)?.eff;
  }

  /// As palavras dos jogos para a efetividade (a tela traduz).
  static String? effectLabel(double? eff) {
    if (eff == null) return null;
    if (eff == 0) return 'Não afeta';
    if (eff < 1) return 'Pouco efetivo';
    if (eff > 1) return 'Super efetivo';
    return 'Efetivo';
  }

  /// Para a troca: o melhor golpe dele contra o inimigo (attack, null se só tem
  /// golpe de status) e o quanto ele sofre com os tipos do inimigo (defense).
  /// typeEff(tipo, tipos) = multiplicador de um tipo de ataque contra os tipos.
  static ({double? attack, double defense}) switchMatchup(
      BattleHit hit, BattleMon mon, BattleMon foe, double Function(String, List<String>) typeEff) {
    final effs = [for (final m in mon.moves) moveEffect(hit, mon, foe, m)].whereType<double>();
    return (
      attack: effs.isEmpty ? null : effs.reduce(max),
      defense: foe.types.map((t) => typeEff(t, mon.types)).reduce(max),
    );
  }

  /// Tipos que causam ×2 ou mais no Pokémon, do pior para ele ao menos pior.
  static List<({String type, double mult})> weaknesses(
      List<String> types, List<String> allTypes, double Function(String, List<String>) typeEff) {
    final list = [
      for (final t in allTypes)
        if (typeEff(t, types) >= 2) (type: t, mult: typeEff(t, types)),
    ];
    // ×4 antes de ×2; empate fica na ordem dos tipos (como o site).
    return [...list.where((w) => w.mult >= 4), ...list.where((w) => w.mult < 4)];
  }

  /// Escolha do computador: maior dano previsto ou um status útil.
  int cpuMove(BattleHit hit) {
    final me = active(1), foe = active(0);
    final usable = usableMoves(me);
    if (usable.isEmpty) return -1;
    var best = usable.first;
    var bestValue = -1.0;
    for (final i in usable) {
      final move = me.moves[i];
      final value = move.category == 'status' ? _statusValue(me, foe, move) : _expected(hit, me, foe, move, weather);
      if (value > bestValue) {
        best = i;
        bestValue = value;
      }
    }
    return best;
  }

  /// Quanto vale um golpe de status para o computador (comparado com dano).
  double _statusValue(BattleMon me, BattleMon foe, BattleMove move) {
    final r = move.rules ?? const {};
    // Clima: vale se ainda não está e ajuda os golpes dele.
    final w = weatherMoves[move.slug];
    if (w != null) {
      final helps = const {'rain': 'water', 'sun': 'fire', 'sand': 'rock', 'hail': 'ice', 'snow': 'ice'}[w];
      return weather != w && me.moves.any((m) => m.type == helps && m.category != 'status') ? (foe.maxHp * 0.2).floorToDouble() : 0;
    }
    final h = r['h'] as List?;
    if (h != null) return me.hp * 2 < me.maxHp ? (me.maxHp * (h[0] as num) / (h[1] as num)).floorToDouble() : 0;
    final status = r['s'] as String?;
    if (status != null) {
      return foe.status.isEmpty && !_immuneTo(foe, status, move) ? (foe.maxHp * (status == 'slp' ? 0.5 : 0.3)).floorToDouble() : 0;
    }
    final b = r['b'] as Map?;
    if (b != null && r['t'] == 'self') {
      final room = b.entries.any((e) => (e.value as num) > 0 && (me.boosts['${e.key}'] ?? 0) < 2);
      return room && me.hp * 10 >= me.maxHp * 6 ? (me.maxHp * 0.25).floorToDouble() : 0;
    }
    if (b != null) return (foe.maxHp * 0.1).floorToDouble();
    return 0;
  }

  /// O Pokémon é imune a esse status (pelo tipo; Thunder Wave não pega em Ground)?
  static bool _immuneTo(BattleMon mon, String status, BattleMove? move) {
    if (_statusImmune[status]!.any(mon.types.contains)) return true;
    return move?.category == 'status' && move?.type == 'electric' && mon.types.contains('ground');
  }

  /// Status num Pokémon. [fromMove]: veio de um golpe de status (se não pegar, "Mas falhou!").
  void _inflict(int side, String status, BattleMove move, List<BattleEvent> events, bool fromMove) {
    final mon = active(side);
    if (mon.status.isNotEmpty || _immuneTo(mon, status, move)) {
      if (fromMove) _say(events, mon.status.isNotEmpty ? 'failed' : 'noEffect', [_label(side)]);
      return;
    }
    mon.status = status;
    if (status == 'slp') mon.sleep = 1 + (random() * 3).floor();
    if (status == 'tox') mon.toxic = 1;
    events.add(BattleEvent.status(side, status));
    const keys = {'brn': 'burned', 'par': 'paralyzed', 'psn': 'poisoned', 'tox': 'badlyPoisoned', 'slp': 'fellAsleep', 'frz': 'frozen'};
    _say(events, keys[status]!, [_label(side)]);
  }

  /// Muda os atributos (estágios de −6 a +6) e diz como ficou.
  void _boost(int side, Map boosts, List<BattleEvent> events) {
    final mon = active(side);
    for (final stat in battleStats) {
      final by = (boosts[stat] as num?)?.toInt() ?? 0;
      if (by == 0) continue;
      final before = mon.boosts[stat]!;
      final now = (before + by).clamp(-6, 6);
      if (now == before) {
        _say(events, by > 0 ? 'statMax' : 'statMin', [_label(side), stat]);
        continue;
      }
      final size = (now - before).abs() > 3 ? 3 : (now - before).abs();
      mon.boosts[stat] = now;
      _say(events, '${by > 0 ? 'statUp' : 'statDown'}${size > 1 ? size : ''}', [_label(side), stat]);
    }
  }

  /// Golpe de status: cura, causa status ou muda atributos.
  void _statusMove(int side, BattleMove move, List<BattleEvent> events) {
    final mon = active(side);
    final r = move.rules ?? const {};
    if (weatherMoves[move.slug] != null) {
      _setWeather(weatherMoves[move.slug]!, events, side);
      return;
    }
    final h = r['h'] as List?;
    if (h != null) {
      if (mon.hp >= mon.maxHp) {
        _say(events, 'failed', [_label(side)]);
      } else {
        final heal = _weatherHeal(move.slug) ?? h;
        mon.hp = (mon.hp + (mon.maxHp * (heal[0] as num) / (heal[1] as num)).floor()).clamp(0, mon.maxHp);
        events.add(BattleEvent.hp(side, mon.hp));
        _say(events, 'healedMove', [_label(side)]);
      }
    }
    if (r['s'] != null) _inflict(1 - side, r['s'] as String, move, events, true);
    if (r['b'] != null) _boost(r['t'] == 'self' ? side : 1 - side, r['b'] as Map, events);
    if (h == null && r['s'] == null && r['b'] == null) _say(events, 'failed', [_label(side)]);
  }

  /// Quem ficou sem vida desmaia ([first] primeiro: o alvo do golpe).
  void _faints(List<BattleEvent> events, [int first = 1]) {
    for (final s in [first, 1 - first]) {
      final m = active(s);
      if (m.hp <= 0 && !m.faintShown) {
        m.faintShown = true;
        _endDmax(s, events, true);
        events.add(BattleEvent.faint(s));
        _say(events, 'fainted', [_label(s)]);
      }
    }
  }

  /// Fim do turno: queimadura e veneno tiram vida; quem recuou volta ao normal.
  void _endOfTurn(List<BattleEvent> events) {
    // Clima: conta os turnos; areia e granizo machucam quem não é imune.
    if (weather.isNotEmpty) {
      final w = weather;
      weatherTurns -= 1;
      if (weatherTurns <= 0) {
        weather = '';
        events.add(const BattleEvent.weather(''));
        _say(events, '${w}End');
      } else {
        _say(events, '${w}Go');
        for (final s in [0, 1]) {
          final mon = active(s);
          final immune = _weatherImmune[w];
          if (mon.hp <= 0 || immune == null || mon.types.any(immune.contains)) continue;
          mon.hp = max(0, mon.hp - max(1, mon.maxHp ~/ 16));
          events.add(BattleEvent.hp(s, mon.hp));
          _say(events, w == 'sand' ? 'hurtSand' : 'hurtHail', [_label(s)]);
        }
        _faints(events, 0);
      }
    }
    for (final s in [0, 1]) {
      final mon = active(s);
      if (mon.hp <= 0) continue;
      var loss = 0;
      if (mon.status == 'brn') loss = max(1, mon.maxHp ~/ 16);
      if (mon.status == 'psn') loss = max(1, mon.maxHp ~/ 8);
      if (mon.status == 'tox') {
        loss = max(1, mon.maxHp * mon.toxic ~/ 16);
        mon.toxic = min(15, mon.toxic + 1);
      }
      if (loss > 0) {
        mon.hp = max(0, mon.hp - loss);
        events.add(BattleEvent.hp(s, mon.hp));
        _say(events, mon.status == 'brn' ? 'hurtBurn' : 'hurtPoison', [_label(s)]);
      }
    }
    _faints(events, 0);
    // Dinamax dura 3 turnos.
    for (final s in [0, 1]) {
      final mon = active(s);
      if (mon.dmax > 1 && mon.hp > 0) {
        mon.dmax -= 1;
      } else if (mon.dmax == 1 && mon.hp > 0) {
        _endDmax(s, events);
      }
    }
    for (final team in teams) {
      for (final mon in team) {
        mon.flinch = false;
      }
    }
  }

  int _cpuReplacement(BattleHit hit) {
    final foe = active(0);
    var best = -1;
    var bestValue = -1.0;
    for (var i = 0; i < teams[1].length; i++) {
      final mon = teams[1][i];
      if (_simState != null ? !canSwitch(1, i) : mon.hp <= 0) continue;
      var value = 0.0;
      for (final m in usableMoves(mon)) {
        final v = _expected(hit, mon, foe, mon.moves[m], weather);
        if (v > value) value = v;
      }
      if (value > bestValue) {
        best = i;
        bestValue = value;
      }
    }
    return best;
  }

  void _doMove(int side, int moveIndex, BattleHit hit, List<BattleEvent> events, [bool zMove = false]) {
    final mon = active(side);
    final foeSide = 1 - side;
    final target = active(foeSide);
    // Antes do golpe: congelado, dormindo, recuou ou paralisado.
    if (mon.status == 'frz') {
      if (random() < 0.2) {
        mon.status = '';
        events.add(BattleEvent.status(side, ''));
        _say(events, 'thawed', [_label(side)]);
      } else {
        _say(events, 'isFrozen', [_label(side)]);
        return;
      }
    }
    if (mon.status == 'slp') {
      mon.sleep -= 1;
      if (mon.sleep > 0) {
        _say(events, 'asleep', [_label(side)]);
        return;
      }
      mon.status = '';
      events.add(BattleEvent.status(side, ''));
      _say(events, 'woke', [_label(side)]);
    }
    if (mon.flinch) {
      _say(events, 'flinched', [_label(side)]);
      return;
    }
    if (mon.status == 'par' && random() < 0.25) {
      _say(events, 'fullPara', [_label(side)]);
      return;
    }
    final move = moveIndex < 0 ? struggle : mon.moves[moveIndex];
    if (moveIndex >= 0) move.pp -= 1;
    // Z-Move e Max Move: outro nome, poder da tabela, nunca erram, sem efeitos extras.
    final special = move.category != 'status' && moveIndex >= 0 && (zMove || mon.dmax > 0);
    if (zMove) _say(events, 'zPower', [_label(side)]);
    final name = !special
        ? move.name
        : zMove
            ? zMoves[move.type]!
            : maxMoves[move.type]!;
    _say(events, 'used', [_label(side), name]);
    final accuracy = _accuracyOf(move);
    if (!special && accuracy != null && random() * 100 >= accuracy) {
      events.add(BattleEvent.miss(side));
      _say(events, 'missed', [_label(side)]);
      return;
    }
    events.add(BattleEvent.attack(side, move.type, move.category, move.slug));
    if (move.category == 'status') {
      _statusMove(side, move, events);
      _faints(events, foeSide);
      return;
    }
    final rules = special ? const <String, dynamic>{} : move.rules ?? const <String, dynamic>{};
    final crit = random() < _critChance[min(3, (rules['c'] as num?)?.toInt() ?? 0)];
    final power = special ? (zMove ? zPower(move.power) : maxPower(move.power, move.type)) : null;
    final r = hit(mon, target, move.slug, crit, power, weather);
    if (r == null || r.eff == 0) {
      _say(events, 'noEffect', [_label(foeSide)]);
      return;
    }
    var damage = 0;
    for (final rolls in r.rolls) {
      damage += rolls[(random() * rolls.length).floor()];
    }
    damage = damage.clamp(0, target.hp);
    target.hp -= damage;
    events.add(BattleEvent.hp(foeSide, target.hp));
    if (r.rolls.length > 1) _say(events, 'hits', [r.rolls.length]);
    if (crit && damage > 0) _say(events, 'crit');
    if (r.eff > 1) {
      _say(events, 'super');
    } else if (r.eff < 1) {
      _say(events, 'weak');
    }
    // Recuo (Struggle: 1/4 da vida máxima) e dreno.
    final rec = rules['r'] as List?, drain = rules['d'] as List?;
    final recoil = move.slug == 'struggle'
        ? max(1, mon.maxHp ~/ 4)
        : rec != null && damage > 0
            ? max(1, (damage * (rec[0] as num) / (rec[1] as num)).floor())
            : 0;
    if (recoil > 0) {
      mon.hp = max(0, mon.hp - recoil);
      events.add(BattleEvent.hp(side, mon.hp));
      _say(events, 'recoil', [_label(side)]);
    }
    if (drain != null && damage > 0 && mon.hp > 0 && mon.hp < mon.maxHp) {
      mon.hp = min(mon.maxHp, mon.hp + max(1, (damage * (drain[0] as num) / (drain[1] as num)).floor()));
      events.add(BattleEvent.hp(side, mon.hp));
      _say(events, 'drained', [_label(foeSide)]);
    }
    // Efeitos secundários (cada um com a sua chance) e mudanças em quem usou.
    if (damage > 0) {
      for (final e in (rules['x'] as List?) ?? const []) {
        final eff = e as Map;
        if (random() * 100 >= (eff['p'] as num)) continue;
        if (eff['s'] != null && target.hp > 0) _inflict(foeSide, eff['s'] as String, move, events, false);
        if (eff['b'] != null && target.hp > 0) _boost(foeSide, eff['b'] as Map, events);
        if (eff['f'] != null && target.hp > 0 && target.dmax == 0) target.flinch = true;
        if (eff['sb'] != null && mon.hp > 0) _boost(side, eff['sb'] as Map, events);
      }
      if (rules['sb'] != null && mon.hp > 0) _boost(side, rules['sb'] as Map, events);
    }
    // Max Geyser, Max Flare, Max Rockfall e Max Hailstorm mudam o clima.
    if (special && !zMove && _maxWeather[move.type] != null) _setWeather(_maxWeather[move.type]!, events);
    _faints(events, foeSide);
  }

  /// Dá para usar o item nesse Pokémon? (poção: vivo e ferido; Revive: desmaiado).
  bool canUseItem(int side, String slug, int index) {
    final item = _itemOf(slug);
    if (item == null || index < 0 || index >= teams[side].length || (bags[side][slug] ?? 0) <= 0) return false;
    final mon = teams[side][index];
    return item.revive ? mon.hp <= 0 : mon.hp > 0 && mon.hp < mon.maxHp;
  }

  void _useItem(int side, String slug, int index, List<BattleEvent> events) {
    if (!canUseItem(side, slug, index)) return;
    final item = _itemOf(slug)!;
    final mon = teams[side][index];
    bags[side][slug] = bags[side][slug]! - 1;
    _say(events, 'usedItem', [(side, mon.name), item.name]);
    if (item.revive) {
      mon.hp = mon.maxHp ~/ 2 < 1 ? 1 : mon.maxHp ~/ 2;
      mon.faintShown = false;
      events.add(BattleEvent.heal(side, index, mon.hp));
      _say(events, 'revived', [(side, mon.name)]);
    } else {
      final missing = mon.maxHp - mon.hp;
      final healed = item.heal < missing ? item.heal : missing;
      mon.hp += healed;
      events.add(BattleEvent.heal(side, index, mon.hp));
      _say(events, 'healed', [(side, mon.name), healed]);
    }
  }

  /// O computador cura o Pokémon dele quando está com pouca vida (às vezes).
  double _bestDamage(BattleHit hit, BattleMon att, BattleMon def) {
    var best = 0.0;
    for (final i in usableMoves(att)) {
      final move = att.moves[i];
      if (move.category == 'status') continue;
      final result = hit(att, def, move.slug, false, null, weather);
      if (result == null || result.eff == 0) continue;
      var damage = 0.0;
      for (final rolls in result.rolls) {
        damage += rolls.fold<int>(0, (a, b) => a + b) / rolls.length;
      }
      best = max(best, damage * (move.accuracy == null ? 1 : move.accuracy! / 100));
    }
    return best;
  }

  double _matchupScore(BattleHit hit, BattleMon mon, BattleMon foe) =>
      _bestDamage(hit, mon, foe) / max(1, foe.hp) - _bestDamage(hit, foe, mon) / max(1, mon.hp);

  /// Decide sem olhar a ação do jogador: golpe, troca ou item.
  ({String kind, int index, String? item, int? target}) cpuPlan(BattleHit hit) {
    final me = active(1), foe = active(0), index = cpuMove(hit);
    final outgoing = _bestDamage(hit, me, foe), incoming = _bestDamage(hit, foe, me);
    final canFinish = outgoing >= foe.hp && (speedOf(me, weather) >= speedOf(foe, weather) || (index >= 0 && me.moves[index].priority > 0)) && !['slp', 'frz'].contains(me.status);
    if (!canFinish && me.dmax == 0 && !me.trapped && turn - cpuSwitchTurn >= 2) {
      var best = activeIndex[1];
      final currentScore = _matchupScore(hit, me, foe);
      var score = currentScore;
      for (var i = 0; i < teams[1].length; i++) {
        final mon = teams[1][i];
        if (i == activeIndex[1] || mon.hp <= 0 || _bestDamage(hit, foe, mon) >= mon.hp) continue;
        final value = _matchupScore(hit, mon, foe);
        if (value > score) { best = i; score = value; }
      }
      if (best != activeIndex[1] && score > currentScore + 0.35 && (incoming >= me.maxHp / 3 || outgoing == 0)) {
        return (kind: 'switch', index: best, item: null, target: null);
      }
    }
    if (!canFinish) {
      final missing = me.maxHp - me.hp;
      final potions = battleItems.where((item) => item.heal > 0 && (bags[1][item.slug] ?? 0) > 0).toList();
      final potion = potions.where((item) => item.heal >= missing).firstOrNull ?? potions.lastOrNull;
      if (potion != null && missing >= min(20, me.maxHp / 4) && (me.hp <= me.maxHp / 2 || incoming >= me.hp) && me.hp + min(missing, potion.heal) > incoming) {
        return (kind: 'item', index: -1, item: potion.slug, target: activeIndex[1]);
      }
      if (incoming < me.hp && (bags[1]['revive'] ?? 0) > 0 && teams[1].any((mon) => mon.hp <= 0)) {
        var target = -1, score = double.negativeInfinity;
        for (var i = 0; i < teams[1].length; i++) {
          final mon = teams[1][i];
          if (mon.hp > 0) continue;
          final value = _bestDamage(hit, mon, foe) / max(1, foe.hp);
          if (value > score) { target = i; score = value; }
        }
        if (target >= 0) return (kind: 'item', index: -1, item: 'revive', target: target);
      }
    }
    return (kind: 'move', index: index, item: null, target: null);
  }

  void _switchTo(int side, int index, List<BattleEvent> events) {
    final before = active(side);
    if (before.hp > 0) _say(events, side == 0 ? 'comeBack' : 'foeWithdrew', [_label(side)]);
    _endDmax(side, events, true);
    // Quem sai perde as mudanças de atributo (e o veneno grave recomeça).
    before.boosts = {for (final s in battleStats) s: 0};
    before.flinch = false;
    if (before.toxic > 0) before.toxic = 1;
    activeIndex[side] = index;
    events.add(BattleEvent.switched(side, index));
    _say(events, side == 0 ? 'go' : 'foeSent', [_label(side)]);
    _weatherAbility(side, events);
  }

  void _checkEnd(BattleHit hit, List<BattleEvent> events) {
    if (_alive(1) == 0) {
      winner = 0;
      _say(events, 'win');
      return;
    }
    if (_alive(0) == 0) {
      winner = 1;
      _say(events, 'lose');
      return;
    }
    if (active(1).hp <= 0) _switchTo(1, _cpuReplacement(hit), events);
    if (active(0).hp <= 0) needSwitch = true;
  }

  /// Um turno: [move] (índice; -1 = Struggle; com [gimmick] 'mega' | 'z' |
  /// 'dmax' | 'tera'; sem: a do set do Pokémon), [switchTo] ou [item] em
  /// [target] (índice no time).
  /// Trocas e itens vêm antes dos golpes.
  List<BattleEvent> playTurn(BattleHit hit, {int? move, String? gimmick, int? switchTo, String? item, int? target}) {
    if (_simHandle != null) {
      _lastHit = hit;
      final plan = cpuPlan(hit);
      final mine = switchTo != null ? {'kind': 'switch', 'index': switchTo}
        : item != null ? {'kind': 'item', 'item': item, 'index': target ?? activeIndex[0]}
        : {'kind': 'move', 'index': move, 'gimmick': gimmick};
      final theirs = _simState!['sides'][1]['wait'] == true ? <String, dynamic>{'kind': 'wait'}
        : plan.kind == 'item' ? {'kind': 'item', 'item': plan.item, 'index': plan.target}
        : plan.kind == 'switch' ? {'kind': 'switch', 'index': plan.index}
        : {'kind': 'move', 'index': plan.index, 'gimmick': _cpuGimmick(plan.index)};
      final events = _simChoose([mine, theirs]);
      if (plan.kind == 'switch') cpuSwitchTurn = turn;
      _completeCpuSwitches(hit, events);
      return events;
    }
    final events = <BattleEvent>[];
    if (winner != null || needSwitch) return events;
    final plan = cpuPlan(hit);
    final cpu = plan.kind == 'move' ? plan.index : null;
    final cpuG = cpu != null && cpu >= 0 ? _cpuGimmick(cpu) : null;
    // A sua: a do set do Pokémon (escolhida no montador), no primeiro ataque dele.
    final wanted = gimmick ?? (active(0).gimmick.isEmpty ? null : active(0).gimmick);
    final myG = move != null && wanted != null && canGimmick(0, wanted, move) ? wanted : null;
    if (switchTo != null) _switchTo(0, switchTo, events);
    if (item != null) _useItem(0, item, target ?? activeIndex[0], events);
    if (plan.kind == 'item') _useItem(1, plan.item!, plan.target!, events);
    if (plan.kind == 'switch') { _switchTo(1, plan.index, events); cpuSwitchTurn = turn; }
    // Mega, Terastal e Dinamax antes dos golpes (a Mega já vale para a ordem).
    final zMove = [false, false];
    for (final (side, g) in [(0, myG), (1, cpuG)]) {
      if (g == 'z') {
        gimmicks[side] = 'z'; usedGimmicks[side].add('z');
        zMove[side] = true;
      } else if (g != null) {
        _applyGimmick(side, g, events);
      }
    }
    var order = <(int, int)>[];
    if (cpu != null) order.add((1, cpu));
    if (switchTo == null && item == null) order.add((0, move ?? -1));
    int priority((int, int) o) => o.$2 < 0 ? 0 : active(o.$1).moves[o.$2].priority;
    if (order.length == 2) {
      final a = order[0], b = order[1];
      final pa = priority(a), pb = priority(b);
      final sa = speedOf(active(a.$1), weather), sb = speedOf(active(b.$1), weather);
      final tie = random() < 0.5;
      final bFirst = pb > pa || (pb == pa && (sb > sa || (sb == sa && tie)));
      if (bFirst) order = [b, a];
    }
    for (final o in order) {
      if (active(o.$1).hp <= 0 || active(1 - o.$1).hp <= 0) continue;
      _doMove(o.$1, o.$2, hit, events, zMove[o.$1]);
    }
    _endOfTurn(events);
    _checkEnd(hit, events);
    turn += 1;
    return events;
  }

  /// Começo da batalha: as habilidades de clima de quem entrou (o mais rápido
  /// primeiro; o clima do mais lento fica). Devolve os eventos para mostrar.
  /// Resolve as ações dos dois jogadores, sem escolher ações pelo computador.
  List<BattleEvent> playOnlineTurn(List<Map<String, dynamic>> actions, BattleHit hit) {
    if (_simHandle != null) return _simChoose(actions);
    final events = <BattleEvent>[];
    if (winner != null) return events;
    if (actions.any((a) => a['kind'] == 'forfeit')) {
      winner = actions[0]['kind'] == 'forfeit' ? 1 : 0;
      return events;
    }
    if ([0, 1].any((s) => active(s).hp <= 0)) {
      for (final side in [0, 1]) {
        if (active(side).hp <= 0) {
          final index = (actions[side]['index'] as num?)?.toInt() ?? -1;
          if (actions[side]['kind'] != 'switch' || index < 0 || index >= teams[side].length || teams[side][index].hp <= 0) {
            throw StateError('Troca inválida');
          }
          _switchTo(side, index, events);
        }
      }
      return events;
    }
    var order = <(int, int)>[];
    final zMove = [false, false];
    for (final side in [0, 1]) {
      final action = actions[side];
      final mon = active(side);
      final index = (action['index'] as num?)?.toInt() ?? -1;
      if (action['kind'] == 'switch') {
        if (index == activeIndex[side] || index < 0 || index >= teams[side].length || teams[side][index].hp <= 0) {
          throw StateError('Troca inválida');
        }
        _switchTo(side, index, events);
      } else if (action['kind'] == 'move') {
        if (index == -1 ? mon.moves.any((m) => m.pp > 0) : index < 0 || index >= mon.moves.length || mon.moves[index].pp <= 0) {
          throw StateError('Golpe inválido');
        }
        final wanted = (action['gimmick'] as String?) ?? mon.gimmick;
        if (wanted.isNotEmpty && canGimmick(side, wanted, index)) {
          if (wanted == 'z') { gimmicks[side] = 'z'; usedGimmicks[side].add('z'); zMove[side] = true; }
          else { _applyGimmick(side, wanted, events); }
        }
        order.add((side, index));
      } else {
        throw StateError('Ação inválida');
      }
    }
    if (order.length == 2) {
      final a = order[0], b = order[1];
      final pa = a.$2 < 0 ? 0 : active(a.$1).moves[a.$2].priority;
      final pb = b.$2 < 0 ? 0 : active(b.$1).moves[b.$2].priority;
      final sa = speedOf(active(a.$1), weather), sb = speedOf(active(b.$1), weather);
      final tie = random() < 0.5;
      if (pb > pa || (pb == pa && (sb > sa || (sb == sa && tie)))) order = [b, a];
    }
    for (final o in order) {
      if (active(o.$1).hp > 0 && active(1 - o.$1).hp > 0) _doMove(o.$1, o.$2, hit, events, zMove[o.$1]);
    }
    _endOfTurn(events);
    if (_alive(1) == 0) { winner = 0; }
    else if (_alive(0) == 0) { winner = 1; }
    turn += 1;
    return events;
  }

  List<BattleEvent> start() {
    if (_simHandle != null) {
      final events = _opening;
      _opening = [];
      return events;
    }
    final events = <BattleEvent>[];
    for (final side in speedOf(active(1)) > speedOf(active(0)) ? [1, 0] : [0, 1]) {
      _weatherAbility(side, events);
    }
    return events;
  }

  /// Seu Pokémon desmaiou: manda outro (não gasta turno).
  List<BattleEvent> replace(int index) {
    if (_simHandle != null) {
      final cpu = forceSwitch[1] && _lastHit != null ? {'kind': 'switch', 'index': _cpuReplacement(_lastHit!)} : <String, dynamic>{'kind': 'wait'};
      final events = _simChoose([{'kind': 'switch', 'index': index}, cpu]);
      if (_lastHit != null) _completeCpuSwitches(_lastHit!, events);
      return events;
    }
    final events = <BattleEvent>[];
    if (!needSwitch) return events;
    needSwitch = false;
    _switchTo(0, index, events);
    return events;
  }

  /// Desistir: o computador ganha.
  List<BattleEvent> forfeit() {
    winner = 1;
    return [const BattleEvent.text('ran', [])];
  }

  /// Texto das falas (em português; a tela traduz). {0} = Pokémon, {1} = golpe.
  static const lines = <String, Object>{
    'sim': '{0}',
    'draw': 'A batalha terminou empatada!',
    'used': ['{0} usou {1}!', '{0} inimigo usou {1}!'],
    'missed': ['O ataque de {0} errou!', 'O ataque de {0} inimigo errou!'],
    'noEffect': ['Não afeta {0}...', 'Não afeta {0} inimigo...'],
    'recoil': ['{0} foi atingido pelo recuo!', '{0} inimigo foi atingido pelo recuo!'],
    'fainted': ['{0} desmaiou!', '{0} inimigo desmaiou!'],
    'comeBack': ['Volte, {0}!', ''],
    'go': ['Vai, {0}!', ''],
    'foeWithdrew': ['', 'O adversário chamou {0} de volta!'],
    'foeSent': ['', 'O adversário mandou {0}!'],
    'hits': 'Acertou {0} vezes!',
    'crit': 'Um golpe crítico!',
    'super': 'É super eficaz!',
    'weak': 'Não é muito eficaz...',
    'win': 'Você venceu a batalha!',
    'lose': 'Todos os seus Pokémon desmaiaram... Você perdeu!',
    'ran': 'Você fugiu da batalha!',
    'usedItem': ['Você usou {1} em {0}!', 'O adversário usou {1} em {0}!'],
    'healed': ['{0} recuperou {1} de HP!', '{0} inimigo recuperou {1} de HP!'],
    'revived': ['{0} voltou à batalha!', '{0} inimigo voltou à batalha!'],
    'burned': ['{0} foi queimado!', '{0} inimigo foi queimado!'],
    'paralyzed': ['{0} foi paralisado! Talvez não consiga se mover!', '{0} inimigo foi paralisado! Talvez não consiga se mover!'],
    'poisoned': ['{0} foi envenenado!', '{0} inimigo foi envenenado!'],
    'badlyPoisoned': ['{0} foi gravemente envenenado!', '{0} inimigo foi gravemente envenenado!'],
    'fellAsleep': ['{0} adormeceu!', '{0} inimigo adormeceu!'],
    'frozen': ['{0} foi congelado!', '{0} inimigo foi congelado!'],
    'hurtBurn': ['{0} foi ferido pela queimadura!', '{0} inimigo foi ferido pela queimadura!'],
    'hurtPoison': ['{0} foi ferido pelo veneno!', '{0} inimigo foi ferido pelo veneno!'],
    'asleep': ['{0} está dormindo profundamente.', '{0} inimigo está dormindo profundamente.'],
    'woke': ['{0} acordou!', '{0} inimigo acordou!'],
    'isFrozen': ['{0} está congelado!', '{0} inimigo está congelado!'],
    'thawed': ['{0} descongelou!', '{0} inimigo descongelou!'],
    'fullPara': ['{0} está paralisado! Não consegue se mover!', '{0} inimigo está paralisado! Não consegue se mover!'],
    'flinched': ['{0} recuou e não conseguiu atacar!', '{0} inimigo recuou e não conseguiu atacar!'],
    'statUp': ['{1} de {0} subiu!', '{1} de {0} inimigo subiu!'],
    'statUp2': ['{1} de {0} subiu muito!', '{1} de {0} inimigo subiu muito!'],
    'statUp3': ['{1} de {0} subiu drasticamente!', '{1} de {0} inimigo subiu drasticamente!'],
    'statDown': ['{1} de {0} caiu!', '{1} de {0} inimigo caiu!'],
    'statDown2': ['{1} de {0} caiu muito!', '{1} de {0} inimigo caiu muito!'],
    'statDown3': ['{1} de {0} caiu drasticamente!', '{1} de {0} inimigo caiu drasticamente!'],
    'statMax': ['{1} de {0} não pode subir mais!', '{1} de {0} inimigo não pode subir mais!'],
    'statMin': ['{1} de {0} não pode cair mais!', '{1} de {0} inimigo não pode cair mais!'],
    'healedMove': ['{0} recuperou HP!', '{0} inimigo recuperou HP!'],
    'drained': ['{0} teve a energia drenada!', '{0} inimigo teve a energia drenada!'],
    'failed': ['Mas falhou!', 'Mas falhou!'],
    'megaReact': ['A Mega Pedra de {0} está reagindo!', 'A Mega Pedra de {0} inimigo está reagindo!'],
    'megaEvolved': ['{0} megaevoluiu em {1}!', '{0} inimigo megaevoluiu em {1}!'],
    'terastallized': ['{0} terastalizou no tipo {1}!', '{0} inimigo terastalizou no tipo {1}!'],
    'dynamaxed': ['{0} dinamaxizou!', '{0} inimigo dinamaxizou!'],
    'gigantamaxed': ['{0} gigantamaxizou!', '{0} inimigo gigantamaxizou!'],
    'dmaxEnd': ['{0} voltou ao tamanho normal!', '{0} inimigo voltou ao tamanho normal!'],
    'zPower': ['{0} libera todo o seu Z-Poder!', '{0} inimigo libera todo o seu Z-Poder!'],
    'rainStart': 'Começou a chover!',
    'rainGo': 'A chuva continua.',
    'rainEnd': 'A chuva parou.',
    'sunStart': 'A luz do sol ficou forte!',
    'sunGo': 'A luz do sol está forte.',
    'sunEnd': 'A luz do sol voltou ao normal.',
    'sandStart': 'Começou uma tempestade de areia!',
    'sandGo': 'A tempestade de areia continua.',
    'sandEnd': 'A tempestade de areia passou.',
    'hailStart': 'Começou a cair granizo!',
    'hailGo': 'O granizo continua.',
    'hailEnd': 'O granizo parou.',
    'snowStart': 'Começou a nevar!',
    'snowGo': 'A neve continua.',
    'snowEnd': 'A neve parou.',
    'hurtSand': ['{0} foi atingido pela tempestade de areia!', '{0} inimigo foi atingido pela tempestade de areia!'],
    'hurtHail': ['{0} foi atingido pelo granizo!', '{0} inimigo foi atingido pelo granizo!'],
  };

  /// Evento de texto → (modelo, valores) (o Pokémon vai no lugar de {0}).
  static (String, List<String>) lineOf(BattleEvent e) {
    final line = lines[e.key]!;
    if (line is List) {
      final (side, name) = e.args.first as (int, String);
      return (line[side] as String, [name, for (final a in e.args.skip(1)) statNames['$a'] ?? '$a']);
    }
    return (line as String, [for (final a in e.args) '$a']);
  }
}

/// Monta os Pokémon da batalha (igual ao site, battleSetup.js).
class TurnBattleSetup {
  TurnBattleSetup._();

  /// Golpes que ficam de fora do preenchimento automático (recarga, carga, se sacrificar...).
  static const bannedMoves = {
    'explosion',
    'self-destruct',
    'misty-explosion',
    'memento',
    'final-gambit',
    'hyper-beam',
    'giga-impact',
    'blast-burn',
    'frenzy-plant',
    'hydro-cannon',
    'rock-wrecker',
    'roar-of-time',
    'prismatic-laser',
    'eternabeam',
    'meteor-assault',
    'solar-beam',
    'solar-blade',
    'sky-attack',
    'skull-bash',
    'razor-wind',
    'freeze-shock',
    'ice-burn',
    'geomancy',
    'meteor-beam',
    'electro-shot',
    'focus-punch',
    'dream-eater',
    'belch',
    'last-resort',
    'synchronoise',
    'fake-out',
    'first-impression',
    'steel-beam',
    'mind-blown',
    'shadow-force',
    'phantom-force',
    'dig',
    'dive',
    'fly',
    'bounce',
    'sky-drop',
    'future-sight',
    'doom-desire',
    'snore',
    'spit-up',
    'natural-gift',
    'fling',
    'present',
    'counter',
    'mirror-coat',
    'metal-burst',
    'bide',
    'endeavor',
    'super-fang',
    'natures-madness',
    'ruination',
    'guillotine',
    'fissure',
    'horn-drill',
    'sheer-cold',
    'struggle',
    'dragon-rage',
    'sonic-boom',
    'night-shade',
    'seismic-toss',
    'psywave',
    'hold-back',
    'false-swipe',
    'burn-up',
    'double-shock',
    'hyperspace-fury',
    'dark-void',
    'upper-hand',
    'poltergeist',
    'sucker-punch',
    'thunderclap',
  };

  /// Categoria do golpe (no banco do app é damage_class; no do site, category).
  static String _category(Map<String, dynamic> m) => '${m['damage_class'] ?? m['category']}';

  /// Os 4 golpes: os de dano do set e, se faltar, os melhores que aprende
  /// (poder × STAB × precisão), um de cada tipo primeiro. Igual ao site.
  static List<String> pickMoves(List<String> setMoves, List<String> learnable, List<String> types, Map<String, Map<String, dynamic>> moves,
      [Map<String, dynamic> rules = const {}]) {
    bool damaging(String slug) {
      final m = moves[slug];
      return m != null && _category(m) != 'status' && ((m['power'] as num?) ?? 0) > 0;
    }

    // Do set também valem os de status que a batalha sabe usar (rules[slug].ok).
    bool usable(String slug) => moves[slug] != null;
    final chosen = <String>[];
    for (final s in setMoves) {
      if (s.isNotEmpty && usable(s) && !chosen.contains(s) && chosen.length < 4) chosen.add(s);
    }
    double score(String slug) {
      final m = moves[slug]!;
      return (m['power'] as num) * (types.contains(m['type']) ? 1.5 : 1) * (((m['accuracy'] as num?) ?? 100) / 100);
    }

    final pool = learnable.where((s) => damaging(s) && !bannedMoves.contains(s) && !chosen.contains(s)).toList()
      ..sort((a, b) {
        final c = score(b).compareTo(score(a));
        return c != 0 ? c : a.compareTo(b);
      });
    for (final slug in pool) {
      if (chosen.length >= 4) break;
      if (!chosen.any((c) => moves[c]!['type'] == moves[slug]!['type'])) chosen.add(slug);
    }
    for (final slug in pool) {
      if (chosen.length >= 4) break;
      if (!chosen.contains(slug)) chosen.add(slug);
    }
    return chosen;
  }

  /// Membros do time → Pokémon da batalha. [name] dá o nome na tela.
  static Future<List<BattleMon>> mons(List<Member> members, String Function(Map<String, dynamic> row) name) async {
    await BattleSimulator.load();
    final data = await DamageData.load();
    final moves = await LocalDatabase.instance.movesByName();
    final rules = await LocalDatabase.instance.moveRules().catchError((_) => <String, dynamic>{});
    final battleItems = await LocalDatabase.instance.battleItems().catchError((_) => <String, dynamic>{});
    final megaStones = (battleItems['mega'] as Map?) ?? const {}, zCrystals = (battleItems['z'] as Map?) ?? const {};
    final out = <BattleMon>[];
    final allRows = await LocalDatabase.instance.allPokemonRows();
    for (final original in members) {
      final m = _entryForm(original, allRows, battleItems);
      final row = await LocalDatabase.instance.pokemonRow(m.$1);
      final calc = await TeamBattle.calcPokemon(data, m);
      if (row == null || calc == null) continue;
      final types = [for (final t in row['types'] as List) '$t'];
      final learnable = [
        for (final mv in {for (final mv in row['moves'] as List) (mv as List).first as String})
          if (moves.containsKey(mv)) mv,
      ];
      final setMoves = [for (final s in (m.$2?['moves'] as List?) ?? const []) '$s'].where(moves.containsKey).toList();
      final slugs = pickMoves(setMoves, learnable, types, moves, rules);
      if (slugs.isEmpty) continue;
      // Mecânicas, com as regras dos jogos: Mega só segurando a Mega Pedra dele
      // (a X ou a Y decide a forma), Z-Move só com o Cristal Z (e só nos golpes
      // do tipo dele), Dinamax menos Zacian/Zamazenta/Eternatus e o Tipo Tera.
      final forms = [
        for (final r in await LocalDatabase.instance.allPokemonRows())
          if (r['species'] == row['species']) r,
      ];
      final itemId = toId('${m.$2?['item'] ?? ''}'.replaceAll(RegExp(r'--held$'), ''));
      // A Mega da forma dele, se existir (Tatsugiri Droopy → Mega Tatsugiri Droopy).
      final stoneForm = megaStones[itemId];
      final megaRow = stoneForm == null
          ? null
          : forms.where((r) => r['name'] == '${row['name']}-mega').firstOrNull ?? forms.where((r) => r['name'] == stoneForm).firstOrNull;
      BattleMega? mega;
      if (megaRow != null) {
        final megaCalc = await TeamBattle.calcPokemon(data, (megaRow['id'] as int, {...?m.$2, 'ability': ''}));
        if (megaCalc != null) {
          // "charizard-mega-x" → "Mega Charizard X" (como nos jogos).
          final parts = (megaRow['name'] as String).split(RegExp(r'-mega-?'));
          final letter = parts.length > 1 && parts[1].isNotEmpty ? ' ${parts[1].toUpperCase()}' : '';
          mega = BattleMega(megaRow['id'] as int, 'Mega ${name({...row, 'name': parts[0]})}$letter',
              [for (final t in megaRow['types'] as List) '$t'], megaCalc.stats['spe']!,
              calc: megaCalc, ability: megaCalc.ability);
        }
      }
      final gmax = forms.where((r) => (r['name'] as String).endsWith('-gmax')).firstOrNull?['id'] as int?;
      final tera = '${m.$2?['tera'] ?? ''}'.toLowerCase();
      out.add(BattleMon(
        m.$1,
        name(row),
        calc.level,
        calc.maxHP(),
        calc.stats['spe']!,
        types,
        [
          for (final slug in slugs)
            BattleMove(
              slug,
              data.move(slug)?.name ?? slug,
              '${moves[slug]!['type']}',
              (moves[slug]!['power'] as num?)?.toInt() ?? 0,
              (moves[slug]!['accuracy'] as num?)?.toInt(),
              (moves[slug]!['pp'] as num?)?.toInt() ?? 10,
              (moves[slug]!['pp'] as num?)?.toInt() ?? 10,
              (moves[slug]!['priority'] as num?)?.toInt() ?? 0,
              category: _category(moves[slug]!),
              // Regras do Pokémon Showdown (efeitos, recuo, dreno, status...).
              rules: rules[slug] is Map ? Map<String, dynamic>.from(rules[slug] as Map) : null,
            ),
        ],
        calc: calc,
        shiny: m.$2?['shiny'] == true,
        mega: mega,
        gmax: gmax,
        teraType: tera.isNotEmpty ? tera : (types.isEmpty ? '' : types.first),
        gimmick: '${m.$2?['gimmick'] ?? ''}',
        zType: '${zCrystals[itemId] ?? ''}',
        noDmax: const {888, 889, 890}.contains(row['species']),
        ability: calc.ability,
      )..simulationSpecies = BattleSimulator.call('species', [row['name']])['name'] as String?
        ..simulationAbility = BattleSimulator.call('ability', [m.$2?['ability'] ?? ((row['abilities'] as List).isEmpty ? '' : (row['abilities'] as List).first[0])])['name'] as String?
        ..simulationItem = BattleSimulator.call('item', [m.$2?['item']])['name'] as String?);
    }
    return out;
  }

  /// Formas que aparecem ao entrar na batalha segurando o item: Groudon/Kyogre
  /// com Red/Blue Orb viram Primal, Zacian/Zamazenta com Rusted Sword/Shield
  /// viram Crowned (como nos jogos). Igual ao site.
  static Member _entryForm(Member member, List<Map<String, dynamic>> rows, Map<String, dynamic> battleItems) {
    final itemId = toId('${member.$2?['item'] ?? ''}'.replaceAll(RegExp(r'--held$'), ''));
    final me = rows.where((r) => r['id'] == member.$1).firstOrNull;
    if (itemId.isEmpty || me == null) return member;
    for (final e in ((battleItems['forms'] as Map?) ?? const {}).entries) {
      final form = '${e.key}';
      if (!(e.value as List).contains(itemId) || !(form.endsWith('-primal') || form.endsWith('-crowned'))) continue;
      final target = rows.where((r) => r['name'] == form && r['species'] == me['species']).firstOrNull;
      if (target != null && target['id'] != member.$1) return (target['id'] as int, member.$2);
    }
    return member;
  }

  /// Time aleatório para o computador: 6 Pokémon totalmente evoluídos (sem lendários). Igual ao site.
  static Future<List<Member>> randomTeam(double Function() random) async {
    final data = await DamageData.load();
    final rows = await LocalDatabase.instance.defaultPokemon();
    final species = await LocalDatabase.instance.speciesById();
    bool special(int id) => species[id]?['is_legendary'] == true || species[id]?['is_mythical'] == true || species[id]?['is_baby'] == true;
    final pool = [
      for (final r in rows)
        if (!special(r['id'] as int) && !(data.species[toId(data.speciesName(r['name'] as String))]?.nfe ?? false)) r['id'] as int,
    ]..sort();
    final ids = <int>[];
    while (ids.length < 6 && ids.length < pool.length) {
      final id = pool[(random() * pool.length).floor()];
      if (!ids.contains(id)) ids.add(id);
    }
    return [for (final id in ids) (id, null)];
  }

  /// A função de dano para o motor (a calculadora do Showdown).
  /// Multiplicador de um tipo de ataque contra os tipos (tabela da calculadora).
  static double Function(String, List<String>) typeEffect(DamageData data) {
    String cap(String t) => t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
    return (type, types) => types.fold(1.0, (m, d) => m * data.effectiveness(cap(type), cap(d)));
  }

  static BattleHit hitter(DamageData data) => (att, def, slug, crit, [power, weather = '']) {
        final a = att.calc, d = def.calc;
        if (a == null || d == null || data.move(slug) == null) return null;
        String cap(String t) => t.isEmpty ? t : '${t[0].toUpperCase()}${t.substring(1)}';
        try {
          // Com o status (queimadura corta o dano físico...), os estágios de
          // atributo e o Terastal da batalha; a vida em proporção (como o site,
          // que manda a porcentagem: no Dinamax ela está em dobro).
          int hpOf(CalcPokemon c, BattleMon m) => max(1, (c.maxHP() * m.hp / m.maxHp).floor());
          final attacker = a.clone()
            ..originalCurHP = hpOf(a, att)
            ..status = att.status
            ..boosts = {...a.boosts, ...att.boosts}
            ..teraType = att.terastal ? cap(att.teraType) : '';
          final defender = d.clone()
            ..originalCurHP = hpOf(d, def)
            ..status = def.status
            ..boosts = {...d.boosts, ...def.boosts}
            ..teraType = def.terastal ? cap(def.teraType) : '';
          final move = CalcMove(data, data.move(slug)!.name, isCrit: crit, ability: attacker.ability, item: attacker.item);
          // Z-Move / Max Move: o mesmo golpe com o poder da tabela, um acerto só.
          if (power != null) {
            move
              ..bp = power
              ..hits = 1;
          }
          // O clima do motor (rain, sun...) vira o da calculadora (Rain, Sun...).
          final result = calculateDamage(attacker, defender, move, CalcField(weather: calcWeather[weather] ?? ''));
          var eff = 1.0;
          for (final t in defender.teraType.isNotEmpty ? [defender.teraType] : result.defender.types) {
            eff *= data.effectiveness(result.move.type, t);
          }
          if (result.damage.every((r) => r.every((x) => x == 0))) eff = 0;
          return (rolls: result.damage, eff: eff);
        } catch (_) {
          return null;
        }
      };
}
