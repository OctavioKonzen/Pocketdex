// lib/services/turn_battle.dart
//
// Batalha por turnos (como nos jogos de GBA), igual ao site
// (web-site/src/lib/turnBattle.js e battleSetup.js). O motor não sabe
// calcular dano: recebe uma função [BattleHit] que usa a calculadora do
// Showdown (damage_calc.dart). Mesma semente e mesmos danos dão a mesma
// batalha no site e no app (test/fixtures/turn_battle.json).
//
// Simplificado: golpes de dano (com precisão, prioridade, crítico, vários
// acertos, PP e Struggle), troca de Pokémon e o adversário controlado pelo
// computador. Sem status, clima, efeitos secundários nem mudança de atributos.
// Lado 0 = você, lado 1 = o computador.

import 'damage_calc.dart';
import 'local_database.dart';
import 'team_battle.dart';

class BattleMove {
  final String slug, name, type;
  final int power, maxPp, priority;
  final int? accuracy;
  int pp;
  BattleMove(this.slug, this.name, this.type, this.power, this.accuracy, this.pp, this.maxPp, this.priority);
  BattleMove copy() => BattleMove(slug, name, type, power, accuracy, maxPp, maxPp, priority);
}

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
  BattleMon(this.id, this.name, this.level, this.maxHp, this.spe, this.types, this.moves, {this.calc, this.shiny = false}) : hp = maxHp;

  /// Com HP e PP cheios (para "batalhar de novo").
  BattleMon fresh() => BattleMon(id, name, level, maxHp, spe, types, [for (final m in moves) m.copy()], calc: calc, shiny: shiny);
}

/// Resultado de um golpe: os danos possíveis de cada acerto e a eficácia (0 = não afeta).
typedef HitResult = ({List<List<int>> rolls, double eff});
typedef BattleHit = HitResult? Function(BattleMon att, BattleMon def, String slug, bool crit);

/// Evento para a tela ir mostrando: texto, HP, troca ou desmaio.
class BattleEvent {
  final String t; // text | hp | switch | faint
  final String key;
  final List<Object> args;
  final int side, value;
  const BattleEvent.text(this.key, this.args)
      : t = 'text',
        side = -1,
        value = 0;
  const BattleEvent.hp(this.side, this.value)
      : t = 'hp',
        key = '',
        args = const [];
  const BattleEvent.switched(this.side, this.value)
      : t = 'switch',
        key = '',
        args = const [];
  const BattleEvent.faint(this.side)
      : t = 'faint',
        key = '',
        args = const [],
        value = 0;
}

final struggle = BattleMove('struggle', 'Struggle', 'normal', 50, null, 1, 1, 0);
const _critChance = 1 / 24;

class TurnBattle {
  TurnBattle(List<BattleMon> mine, List<BattleMon> theirs, this.random) : teams = [mine, theirs];

  final List<List<BattleMon>> teams;
  final List<int> activeIndex = [0, 0];
  final double Function() random;
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
      final value = _expected(hit, me, foe, me.moves[i]);
      if (value > bestValue) {
        best = i;
        bestValue = value;
      }
    }
    return best;
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
    final move = moveIndex < 0 ? struggle : mon.moves[moveIndex];
    if (moveIndex >= 0) move.pp -= 1;
    _say(events, 'used', [_label(side), move.name]);
    if (move.accuracy != null && random() * 100 >= move.accuracy!) {
      _say(events, 'missed', [_label(side)]);
      return;
    }
    final crit = random() < _critChance;
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
    if (move.slug == 'struggle') {
      final recoil = mon.maxHp ~/ 4;
      mon.hp = (mon.hp - (recoil < 1 ? 1 : recoil)).clamp(0, mon.maxHp);
      events.add(BattleEvent.hp(side, mon.hp));
      _say(events, 'recoil', [_label(side)]);
    }
    for (final s in [foeSide, side]) {
      final m = active(s);
      if (m.hp <= 0 && !m.faintShown) {
        m.faintShown = true;
        events.add(BattleEvent.faint(s));
        _say(events, 'fainted', [_label(s)]);
      }
    }
  }

  void _switchTo(int side, int index, List<BattleEvent> events) {
    if (active(side).hp > 0) _say(events, side == 0 ? 'comeBack' : 'foeWithdrew', [_label(side)]);
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

  /// Um turno: [move] (índice; -1 = Struggle) ou [switchTo]. Devolve os eventos.
  List<BattleEvent> playTurn(BattleHit hit, {int? move, int? switchTo}) {
    final events = <BattleEvent>[];
    if (winner != null || needSwitch) return events;
    final cpu = cpuMove(hit);
    if (switchTo != null) _switchTo(0, switchTo, events);
    var order = <(int, int)>[(1, cpu)];
    if (switchTo == null) order.add((0, move ?? -1));
    int priority((int, int) o) => o.$2 < 0 ? 0 : active(o.$1).moves[o.$2].priority;
    if (order.length == 2) {
      final a = order[0], b = order[1];
      final pa = priority(a), pb = priority(b);
      final sa = active(a.$1).spe, sb = active(b.$1).spe;
      final tie = random() < 0.5;
      final bFirst = pb > pa || (pb == pa && (sb > sa || (sb == sa && tie)));
      if (bFirst) order = [b, a];
    }
    for (final o in order) {
      if (active(o.$1).hp <= 0 || active(1 - o.$1).hp <= 0) continue;
      _doMove(o.$1, o.$2, hit, events);
    }
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
  };

  /// Evento de texto → (modelo, valores) (o Pokémon vai no lugar de {0}).
  static (String, List<String>) lineOf(BattleEvent e) {
    final line = lines[e.key]!;
    if (line is List) {
      final (side, name) = e.args.first as (int, String);
      return (line[side] as String, [name, for (final a in e.args.skip(1)) '$a']);
    }
    return (line as String, [for (final a in e.args) '$a']);
  }
}

/// Monta os Pokémon da batalha (igual ao site, battleSetup.js).
class TurnBattleSetup {
  TurnBattleSetup._();

  /// Golpes que ficam de fora do preenchimento automático (recarga, carga, se sacrificar...).
  static const bannedMoves = {
    'explosion', 'self-destruct', 'misty-explosion', 'memento', 'final-gambit',
    'hyper-beam', 'giga-impact', 'blast-burn', 'frenzy-plant', 'hydro-cannon', 'rock-wrecker', 'roar-of-time',
    'prismatic-laser', 'eternabeam', 'meteor-assault', 'solar-beam', 'solar-blade', 'sky-attack', 'skull-bash',
    'razor-wind', 'freeze-shock', 'ice-burn', 'geomancy', 'meteor-beam', 'electro-shot', 'focus-punch',
    'dream-eater', 'belch', 'last-resort', 'synchronoise', 'fake-out', 'first-impression', 'steel-beam',
    'mind-blown', 'shadow-force', 'phantom-force', 'dig', 'dive', 'fly', 'bounce', 'sky-drop', 'future-sight',
    'doom-desire', 'snore', 'spit-up', 'natural-gift', 'fling', 'present', 'counter', 'mirror-coat',
    'metal-burst', 'bide', 'endeavor', 'super-fang', 'natures-madness', 'ruination', 'guillotine', 'fissure',
    'horn-drill', 'sheer-cold', 'struggle', 'dragon-rage', 'sonic-boom', 'night-shade',
    'seismic-toss', 'psywave', 'hold-back', 'false-swipe', 'burn-up', 'double-shock', 'hyperspace-fury',
    'dark-void', 'upper-hand', 'poltergeist', 'sucker-punch', 'thunderclap',
  };

  /// Os 4 golpes: os de dano do set e, se faltar, os melhores que aprende
  /// (poder × STAB × precisão), um de cada tipo primeiro. Igual ao site.
  static List<String> pickMoves(List<String> setMoves, List<String> learnable, List<String> types, Map<String, Map<String, dynamic>> moves) {
    bool damaging(String slug) {
      final m = moves[slug];
      return m != null && m['category'] != 'status' && ((m['power'] as num?) ?? 0) > 0;
    }

    final chosen = <String>[];
    for (final s in setMoves) {
      if (s.isNotEmpty && damaging(s) && !chosen.contains(s) && chosen.length < 4) chosen.add(s);
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
      final slugs = pickMoves(setMoves, learnable, types, moves);
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
              (moves[slug]!['power'] as num).toInt(),
              (moves[slug]!['accuracy'] as num?)?.toInt(),
              (moves[slug]!['pp'] as num?)?.toInt() ?? 10,
              (moves[slug]!['pp'] as num?)?.toInt() ?? 10,
              (moves[slug]!['priority'] as num?)?.toInt() ?? 0,
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
          final attacker = a.clone()..originalCurHP = att.hp.clamp(1, a.maxHP());
          final defender = d.clone()..originalCurHP = def.hp.clamp(1, d.maxHP());
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
