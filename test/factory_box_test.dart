import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/factory_run.dart';

void main() {
  final data = FactoryData.parse(jsonDecode(File('assets/database/factory.json').readAsStringSync()) as Map<String, dynamic>);

  test('PC: no fim da corrida o time vai para o PC, com quem saiu do time (igual ao site)', () {
    var run = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;
    final team = FactoryRun.teamOf(run);
    run = {...run, 'team': [...team, for (var i = 0; i < 5; i++) {...team.first, 'id': 10 + i}]};
    run = {...run, 'pending': {'capture': {'id': 415, 'level': 9}}};
    final caught = FactoryRun.capture(run, 2);
    expect([for (final m in caught['pc'] as List) m['id']], [11]);
    final after = FactoryRun.endRun(FactoryRun.empty(), caught);
    final box = after['box'] as List;
    expect([for (final b in box) b['id']], [1, 10, 415, 12, 13, 14, 11]);
    expect((box.first as Map).keys.toSet().containsAll({'id', 'level', 'nature', 'ivs', 'evs', 'moves', 'date'}), isTrue);
  });

  test('PC: cabe 300, solta e vira membro de time', () {
    final many = FactoryRun.addToBox(null, [for (var i = 0; i < 310; i++) {'id': 1 + i % 5, 'level': 5}], '2026-11-04');
    expect(many.length, FactoryRun.boxSize);
    final f = {...FactoryRun.empty(), 'box': many.take(2).toList()};
    expect((FactoryRun.releaseFromBox(f, 0)['box'] as List).length, 1);
    final set = FactoryRun.boxToSet({'id': 25, 'level': 140, 'nature': 'Timid', 'shiny': true, 'ivs': {'spe': 31}, 'evs': {'spe': 400}, 'moves': []}, ['thunderbolt', 'quick-attack']);
    expect(set['level'], 100);
    expect(set['moves'], ['thunderbolt', 'quick-attack', '', '']);
    expect((set['evs'] as Map)['spe'], 252);
    expect(set['shiny'], true);
    expect(set['nature'], 'Timid');
  });

  double Function() lcg(int seed) {
    var x = seed;
    return () => (x = (x * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff;
  }

  test('caça shiny: a chance do escolhido sobe com os encontros e zera quando acha (igual ao site)', () {
    expect(FactoryRun.huntMultOf(0), 1);
    expect(FactoryRun.huntMultOf(25), 3);
    expect(FactoryRun.huntMultOf(999), FactoryRun.huntMax);
    // A caça é pela linha: escolher o Charizard caça o Charmander.
    final f = FactoryRun.setHunt(FactoryRun.empty(), data, 6);
    expect(f['hunt'], {'id': 4, 'count': 0, 'found': 0});
    final run = FactoryRun.startRun({...f, 'hunt': {'id': 4, 'count': 37}}, data, 1, 42)!;
    expect(run['hunt'], 4);
    expect(FactoryRun.huntNode(run), {'hunt': 4, 'huntMult': 4});
    // O mesmo encontro, com a caça no escolhido dele: vem shiny.
    final plain = FactoryRun.encounterFor(data, 5, lcg(7), null, false, {'kind': 'wild', 'biome': 'grass'});
    final id = ((plain['foes'] as List).first as Map)['id'] as int;
    final hunted = FactoryRun.encounterFor(data, 5, lcg(7), null, false, {'kind': 'wild', 'biome': 'grass', 'hunt': FactoryRun.huntBase(data, id), 'huntMult': 4096});
    expect(((hunted['foes'] as List).first as Map)['shiny'], true);
    expect(((hunted['foes'] as List).first as Map)['id'], id);
    // No fim: soma os encontros; achou o shiny, zera e conta.
    final hf = {...FactoryRun.empty(), 'hunt': {'id': 4, 'count': 37, 'found': 0}};
    expect(FactoryRun.huntAfter(hf, {'hunt': 4, 'huntSeen': 5}), {'id': 4, 'count': 42, 'found': 0});
    expect(FactoryRun.huntAfter(hf, {'hunt': 4, 'huntSeen': 5, 'huntFound': true}), {'id': 4, 'count': 0, 'found': 1});
  });
}
