import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/run_guard.dart';
import 'package:pocket_dex/services/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Map<String, dynamic> league(Object? run) => {'factory': {'coins': 0, 'run': run}};

  test('a corrida mudou em outro aparelho (igual ao site)', () {
    expect(RunGuard.changed(league({'floor': 3}), league({'floor': 5})), isTrue);
    // Acabou lá.
    expect(RunGuard.changed(league({'floor': 3}), league(null)), isTrue);
    // Sem corrida aqui, ou a mesma corrida: não avisa.
    expect(RunGuard.changed(league(null), league({'floor': 1})), isFalse);
    expect(RunGuard.changed(null, league({'floor': 1})), isFalse);
    expect(RunGuard.changed(league({'floor': 3}), {...league({'floor': 3}), 'gym': 1}), isFalse);
    // A conta devolve os campos em outra ordem: não é outra corrida.
    expect(RunGuard.changed(league({'floor': 1, 'bag': {'poke-ball': 5, 'potion': 4}, 'foes': [{'id': 1, 'level': 3}]}),
        league({'foes': [{'level': 3, 'id': 1}], 'bag': {'potion': 4, 'poke-ball': 5}, 'floor': 1})), isFalse);
  });

  test('a conta trouxe outra corrida: avisa depois de aplicar', () async {
    SharedPreferences.setMockInitialValues({});
    await UserData.instance.load();
    UserData.instance.update({'league': {...UserData.instance.league, ...league({'floor': 3})}});
    final before = RunGuard.takeovers.value;
    Object? seen;
    void listener() => seen = (UserData.instance.league['factory'] as Map)['run'];
    RunGuard.takeovers.addListener(listener);
    UserData.instance.applyRemote({'league': {...UserData.instance.league, ...league({'floor': 7})}});
    RunGuard.takeovers.removeListener(listener);
    expect(RunGuard.takeovers.value, before + 1);
    // Quem ouve o aviso já vê a corrida nova.
    expect(seen, {'floor': 7});
    // A mesma corrida de novo: nada.
    UserData.instance.applyRemote({'league': {...UserData.instance.league, 'gym': 2}});
    expect(RunGuard.takeovers.value, before + 1);
  });
}
