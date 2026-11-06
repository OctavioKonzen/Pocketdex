// lib/services/factory_daily.dart
//
// Missões diárias do Pokelike. Igual ao site (web-site/src/lib/factoryDaily.js):
// três por dia, as mesmas para todos (sorteadas pela data de Brasília). O
// progresso sai da diferença entre a corrida salva antes e a de agora
// (saveFactory); cada missão cumprida dá moedas.
//
//   factory['daily'] = {day, p: {tipo: progresso}, done: [tipos], streak}

import 'factory_run.dart';
import 'league.dart';

class DailyMission {
  const DailyMission(this.kind, this.count, this.coins);
  final String kind;
  final int count;
  final int coins;
  /// O texto da missão (no singular quando é uma só).
  String get label => count == 1 ? FactoryDaily.missions[kind]!.one ?? FactoryDaily.missions[kind]!.label : FactoryDaily.missions[kind]!.label;
}

class _Mission {
  const _Mission(this.label, this.counts, this.coins, {this.one});
  final String label;
  final String? one;
  final List<int> counts;
  final int coins;
}

class FactoryDaily {
  static const missions = {
    'defeat': _Mission('Derrote {0} Pokémon', [8, 15], 40),
    'floors': _Mission('Suba {0} andares', [5, 10], 40),
    'boss': _Mission('Vença {0} chefes', [1, 2], 60, one: 'Vença um chefe'),
    'catch': _Mission('Capture {0} Pokémon novos na corrida', [1, 3], 50, one: 'Capture um Pokémon novo na corrida'),
    'noPotion': _Mission('Suba {0} andares seguidos sem usar poção', [3, 5], 70),
  };

  /// As três missões do dia.
  static List<DailyMission> of([String? day]) {
    final random = League.seededRandom(League.seedOf('pocketdex-missions-${day ?? League.dayKey()}'));
    final kinds = missions.keys.toList();
    final out = <DailyMission>[];
    while (out.length < 3) {
      final kind = kinds.removeAt((random() * kinds.length).floor());
      final m = missions[kind]!;
      final big = random() < 0.5;
      out.add(DailyMission(kind, m.counts[big ? 1 : 0], m.coins + (big ? 30 : 0)));
    }
    return out;
  }

  /// O estado de hoje (zerado quando o dia vira).
  static Map<String, dynamic> stateOf(Map? factory, [String? day]) {
    day ??= League.dayKey();
    final daily = factory?['daily'];
    if (daily is Map && daily['day'] == day) return Map<String, dynamic>.from(daily);
    return {'day': day, 'p': <String, dynamic>{}, 'done': <dynamic>[], 'streak': 0};
  }

  static int _n(Object? v) => (v as num?)?.toInt() ?? 0;
  static int _heals(Map? run) => FactoryRun.healTiers.fold(0, (sum, k) => sum + _n((run?['bag'] as Map?)?[k]));
  static int _dex(Map? run) => (run?['dex'] as List?)?.length ?? (run?['starter'] != null ? 1 : 0);

  /// A Factory com o progresso das missões de hoje (e as moedas das cumpridas).
  static Map<String, dynamic> track(Map? prev, Map<String, dynamic> next, [String? day]) {
    day ??= League.dayKey();
    final now = next['run'] as Map?;
    if (now == null) return next;
    final before = prev?['run'] as Map?;
    final same = before != null && _n(now['floor']) >= _n(before['floor']) && _n(now['defeated']) >= _n(before['defeated']) && _n(now['bosses']) >= _n(before['bosses']);
    // Uma corrida nova começa do zero.
    final base = same ? before : {'floor': 1, 'defeated': 0, 'bosses': 0, 'dex': (now['dex'] as List?)?.take(1).toList(), 'starter': now['starter']};
    final d = {
      'defeat': _n(now['defeated']) - _n(base['defeated']),
      'floors': _n(now['floor']) - _n(base['floor']),
      'boss': _n(now['bosses']) - _n(base['bosses']),
      'catch': _dex(now) - _dex(base),
    };
    // Usou poção: a soma das poções na Bolsa caiu (comprar só aumenta).
    final potion = same && _heals(now) < _heals(before);
    final daily = stateOf(next, day);
    final old = Map<String, dynamic>.from(daily['p'] as Map);
    final p = {...old};
    final streak = potion ? 0 : _n(daily['streak']) + d['floors']!;
    final done = [...daily['done'] as List];
    var coins = 0;
    for (final m in of(day)) {
      final value = m.kind == 'noPotion' ? (streak > _n(p[m.kind]) ? streak : _n(p[m.kind])) : _n(p[m.kind]) + (d[m.kind]! > 0 ? d[m.kind]! : 0);
      p[m.kind] = value < m.count ? value : m.count;
      if (_n(p[m.kind]) >= m.count && !done.contains(m.kind)) {
        done.add(m.kind);
        coins += m.coins;
      }
    }
    final changed = coins > 0 || streak != _n(daily['streak']) || of(day).any((m) => _n(p[m.kind]) != _n(old[m.kind])) || (next['daily'] as Map?)?['day'] != day;
    if (!changed) return next;
    // missionsDone: quantas missões já cumpriu no total (medalha "Missão cumprida").
    final fresh = done.length - (daily['done'] as List).length;
    return {
      ...next,
      'coins': _n(next['coins']) + coins,
      'daily': {'day': day, 'p': p, 'done': done, 'streak': streak},
      if (fresh > 0) 'missionsDone': _n(next['missionsDone']) + fresh,
    };
  }
}
