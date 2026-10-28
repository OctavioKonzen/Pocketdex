import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/factory_daily.dart';

const day = '2026-10-28';
Map<String, dynamic> run([Map<String, dynamic> o = const {}]) =>
    {'floor': 1, 'defeated': 0, 'bosses': 0, 'starter': 1, 'dex': [1], 'bag': {'potion': 4}, ...o};

void main() {
  test('Missões diárias: as mesmas do site no mesmo dia', () {
    String show(String d) => [for (final m in FactoryDaily.of(d)) '${m.kind}:${m.count}:${m.coins}'].join(' ');
    expect(show('2026-10-28'), 'noPotion:3:70 floors:5:40 boss:1:60');
    expect(show('2026-10-29'), 'defeat:8:40 boss:2:90 noPotion:3:70');
    expect(show('2026-11-01'), 'noPotion:5:100 boss:1:60 defeat:15:70');
  });

  test('Missões diárias: o progresso paga as moedas uma vez', () {
    final prev = {'coins': 0, 'run': run()};
    final big = run({'floor': 30, 'defeated': 40, 'bosses': 3, 'dex': [1, 2, 3, 4]});
    final next = FactoryDaily.track(prev, {...prev, 'run': big}, day);
    expect(next['coins'], 170);
    expect((FactoryDaily.stateOf(next, day)['done'] as List).length, 3);
    final again = FactoryDaily.track(next, {...next, 'run': {...big, 'floor': 31}}, day);
    expect(again['coins'], 170);
  });

  test('Missões diárias: usar poção zera a sequência', () {
    final prev = {'coins': 0, 'run': run({'floor': 3}), 'daily': {'day': day, 'p': {}, 'done': [], 'streak': 2}};
    final next = FactoryDaily.track(prev, {...prev, 'run': run({'floor': 3, 'bag': {'potion': 3}})}, day);
    expect((next['daily'] as Map)['streak'], 0);
  });
}
