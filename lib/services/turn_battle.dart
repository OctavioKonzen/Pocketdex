// lib/services/turn_battle.dart
//
// Batalha por turnos (como nos jogos de GBA), igual ao site
// (web-site/src/lib/turnBattle.js e battleSetup.js). O motor não sabe
// calcular dano: recebe uma função [BattleHit] que usa a calculadora do
// Showdown (damage_calc.dart). Mesma semente e mesmos danos dão a mesma
// batalha no site e no app (test/fixtures/turn_battle.json).
//
// Regras dos golpes do Pokémon Showdown (move_rules.json, tool/build_move_rules.mjs):
// precisão, prioridade, crítico (e golpes com mais chance de crítico), vários
// acertos, PP, Struggle, recuo, dreno, cura, status (queimadura, paralisia,
// veneno, veneno grave, sono e congelamento), mudanças de atributo (−6 a +6),
// efeitos secundários (com a chance de cada um) e recuar. Mais troca de
// Pokémon, Bolsa e o adversário controlado pelo computador. Sem clima,
// campo nem golpes que mexem no campo (Stealth Rock, Protect...).
// Lado 0 = você, lado 1 = o computador.

import 'dart:math';

import 'damage_calc.dart';
import 'local_database.dart';
import 'team_battle.dart';

class BattleMove {
  final String slug, name, type, category;
  final int power, maxPp, priority;
  final int? accuracy;

  /// Regras do Pokémon Showdown (move_rules.json): efeitos, recuo, dreno, status...
  final Map<String, dynamic>? rules;
  int pp;
  BattleMove(this.slug, this.name, this.type, this.power, this.accuracy, this.pp, this.maxPp, this.priority,
      {this.category = 'physical', this.rules});
  BattleMove copy() => BattleMove(slug, name, type, power, accuracy, maxPp, maxPp, priority, category: category, rules: rules);
}

/// Atributos que mudam na batalha e o nome deles nas falas (em português; a tela traduz).
const battleStats = ['atk', 'def', 'spa', 'spd', 'spe'];
const statNames = {'atk': 'Ataque', 'def': 'Defesa', 'spa': 'Ataque Especial', 'spd': 'Defesa Especial', 'spe': 'Velocidade'};

class BattleMon {
  final int id;
  final String name;
  final int level, maxHp, spe;
  final List<String> types;
  final List<BattleMove> moves;
  final bool shiny;

  /// Pokémon da calculadora (com Nature, EVs, IVs, item e habilidade).
  final CalcPokemon? calc;
  int hp;
  bool faintShown = false;

  /// Status ('', brn, par, psn, tox, slp, frz), turnos de sono, contador do
  /// veneno grave, estágios de atributo (−6 a +6) e se recuou neste turno.
  String status = '';
  int sleep = 0, toxic = 0;
  bool flinch = false;
  Map<String, int> boosts = {for (final s in battleStats) s: 0};
  BattleMon(this.id, this.name, this.level, this.maxHp, this.spe, this.types, this.moves, {this.calc, this.shiny = false}) : hp = maxHp;

  /// Com HP e PP cheios (para "batalhar de novo").
  BattleMon fresh() => BattleMon(id, name, level, maxHp, spe, types, [for (final m in moves) m.copy()], calc: calc, shiny: shiny);
}

/// Resultado de um golpe: os danos possíveis de cada acerto e a eficácia (0 = não afeta).
typedef HitResult = ({List<List<int>> rolls, double eff});
typedef BattleHit = HitResult? Function(BattleMon att, BattleMon def, String slug, bool crit);

/// Evento para a tela ir mostrando: texto, HP, troca, desmaio, a animação
/// do golpe (attack, com o tipo, a categoria e o golpe) / do erro (miss), o
/// item usado num Pokémon do time (heal: [index] e o HP em [value]) ou o
/// status novo (status: em [type]; '' = curou).
class BattleEvent {
  final String t; // text | hp | switch | faint | attack | miss | heal | status
  final String key;
  final List<Object> args;
  final int side, value, index;
  final String type, category, slug;
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

/// Velocidade na hora da ordem: estágio e paralisia (metade).
int speedOf(BattleMon mon) {
  final spe = (mon.spe * _stageMult(mon.boosts['spe'] ?? 0)).floor();
  return mon.status == 'par' ? spe ~/ 2 : spe;
}

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
        ..status = ''
        ..sleep = 0
        ..toxic = 0
        ..flinch = false
        ..boosts = {for (final s in battleStats) s: 0};
    }
  }

  final List<List<BattleMon>> teams;
  final List<int> activeIndex = [0, 0];
  final double Function() random;
  final List<Map<String, int>> bags = [
    for (var i = 0; i < 2; i++) {for (final item in battleItems) item.slug: item.count},
  ];
  int turn = 1;
  int? winner; // 0 = você ganhou, 1 = o computador
  bool needSwitch = false; // seu Pokémon desmaiou: escolha outro

  BattleMon active(int side) => teams[side][activeIndex[side]];
  int _alive(int side) => teams[side].where((p) => p.hp > 0).length;
  void _say(List<BattleEvent> events, String key, [List<Object> args = const []]) => events.add(BattleEvent.text(key, args));
  (int, String) _label(int side) => (side, active(side).name);

  /// Golpes que dá para usar; sem PP em nenhum, só Struggle.
  static List<int> usableMoves(BattleMon mon) => [
        for (var i = 0; i < mon.moves.length; i++)
          if (mon.moves[i].pp > 0) i,
      ];

  static double _expected(BattleHit hit, BattleMon att, BattleMon def, BattleMove move) {
    if (move.category == 'status') return 0;
    final r = hit(att, def, move.slug, false);
    if (r == null || r.eff == 0) return 0;
    var avg = 0.0;
    for (final rolls in r.rolls) {
      avg += rolls.fold<int>(0, (a, b) => a + b) / rolls.length;
    }
    return (avg < def.hp ? avg : def.hp.toDouble()) * (move.accuracy == null ? 1 : move.accuracy! / 100);
  }

  /// Escolha do computador: o golpe com mais dano esperado (às vezes outro qualquer).
  int cpuMove(BattleHit hit) {
    final me = active(1), foe = active(0);
    final usable = usableMoves(me);
    if (usable.isEmpty) return -1;
    if (random() < 0.15) return usable[(random() * usable.length).floor()];
    var best = usable.first;
    var bestValue = -1.0;
    for (final i in usable) {
      final move = me.moves[i];
      final value = move.category == 'status' ? _statusValue(me, foe, move) : _expected(hit, me, foe, move);
      if (value > bestValue) {
        best = i;
        bestValue = value;
      }
    }
    return best;
  }

  /// Quanto vale um golpe de status para o computador (comparado com dano).
  static double _statusValue(BattleMon me, BattleMon foe, BattleMove move) {
    final r = move.rules ?? const {};
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
    final h = r['h'] as List?;
    if (h != null) {
      if (mon.hp >= mon.maxHp) {
        _say(events, 'failed', [_label(side)]);
      } else {
        mon.hp = (mon.hp + (mon.maxHp * (h[0] as num) / (h[1] as num)).floor()).clamp(0, mon.maxHp);
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
        events.add(BattleEvent.faint(s));
        _say(events, 'fainted', [_label(s)]);
      }
    }
  }

  /// Fim do turno: queimadura e veneno tiram vida; quem recuou volta ao normal.
  void _endOfTurn(List<BattleEvent> events) {
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
      if (mon.hp <= 0) continue;
      var value = 0.0;
      for (final m in usableMoves(mon)) {
        final v = _expected(hit, mon, foe, mon.moves[m]);
        if (v > value) value = v;
      }
      if (value > bestValue) {
        best = i;
        bestValue = value;
      }
    }
    return best;
  }

  void _doMove(int side, int moveIndex, BattleHit hit, List<BattleEvent> events) {
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
    _say(events, 'used', [_label(side), move.name]);
    if (move.accuracy != null && random() * 100 >= move.accuracy!) {
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
    final rules = move.rules ?? const <String, dynamic>{};
    final crit = random() < _critChance[min(3, (rules['c'] as num?)?.toInt() ?? 0)];
    final r = hit(mon, target, move.slug, crit);
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
        if (eff['f'] != null && target.hp > 0) target.flinch = true;
        if (eff['sb'] != null && mon.hp > 0) _boost(side, eff['sb'] as Map, events);
      }
      if (rules['sb'] != null && mon.hp > 0) _boost(side, rules['sb'] as Map, events);
    }
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
  String? _cpuItem() {
    final me = active(1);
    if (me.hp * 4 > me.maxHp) return null;
    final potion = battleItems.reversed.where((i) => i.heal > 0 && (bags[1][i.slug] ?? 0) > 0).firstOrNull;
    if (potion == null || random() >= 0.5) return null;
    return potion.slug;
  }

  void _switchTo(int side, int index, List<BattleEvent> events) {
    final before = active(side);
    if (before.hp > 0) _say(events, side == 0 ? 'comeBack' : 'foeWithdrew', [_label(side)]);
    // Quem sai perde as mudanças de atributo (e o veneno grave recomeça).
    before.boosts = {for (final s in battleStats) s: 0};
    before.flinch = false;
    if (before.toxic > 0) before.toxic = 1;
    activeIndex[side] = index;
    events.add(BattleEvent.switched(side, index));
    _say(events, side == 0 ? 'go' : 'foeSent', [_label(side)]);
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

  /// Um turno: [move] (índice; -1 = Struggle), [switchTo] ou [item] em
  /// [target] (índice no time). Trocas e itens vêm antes dos golpes.
  List<BattleEvent> playTurn(BattleHit hit, {int? move, int? switchTo, String? item, int? target}) {
    final events = <BattleEvent>[];
    if (winner != null || needSwitch) return events;
    final cpuPotion = _cpuItem();
    final cpu = cpuPotion != null ? null : cpuMove(hit);
    if (switchTo != null) _switchTo(0, switchTo, events);
    if (item != null) _useItem(0, item, target ?? activeIndex[0], events);
    if (cpuPotion != null) _useItem(1, cpuPotion, activeIndex[1], events);
    var order = <(int, int)>[];
    if (cpu != null) order.add((1, cpu));
    if (switchTo == null && item == null) order.add((0, move ?? -1));
    int priority((int, int) o) => o.$2 < 0 ? 0 : active(o.$1).moves[o.$2].priority;
    if (order.length == 2) {
      final a = order[0], b = order[1];
      final pa = priority(a), pb = priority(b);
      final sa = speedOf(active(a.$1)), sb = speedOf(active(b.$1));
      final tie = random() < 0.5;
      final bFirst = pb > pa || (pb == pa && (sb > sa || (sb == sa && tie)));
      if (bFirst) order = [b, a];
    }
    for (final o in order) {
      if (active(o.$1).hp <= 0 || active(1 - o.$1).hp <= 0) continue;
      _doMove(o.$1, o.$2, hit, events);
    }
    _endOfTurn(events);
    _checkEnd(hit, events);
    turn += 1;
    return events;
  }

  /// Seu Pokémon desmaiou: manda outro (não gasta turno).
  List<BattleEvent> replace(int index) {
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
    bool usable(String slug) =>
        damaging(slug) || (moves[slug] != null && _category(moves[slug]!) == 'status' && (rules[slug] as Map?)?['ok'] != null);
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
    final data = await DamageData.load();
    final moves = await LocalDatabase.instance.movesByName();
    final rules = await LocalDatabase.instance.moveRules().catchError((_) => <String, dynamic>{});
    final out = <BattleMon>[];
    for (final m in members) {
      final row = await LocalDatabase.instance.pokemonRow(m.$1);
      final calc = await TeamBattle.calcPokemon(data, m);
      if (row == null || calc == null) continue;
      final types = [for (final t in row['types'] as List) '$t'];
      final learnable = [
        for (final mv in {for (final mv in row['moves'] as List) (mv as List).first as String})
          if (data.move(mv) != null) mv,
      ];
      final setMoves = [for (final s in (m.$2?['moves'] as List?) ?? const []) '$s'].where((s) => data.move(s) != null).toList();
      final slugs = pickMoves(setMoves, learnable, types, moves, rules);
      if (slugs.isEmpty) continue;
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
              data.move(slug)!.name,
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
      ));
    }
    return out;
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
  static BattleHit hitter(DamageData data) => (att, def, slug, crit) {
        final a = att.calc, d = def.calc;
        if (a == null || d == null || data.move(slug) == null) return null;
        try {
          // Com o status (queimadura corta o dano físico...) e os estágios de atributo da batalha.
          final attacker = a.clone()
            ..originalCurHP = att.hp.clamp(1, a.maxHP())
            ..status = att.status
            ..boosts = {...a.boosts, ...att.boosts};
          final defender = d.clone()
            ..originalCurHP = def.hp.clamp(1, d.maxHP())
            ..status = def.status
            ..boosts = {...d.boosts, ...def.boosts};
          final move = CalcMove(data, data.move(slug)!.name, isCrit: crit, ability: attacker.ability, item: attacker.item);
          final result = calculateDamage(attacker, defender, move, CalcField());
          var eff = 1.0;
          for (final t in result.defender.types) {
            eff *= data.effectiveness(result.move.type, t);
          }
          if (result.damage.every((r) => r.every((x) => x == 0))) eff = 0;
          return (rolls: result.damage, eff: eff);
        } catch (_) {
          return null;
        }
      };
}
