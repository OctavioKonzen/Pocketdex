import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/factory_run.dart';

void main() {
  final data = FactoryData.parse(jsonDecode(File('assets/database/factory.json').readAsStringSync()) as Map<String, dynamic>);
  Map<String, dynamic> base() => FactoryRun.startRun(FactoryRun.empty(), data, 1, 42)!;

  test('troca de itens da árvore: 3 de um por 1 de outro (igual ao site)', () {
    final f = {...FactoryRun.empty(), 'pieces': {'key-stone': 4}};
    expect(FactoryRun.tradePieces(f, 'key-stone', 'relic-crown')!['pieces'], {'key-stone': 1, 'sparkling-stone': 0, 'comet-shard': 0, 'relic-crown': 1});
    expect(FactoryRun.tradePieces({...f, 'pieces': {'key-stone': 2}}, 'key-stone', 'relic-crown'), isNull);
    expect(FactoryRun.tradePieces(f, 'key-stone', 'key-stone'), isNull);
  });

  test('captura: a tela vê antes quem entra e é o mesmo que entra (igual ao site)', () {
    final run = {...base(), 'pending': {'capture': {'id': 415, 'level': 10}}};
    final preview = FactoryRun.capturedMon(run)!;
    final after = FactoryRun.capture(run);
    expect(FactoryRun.teamOf(after).last, preview);
    expect(['M', 'F'], contains(FactoryRun.genderOf(data, preview)));
  });

  test('modos: monotipo, sem itens e formas regionais (igual ao site)', () {
    final mono = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42, modes: {'mono'})!;
    expect(mono['mono'], ['grass', 'poison']);
    expect(FactoryRun.captureFor({...mono, 'encounter': {'kind': 'wild', 'foes': [{'id': 16}]}}, data), isNull);
    expect(FactoryRun.captureFor({...mono, 'encounter': {'kind': 'wild', 'foes': [{'id': 43}]}}, data), isNotNull);
    final empty = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42, modes: {'noItems'})!;
    expect((empty['bag'] as Map).values.every((n) => n == 0), isTrue);
    final regional = FactoryRun.startRun(FactoryRun.empty(), data, 1, 42, modes: {'regionalAll'})!;
    final kanto = {...regional, 'boss': {'region': data.bosses.indexWhere((b) => b['region'] == 'Kanto'), 'step': 0}};
    int wild(int id) => ((FactoryRun.regionalEncounter(data, kanto, {'kind': 'wild', 'foes': [{'id': id, 'level': 9}]})['foes'] as List).first as Map)['id'] as int;
    expect(wild(52), 10107);
    expect(wild(194), 10253);
  });

  test('histórico: as últimas 10 corridas, a mais nova primeiro (igual ao site)', () {
    var f = FactoryRun.empty();
    for (var i = 2; i <= 13; i++) {
      f = FactoryRun.endRun(f, {...base(), 'floor': i, 'nuzlocke': i == 13});
    }
    final history = f['history'] as List;
    expect(history, hasLength(10));
    expect((history.first as Map)['floor'], 12);
    expect((history.first as Map)['modes'], ['nuzlocke']);
    final one = FactoryRun.addToHistory([], {...base(), 'floor': 5, 'mono': ['grass']}, 10, '2026-01-01').first;
    expect([one['date'], one['floor'], one['coins'], one['modes']], ['2026-01-01', 4, 10, ['mono']]);
  });

  test('conquistas novas: Shedinja, os três Hitmon e 5 formas regionais (igual ao site)', () {
    final run = {...base(), 'team': [...FactoryRun.teamOf(base()), {...FactoryRun.teamOf(base()).first, 'id': 292}]};
    final (f, _) = FactoryRun.progress({...FactoryRun.empty(), 'caught': [106, 107, 237, 10091, 10107, 10161, 10229, 10253]}, run);
    expect(f['achievements'], containsAll(['shedinja', 'hitmons', 'regional5']));
  });

  test('Pokédex: a forma regional marca também a espécie (igual ao site)', () {
    final f = FactoryRun.withSeen({...FactoryRun.empty(), 'run': {...base(), 'team': [{'id': 10161}], 'encounter': {'foes': [{'id': 10107}]}}}, data);
    expect(f['caught'], containsAll([10161, 52]));
    expect(f['seen'], containsAll([10107, 52]));
  });
}
