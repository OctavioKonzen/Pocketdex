// lib/services/battle_log.dart
//
// Histórico e replays das batalhas contra o computador (igual ao site,
// web-site/src/lib/battleLog.js). Cada batalha guarda só a semente, os times
// ({id, set}) e as suas jogadas: o motor é determinístico, então o replay
// refaz a batalha inteira igual. Fica nos dados da conta ('battles').

import 'dart:math';

import 'team_battle.dart' show Member;
import 'turn_battle.dart';
import 'user_data.dart';

class BattleLog {
  BattleLog._();

  static const maxBattles = 30;

  /// O registro de uma batalha que acabou.
  static Map<String, dynamic> record(TurnBattle battle, {String foeName = '', String? foeTrainer, DateTime? now}) {
    final at = (now ?? DateTime.now()).millisecondsSinceEpoch;
    return {
      'id': '${at.toRadixString(36)}${Random().nextInt(1000000).toRadixString(36)}',
      'at': at,
      'result': battle.winner == 0 ? 'win' : 'loss',
      'foe': foeName,
      'foeTrainer': foeTrainer,
      'turns': battle.turn,
      'ai': battle.ai,
      'seed': battle.seed,
      'mine': battle.members!.mine,
      'theirs': battle.members!.theirs,
      'actions': battle.actions,
      'kos': {for (final e in battle.kos.entries) '${e.key}': e.value},
      'left': [for (final team in battle.teams) team.where((m) => m.hp > 0).length],
    };
  }

  /// Guarda no histórico (as mais novas primeiro, até [maxBattles]).
  static void add(Map<String, dynamic> record) {
    UserData.instance.update({'battles': [record, ...UserData.instance.battles].take(maxBattles).toList()});
  }

  static void delete(String id) {
    UserData.instance.update({'battles': [for (final b in UserData.instance.battles) if (b['id'] != id) b]});
  }

  /// Dá para refazer (tem semente e os times)?
  static bool canReplay(Map<String, dynamic> r) => r['seed'] != null && (r['mine'] as List?)?.isNotEmpty == true && (r['theirs'] as List?)?.isNotEmpty == true;

  /// Vitórias, batalhas e, por Pokémon, quantas batalhas, vitórias e derrubados.
  static ({int battles, int wins, int rate, List<({int id, int battles, int wins, int kos})> mons}) stats(List<Map<String, dynamic>> records) {
    final byMon = <int, ({int id, int battles, int wins, int kos})>{};
    var wins = 0;
    for (final r in records) {
      final won = r['result'] == 'win';
      if (won) wins++;
      final mine = (r['mine'] as List? ?? const []);
      for (var i = 0; i < mine.length; i++) {
        final id = ((mine[i] as Map)['id'] as num).toInt();
        final s = byMon[id] ?? (id: id, battles: 0, wins: 0, kos: 0);
        final kos = ((r['kos'] as Map?)?['$i'] as num?)?.toInt() ?? 0;
        byMon[id] = (id: id, battles: s.battles + 1, wins: s.wins + (won ? 1 : 0), kos: s.kos + kos);
      }
    }
    final mons = byMon.values.toList()
      ..sort((a, b) => b.kos != a.kos ? b.kos - a.kos : b.wins != a.wins ? b.wins - a.wins : b.battles - a.battles);
    return (battles: records.length, wins: wins, rate: records.isEmpty ? 0 : (wins * 100 / records.length).round(), mons: mons);
  }

  /// O time do registro no formato do motor (id, set).
  static List<Member> members(List<dynamic> list) => [
        for (final m in list) (((m as Map)['id'] as num).toInt(), (m['set'] as Map?)?.cast<String, dynamic>()),
      ];

  /// O time no formato do registro ({id, set}).
  static List<Map<String, dynamic>> toRecord(List<Member> list) => [
        for (final m in list) {'id': m.$1, 'set': m.$2},
      ];
}
