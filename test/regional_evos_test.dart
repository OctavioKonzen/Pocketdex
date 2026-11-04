import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/factory_run.dart';

void main() {
  final data = FactoryData.parse(jsonDecode(File('assets/database/factory.json').readAsStringSync()) as Map<String, dynamic>);
  Map<String, dynamic> zero() => {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 0};
  Map<String, dynamic> mon(int id, int level, [Map<String, dynamic> extra = const {}]) =>
      {'id': id, 'level': level, 'exp': level * level * level, 'nature': 'Hardy', 'ivs': zero(), 'evs': zero(), ...extra};
  Map<String, dynamic> run(String name) => {'boss': {'region': data.bosses.indexWhere((b) => b['region'] == name), 'step': 0}};
  Map<String, dynamic> withGender(int id, int level, String g) {
    for (var hp = 0; hp < 32; hp++) {
      final m = mon(id, level, {'ivs': {...zero(), 'hp': hp}});
      if (FactoryRun.genderOf(data, m) == g) return m;
    }
    throw StateError('sem gênero $g');
  }

  int at(Map<String, dynamic> m, int lvl, [String? where]) => FactoryRun.levelTo(m, lvl, data, () => 0, where).$1['id'] as int;
  int wild(String where, int id, [String kind = 'wild']) =>
      ((FactoryRun.regionalEncounter(data, run(where), {'kind': kind, 'foes': [{'id': id, 'level': 10}]})['foes'] as List).first as Map)['id'] as int;

  test('formas regionais: os selvagens na forma da região; os chefes, não (igual ao site)', () {
    expect(FactoryRun.regionOf(data, run('Galar')), 'Galar');
    expect(wild('Galar', 52), 10161);
    expect(wild('Alola', 52), 10107);
    expect(wild('Kanto', 52), 52);
    expect(wild('Galar', 52, 'boss'), 52);
    expect(wild('Sinnoh', 215), 10235);
    expect(wild('Paldea', 194, 'trainer'), 10253);
  });

  test('cada forma evolui na dela, onde evoluir (igual ao site)', () {
    expect(at(mon(52, 27), 28, 'Galar'), 53);
    expect(at(mon(10161, 27), 28, 'Kanto'), 863);
    expect(at(mon(562, 33), 34), 563);
    expect(at(mon(10179, 33), 34), 867);
    expect(at(mon(194, 19), 20), 195);
    expect(at(mon(10253, 19), 20), 980);
    expect(at(mon(10091, 19), 20), 10092);
  });

  test('evoluindo na região, vira a forma dela; evoluções só da região (igual ao site)', () {
    expect(FactoryRun.canEvolveWith(data, mon(25, 20), 'thunder-stone', 'Alola'), [10100]);
    expect(FactoryRun.canEvolveWith(data, mon(25, 20), 'thunder-stone', 'Kanto'), [26]);
    expect(FactoryRun.canEvolveWith(data, mon(102, 20), 'leaf-stone', 'Alola'), [10114]);
    expect(at(mon(156, 35), 36, 'Sinnoh'), 10233);
    expect(at(mon(156, 35), 36, 'Johto'), 157);
    expect(at(mon(109, 34), 35, 'Galar'), 10167);
    expect(at(mon(234, 24), 30, 'Sinnoh'), 899);
    expect(at(mon(234, 24), 30, 'Kanto'), 234);
    expect(FactoryRun.canEvolveWith(data, mon(217, 40), 'peat-block', 'Paldea'), [901]);
    expect(FactoryRun.canEvolveWith(data, mon(217, 40), 'peat-block', 'Kanto'), isEmpty);
  });

  test('por gênero: Combee, Burmy, Salandit, Dawn Stone e formas femininas (igual ao site)', () {
    expect(at(withGender(415, 20, 'F'), 21), 416);
    expect(at(withGender(415, 20, 'M'), 21), 415);
    expect(at(withGender(412, 19, 'F'), 20), 413);
    expect(at(withGender(412, 19, 'M'), 20), 414);
    expect(at(withGender(757, 32, 'M'), 40), 757);
    expect(FactoryRun.canEvolveWith(data, withGender(281, 30, 'M'), 'dawn-stone'), [475]);
    expect(FactoryRun.canEvolveWith(data, withGender(281, 30, 'F'), 'dawn-stone'), isEmpty);
    expect(FactoryRun.canEvolveWith(data, withGender(361, 30, 'F'), 'dawn-stone'), [478]);
    expect(at(withGender(677, 24, 'F'), 25), 10025);
    expect(at(withGender(677, 24, 'M'), 25), 678);
    expect(FactoryRun.genderOf(data, mon(81, 10)), isNull);
  });

  test('Tyrogue pelo Ataque e pela Defesa (igual ao site)', () {
    Map<String, dynamic> iv(int atk, int def) => {...zero(), 'atk': atk, 'def': def};
    expect(at(mon(236, 19, {'ivs': iv(31, 0)}), 20), 106);
    expect(at(mon(236, 19, {'ivs': iv(0, 31)}), 20), 107);
    expect(at(mon(236, 19, {'ivs': iv(10, 10)}), 20), 237);
    expect(at(mon(236, 19, {'ivs': iv(10, 10), 'nature': 'Adamant'}), 20), 106);
    expect(data.evolutions[79], [[80, 37], [199, 37]]);
  });
}
