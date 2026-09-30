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
BattleMove _move(String slug, String type, int power, int? accuracy, int pp, [int priority = 0]) =>
    BattleMove(slug, slug, type, power, accuracy, pp, pp, priority);
BattleMon _mon(int id, String name, List<String> types, int hp, int spe, List<BattleMove> moves) =>
    BattleMon(id, name, 50, hp, spe, types, moves);

HitResult? _fakeHit(BattleMon att, BattleMon def, String slug, bool crit) {
  final m = att.moves.where((x) => x.slug == slug).firstOrNull;
  final power = m?.power ?? 50, type = m?.type ?? 'normal';
  final eff = type == 'normal' && def.types.contains('ghost')
      ? 0.0
      : type == 'water' && def.types.contains('fire')
          ? 2.0
          : type == 'grass' && def.types.contains('fire')
              ? 0.5
              : 1.0;
  final roll = [for (var i = 0; i < 16; i++) (power * (85 + i) / 100 * eff * 0.5).floor()];
  return (rolls: slug == 'double-hit' ? [roll, roll] : [roll], eff: eff);
}

List<String> fakeBattleLog() {
  final battle = TurnBattle(
    [
      _mon(1, 'Azul', ['water'], 110, 80, [_move('water-gun', 'water', 60, 100, 3), _move('quick-attack', 'normal', 40, 100, 30, 1), _move('double-hit', 'normal', 35, 90, 10)]),
      _mon(2, 'Verde', ['grass'], 100, 60, [_move('vine-whip', 'grass', 45, 100, 25), _move('tackle', 'normal', 40, 100, 35)]),
    ],
    [
      _mon(3, 'Fogo', ['fire'], 120, 90, [_move('ember', 'fire', 60, 100, 25), _move('scratch', 'normal', 40, 95, 35)]),
      _mon(4, 'Fantasma', ['ghost'], 90, 70, [_move('lick', 'ghost', 50, 100, 30), _move('shadow-sneak', 'ghost', 40, 100, 30, 1)]),
    ],
    League.seededRandom(42),
  );
  final log = <String>[];
  void write(List<BattleEvent> events) {
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
      } else if (e.t == 'heal') {
        log.add('[heal ${e.side} ${e.index} ${e.value}]');
      } else {
        log.add('[${e.t} ${e.side} ${e.value}]');
      }
    }
  }

  for (var turn = 0; turn < 60 && battle.winner == null; turn++) {
    if (battle.needSwitch) {
      write(battle.replace(battle.teams[0].indexWhere((m) => m.hp > 0)));
      continue;
    }
    final me = battle.active(0);
    final usable = TurnBattle.usableMoves(me);
    final fainted = battle.teams[0].indexWhere((m) => m.hp <= 0);
    if (turn == 2 && battle.teams[0][1].hp > 0) {
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
    for (final kind in fxDuration.keys) {
      expect(fxPlan(kind, 'fire', 0, const Point(24, 69), const Point(75, 25)).parts, isNotEmpty, reason: kind);
    }
  });
}
