import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/damage_calc.dart';
import 'package:pocket_dex/services/league.dart';
import 'package:pocket_dex/services/local_database.dart';
import 'package:pocket_dex/services/move_anim.dart';
import 'package:pocket_dex/services/turn_battle.dart';

// Batalha de mentira (dano simples, sem a calculadora), a mesma do site
// (web-site/src/lib/turnBattle.test.js): tem que dar exatamente o registro
// de test/fixtures/turn_battle.json.
BattleMove _move(String slug, String type, int power, int? accuracy, int pp,
        [int priority = 0, Map<String, dynamic>? rules, String category = 'physical']) =>
    BattleMove(slug, slug, type, power, accuracy, pp, pp, priority, rules: rules, category: category);
BattleMon _mon(int id, String name, List<String> types, int hp, int spe, List<BattleMove> moves, {BattleMega? mega, String ability = ''}) =>
    BattleMon(id, name, 50, hp, spe, types, moves, mega: mega, ability: ability);

HitResult? _fakeHit(BattleMon att, BattleMon def, String slug, bool crit, [int? override, String weather = '']) {
  final m = att.moves.where((x) => x.slug == slug).firstOrNull;
  final power = override ?? m?.power ?? 50, type = m?.type ?? 'normal';
  final eff = type == 'normal' && def.types.contains('ghost')
      ? 0.0
      : type == 'water' && def.types.contains('fire')
          ? 2.0
          : type == 'grass' && def.types.contains('fire')
              ? 0.5
              : 1.0;
  // Clima: chuva fortalece água e enfraquece fogo; sol, o contrário.
  final boosted = (weather == 'rain' && type == 'water') || (weather == 'sun' && type == 'fire');
  final weakened = (weather == 'rain' && type == 'fire') || (weather == 'sun' && type == 'water');
  final w = boosted
      ? 1.5
      : weakened
          ? 0.5
          : 1.0;
  final roll = [for (var i = 0; i < 16; i++) (power * (85 + i) / 100 * eff * w * 0.5).floor()];
  return (rolls: slug == 'double-hit' ? [roll, roll] : [roll], eff: eff);
}

/// Registro dos eventos em texto (igual ao do teste do site).
void Function(List<BattleEvent>) _writer(List<String> log) => (events) {
      for (final e in events) {
        if (e.t == 'text') {
          final (line, args) = TurnBattle.lineOf(e);
          var text = line;
          for (var i = 0; i < args.length; i++) {
            text = text.replaceFirst('{$i}', args[i]);
          }
          log.add(text);
        } else if (e.t == 'faint' || e.t == 'miss') {
          log.add('[${e.t} ${e.side}]');
        } else if (e.t == 'attack') {
          log.add('[attack ${e.side} ${e.type}]');
        } else if (e.t == 'status') {
          log.add('[status ${e.side} ${e.type}]');
        } else if (e.t == 'heal') {
          log.add('[heal ${e.side} ${e.index} ${e.value}]');
        } else if (e.t == 'mega') {
          log.add('[mega ${e.side} ${e.value}]');
        } else if (e.t == 'tera') {
          log.add('[tera ${e.side} ${e.type}]');
        } else if (e.t == 'dmax') {
          log.add('[dmax ${e.side} ${e.index} ${e.value}]');
        } else if (e.t == 'weather') {
          log.add('[weather ${e.type}]');
        } else {
          log.add('[${e.t} ${e.side} ${e.value}]');
        }
      }
    };

/// Batalha com clima (igual ao site, test/fixtures/turn_battle_weather.json):
/// Sand Stream ao entrar, Rain Dance, Thunder na chuva, Swift Swim, Drought
/// quando o outro entra, Sunny Day e o dano da areia.
List<String> fakeWeatherLog() {
  final battle = TurnBattle(
    [
      _mon(1, 'Chuva', ['water'], 300, 50, [
        _move('rain-dance', 'water', 0, null, 5, 0, {'w': 'rain', 'ok': 1}, 'status'),
        _move('thunder', 'electric', 110, 70, 10, 0, {
          'x': [
            {'p': 30, 's': 'par'},
          ],
        }),
        _move('water-gun', 'water', 40, 100, 25),
      ], ability: 'Swift Swim'),
    ],
    [
      _mon(2, 'Areia', ['rock'], 100, 60, [
        _move('rock-throw', 'rock', 50, 90, 15),
        _move('moonlight', 'fairy', 0, null, 5, 0, {
          'h': [1, 2],
          'ok': 1,
        }, 'status'),
      ], ability: 'Sand Stream'),
      _mon(3, 'Sol', ['fire'], 90, 40, [
        _move('sunny-day', 'fire', 0, null, 5, 0, {'w': 'sun', 'ok': 1}, 'status'),
        _move('ember', 'fire', 40, 100, 25),
      ], ability: 'Drought'),
    ],
    League.seededRandom(7),
  );
  final log = <String>[];
  final write = _writer(log);
  write(battle.start());
  for (var turn = 0; turn < 40 && battle.winner == null; turn++) {
    final me = battle.active(0);
    // Water Gun no primeiro (a areia machuca), depois Rain Dance sempre que
    // a chuva não está; senão Thunder.
    final pick = turn == 0
        ? 2
        : battle.weather != 'rain' && me.moves[0].pp > 0
            ? 0
            : me.moves[1].pp > 0
                ? 1
                : 2;
    write(battle.playTurn(_fakeHit, move: pick));
    log.add('clima: ${battle.weather.isEmpty ? '-' : battle.weather} ${battle.weatherTurns}');
  }
  log.add('vencedor: ${battle.winner}');
  return log;
}

List<String> fakeBattleLog() {
  final battle = TurnBattle(
    [
      _mon(1, 'Azul', ['water'], 110, 80, [
        _move('water-gun', 'water', 60, 100, 3, 0, {
          'd': [1, 2],
          'c': 1,
        }),
        _move('quick-attack', 'normal', 40, 100, 30, 1),
        _move('double-hit', 'normal', 35, 90, 10, 0, {
          'x': [
            {'p': 50, 'f': 1},
          ],
        }),
      ]),
      _mon(2, 'Verde', ['grass'], 100, 60, [
        _move('toxic', 'poison', 0, 90, 2, 0, {'s': 'tox', 'ok': 1}, 'status'),
        _move('swords-dance', 'normal', 0, null, 1, 0, {
          'b': {'atk': 2},
          't': 'self',
          'ok': 1,
        }, 'status'),
        _move('vine-whip', 'grass', 45, 100, 25, 0, {
          'r': [1, 3],
          'sb': {'def': -1},
        }),
        _move('tackle', 'normal', 40, 100, 35),
      ]),
    ],
    [
      _mon(3, 'Fogo', ['fire'], 120, 90, [
        _move('ember', 'fire', 60, 100, 25, 0, {
          'x': [
            {'p': 60, 's': 'brn'},
          ],
        }),
        _move('scratch', 'normal', 40, 95, 35),
      ], mega: const BattleMega(30, 'Mega Fogo', ['fire', 'dragon'], 110)),
      _mon(4, 'Fantasma', ['ghost'], 90, 70, [
        _move('lick', 'ghost', 50, 100, 30, 0, {
          'x': [
            {'p': 70, 's': 'par'},
            {
              'p': 40,
              'b': {'spe': -1},
            },
          ],
        }),
        _move('shadow-sneak', 'ghost', 40, 100, 30, 1),
        _move('recover', 'normal', 0, null, 5, 0, {
          'h': [1, 2],
          'ok': 1,
        }, 'status'),
      ]),
    ],
    League.seededRandom(42),
  );
  final log = <String>[];
  final write = _writer(log);

  for (var turn = 0; turn < 60 && battle.winner == null; turn++) {
    if (battle.needSwitch) {
      write(battle.replace(battle.teams[0].indexWhere((m) => m.hp > 0)));
      continue;
    }
    final me = battle.active(0);
    final usable = TurnBattle.usableMoves(me);
    final fainted = battle.teams[0].indexWhere((m) => m.hp <= 0);
    // Dinamax no primeiro turno (o computador escolhe a dele sozinho).
    if (turn == 0) {
      write(battle.playTurn(_fakeHit, move: 0, gimmick: 'dmax'));
    } else if (turn == 2 && battle.teams[0][1].hp > 0) {
      write(battle.playTurn(_fakeHit, switchTo: 1));
    } else if (turn == 5 && battle.canUseItem(0, 'super-potion', battle.activeIndex[0])) {
      write(battle.playTurn(_fakeHit, item: 'super-potion', target: battle.activeIndex[0]));
    } else if (fainted >= 0 && battle.canUseItem(0, 'revive', fainted)) {
      write(battle.playTurn(_fakeHit, item: 'revive', target: fainted));
    } else {
      write(battle.playTurn(_fakeHit, move: usable.isEmpty ? -1 : usable.first));
    }
  }
  log.add('vencedor: ${battle.winner}');
  return log;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('igual ao site (mesma semente, mesmo registro)', () {
    final expected = (jsonDecode(File('test/fixtures/turn_battle.json').readAsStringSync()) as List).cast<String>();
    expect(fakeBattleLog(), expected);
  });

  test('clima igual ao site (mesma semente, mesmo registro)', () {
    final expected = (jsonDecode(File('test/fixtures/turn_battle_weather.json').readAsStringSync()) as List).cast<String>();
    expect(fakeWeatherLog(), expected);
  });

  test('escolhe os golpes: os do set e, se faltar, um de cada tipo', () {
    final moves = <String, Map<String, dynamic>>{
      'flamethrower': {'type': 'fire', 'category': 'special', 'power': 90, 'accuracy': 100},
      'fire-blast': {'type': 'fire', 'category': 'special', 'power': 110, 'accuracy': 85},
      'air-slash': {'type': 'flying', 'category': 'special', 'power': 75, 'accuracy': 95},
      'dragon-claw': {'type': 'dragon', 'category': 'physical', 'power': 80, 'accuracy': 100},
      'hyper-beam': {'type': 'normal', 'category': 'special', 'power': 150, 'accuracy': 90},
      'roost': {'type': 'flying', 'category': 'status', 'power': null, 'accuracy': null},
      'scratch': {'type': 'normal', 'category': 'physical', 'power': 40, 'accuracy': 100},
    };
    expect(TurnBattleSetup.pickMoves(['roost', 'flamethrower'], moves.keys.toList(), ['fire', 'flying'], moves),
        ['flamethrower', 'air-slash', 'dragon-claw', 'scratch']);
  });

  test('monta os Pokémon com a calculadora (igual ao site)', () async {
    final set = {
      'level': 50,
      'nature': 'Timid',
      'moves': ['flamethrower', 'roost'],
      'evs': {'hp': 4, 'spa': 252, 'spe': 252},
    };
    final mons = await TurnBattleSetup.mons([(6, set)], (row) => '${row['name']}');
    final charizard = mons.single;
    expect(charizard.maxHp, 154);
    expect(charizard.spe, 167);
    expect(charizard.moves.length, 4);
    expect(charizard.moves.first.name, 'Flamethrower');
    expect(charizard.moves.first.pp, 15);
    expect(charizard.moves.first.category, 'special');
    expect(charizard.mega, isNull); // sem a Mega Pedra não megaevolui
  });

  test('mecânicas com as regras dos jogos (igual ao site)', () async {
    final mons = await TurnBattleSetup.mons([
      (6, {'level': 50, 'item': 'charizardite-y', 'tera': 'grass', 'gimmick': 'mega', 'moves': ['flamethrower']}),
      (6, {'level': 50, 'item': 'firium-z--held', 'moves': ['flamethrower', 'air-slash']}),
      (888, {'level': 50, 'moves': ['play-rough']}),
    ], (row) => '${row['name']}');
    expect(mons[0].mega?.id, 10035);
    expect(mons[0].mega?.types, ['fire', 'flying']);
    expect(mons[0].gmax, 10196);
    expect(mons[0].teraType, 'grass');
    expect(mons[0].gimmick, 'mega');
    expect(mons[1].zType, 'fire');
    expect(mons[2].noDmax, isTrue);
  });

  test('formas pelo item: Primal e Crowned ao entrar; a Mega da própria forma (igual ao site)', () async {
    final mons = await TurnBattleSetup.mons([
      (383, {'level': 50, 'item': 'red-orb', 'moves': ['earthquake']}),
      (888, {'level': 50, 'item': 'rusted-sword', 'moves': ['play-rough']}),
      (10258, {'level': 50, 'item': 'tatsugirinite', 'moves': ['draco-meteor']}),
    ], (row) => '${row['name']}');
    expect(mons[0].id, 10078);
    expect(mons[1].id, 10188);
    expect(mons[2].mega?.id, 10323);
  });

  test('clima com a calculadora: chuva fortalece Surf; Drizzle e Drought (igual ao site)', () async {
    final mons = await TurnBattleSetup.mons([
      (9, {'level': 50, 'moves': ['surf']}),
      (6, {'level': 50, 'item': 'charizardite-y', 'moves': ['flamethrower']}),
      (279, {'level': 50, 'ability': 'Drizzle', 'moves': ['hurricane']}),
    ], (row) => '${row['name']}');
    final hit = TurnBattleSetup.hitter(await DamageData.load());
    final dry = hit(mons[0], mons[1], 'surf', false)!, wet = hit(mons[0], mons[1], 'surf', false, null, 'rain')!;
    expect(wet.rolls.first.reduce(max), greaterThan(dry.rolls.first.reduce(max)));
    expect(mons[2].ability, 'Drizzle');
    expect(mons[1].mega?.ability, 'Drought');
  });

  test('dano de verdade: água em fogo é super eficaz, normal em fantasma não afeta', () async {
    final mons = await TurnBattleSetup.mons([(9, null), (6, null), (94, null)], (row) => '${row['name']}');
    final data = await DamageData.load();
    final hit = TurnBattleSetup.hitter(data);
    final water = hit(mons[0], mons[1], 'surf', false)!;
    expect(water.eff, 2);
    expect(water.rolls.single.length, 16);
    expect(hit(mons[1], mons[2], 'body-slam', false)!.eff, 0);
  });

  test('animação de cada golpe igual ao site (todos os golpes do banco)', () async {
    final expected = (jsonDecode(File('test/fixtures/move_anims.json').readAsStringSync()) as Map).cast<String, String>();
    final moves = await LocalDatabase.instance.movesByName();
    final all = {
      for (final slug in (moves.keys.where((k) => moves[k]!['damage_class'] != 'status').toList()..sort()))
        slug: moveAnim(slug, '${moves[slug]!['type']}', '${moves[slug]!['damage_class']}'),
    };
    expect(all, expected);
    for (final kind in _kinds) {
      expect(fxPlan(kind, 'fire', 0, const Point(24, 69), const Point(75, 25)).parts, isNotEmpty, reason: kind);
    }
  });

  test('cada golpe com a sua animação (move_anims.json) e peças iguais às do site', () async {
    final table = await LocalDatabase.instance.moveAnims();
    final keys = [for (final e in table.values) (e as List).join('|')];
    expect(keys.toSet().length, keys.length);
    expect((table['ice-punch'] as List).take(2), ['punch', '🧊']);

    Map<String, Object> json(FxPlan plan) => {
          'parts': [
            for (final p in plan.parts)
              switch (p.shape) {
                'emoji' => {
                    'shape': 'emoji', 'char': p.char, 'x0': p.x0, 'y0': p.y0, 'x1': p.x1, 'y1': p.y1, 'delay': p.delay, 'dur': p.dur,
                    's0': p.s0, 's1': p.s1, 'o0': p.o0, 'o1': p.o1, 'rot': p.rot, 'size': p.size, //
                  },
                'line' => {'shape': 'line', 'x0': p.x0, 'y0': p.y0, 'x1': p.x1, 'y1': p.y1, 'delay': p.delay, 'dur': p.dur, 'width': p.width},
                'ring' => {'shape': 'ring', 'x': p.x0, 'y': p.y0, 'delay': p.delay, 'dur': p.dur},
                _ => {'shape': 'wave', 'dir': p.dir, 'delay': p.delay, 'dur': p.dur},
              },
          ],
          'shake': plan.shake,
          'flash': plan.flash,
          'duration': plan.duration,
        };
    void same(Object? a, Object? b, String path) {
      if (a is num && b is num) {
        expect(a.toDouble(), closeTo(b.toDouble(), 1e-6), reason: path);
      } else if (a is Map && b is Map) {
        expect(a.keys.toSet(), b.keys.toSet(), reason: path);
        for (final k in a.keys) {
          same(a[k], b[k], '$path.$k');
        }
      } else if (a is List && b is List) {
        expect(a.length, b.length, reason: path);
        for (var i = 0; i < a.length; i++) {
          same(a[i], b[i], '$path[$i]');
        }
      } else {
        expect(a, b, reason: path);
      }
    }

    final expected = jsonDecode(File('test/fixtures/fx_plans.json').readAsStringSync()) as Map;
    for (final kind in _kinds) {
      for (var v = 0; v < 6; v++) {
        final plan = fxPlan(kind, 'water', v % 2, const Point(24, 69), const Point(75, 25), v % 3 != 0 ? '🧊' : null, v);
        same(json(plan), expected['$kind/$v'], '$kind/$v');
      }
    }
  });

  group('efetividade na tela (igual ao site)', () {
    const chart = {
      'water': {'fire': 2.0, 'grass': 0.5},
      'electric': {'ground': 0.0, 'water': 2.0},
      'ground': {'electric': 2.0, 'fire': 2.0},
    };
    double typeEff(String t, List<String> types) => types.fold(1.0, (m, d) => m * (chart[t]?[d] ?? 1));
    HitResult hit(BattleMon att, BattleMon def, String slug, bool crit, [int? power, String weather = '']) => (rolls: [[1]], eff: typeEff(slug, def.types));
    BattleMove mv(String slug, [String category = 'special']) => BattleMove(slug, slug, slug, 50, 100, 10, 10, 0, category: category);
    BattleMon mon(List<String> types, [List<BattleMove> moves = const []]) => BattleMon(1, 'X', 50, 100, 50, types, moves);

    test('golpe: super, pouco, não afeta, status', () {
      final fire = mon(['fire']), att = mon(['water']);
      expect(TurnBattle.effectLabel(TurnBattle.moveEffect(hit, att, fire, mv('water'))), 'Super efetivo');
      expect(TurnBattle.effectLabel(TurnBattle.moveEffect(hit, att, mon(['grass']), mv('water'))), 'Pouco efetivo');
      expect(TurnBattle.effectLabel(TurnBattle.moveEffect(hit, att, mon(['ground']), mv('electric'))), 'Não afeta');
      expect(TurnBattle.effectLabel(TurnBattle.moveEffect(hit, att, fire, mv('normal'))), 'Efetivo');
      expect(TurnBattle.moveEffect(hit, att, fire, mv('water', 'status')), isNull);
    });

    test('troca e fraquezas', () {
      final foe = mon(['fire'], [mv('normal')]);
      final m = TurnBattle.switchMatchup(hit, mon(['water'], [mv('water'), mv('normal')]), foe, typeEff);
      expect(m.attack, 2);
      expect(m.defense, 1);
      final w = TurnBattle.weaknesses(['fire'], ['water', 'electric', 'normal', 'ground'], typeEff);
      expect([for (final x in w) '${x.type} ${x.mult}'], ['water 2.0', 'ground 2.0']);
    });
  });

  test('poder do Z-Move e do Max Move (tabelas dos jogos, igual ao site)', () {
    expect([40, 60, 70, 80, 90, 100, 110, 120, 130, 150].map(TurnBattle.zPower), [100, 120, 140, 160, 175, 180, 185, 190, 195, 200]);
    expect([40, 50, 60, 70, 100, 140, 150].map((p) => TurnBattle.maxPower(p, 'fire')), [90, 100, 110, 120, 130, 140, 150]);
    expect([40, 100, 150].map((p) => TurnBattle.maxPower(p, 'fighting')), [70, 90, 100]);
  });
}

const _kinds = ['tackle', 'punch', 'kick', 'bite', 'slash', 'orb', 'beam', 'stream', 'volley', 'bolt', 'quake', 'rocks', 'meteor', 'wave', 'wind', 'rings', 'drain'];
