// lib/services/raid.dart
//
// Raid da semana: um chefe gigante (Dynamax ou Tera) por semana, com uma barra
// de vida enorme dividida entre você e seus amigos. Cada um luta com ele até
// [Raid.triesPerDay] vezes por dia; o dano de cada luta (quanto da vida dele
// tirou) soma na conta (raids/{semana}/hits/{uid}). Quando o total do grupo
// (você e seus amigos) chega à barra, cada um pega o prêmio uma vez. Igual ao
// site (web-site/src/lib/raid.js).

import 'package:cloud_firestore/cloud_firestore.dart';

import 'league.dart';
import 'turn_battle.dart';
import 'team_battle.dart';

class Raid {
  Raid._();

  /// A barra do grupo (em % da vida do chefe): 15 chefes derrubados.
  static const pool = 1500;
  static const triesPerDay = 3;

  /// O prêmio (moedas do Pokelike) quando o grupo derruba o chefe.
  static const coins = 400;

  /// O máximo que uma luta conta (a vida inteira dele).
  static const maxHit = 100;

  /// Os chefes que se revezam (fortes, com Dynamax ou Tera).
  static const bosses = [6, 130, 143, 94, 149, 248, 445, 131, 9, 373, 376, 3, 609, 635, 887, 1000, 25, 448];

  static int _hash(String s) {
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h = ((h ^ c) * 16777619) & 0xFFFFFFFF;
    }
    return h;
  }

  /// O chefe da semana (o mesmo para todo mundo).
  static int bossOf([String? week]) => bosses[_hash(week ?? League.weekKey()) % bosses.length];

  /// Dynamax ou Tera (alternando com as semanas).
  static String gimmickOf([String? week]) => _hash('g${week ?? League.weekKey()}').isEven ? 'dmax' : 'tera';

  /// O chefe como adversário: nível 75, perfeito e com +50% em tudo.
  static Member member([String? week]) => (
        bossOf(week),
        {
          'level': 75, 'levelCap': 'none', 'gimmick': gimmickOf(week),
          'ivs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 31},
          'evs': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 84},
          'boost': {for (final s in ['hp', 'atk', 'def', 'spa', 'spd', 'spe']) s: 0.5},
        },
      );

  /// Quanto a luta tirou da vida do chefe (0 a 100).
  static int damageOf(TurnBattle b) {
    final boss = b.teams[1].first;
    if (boss.maxHp <= 0) return 0;
    return ((boss.maxHp - boss.hp.clamp(0, boss.maxHp)) * 100 / boss.maxHp).round().clamp(0, maxHit);
  }

  // ------------------------------------------------------------ na Factory (as tentativas e o prêmio)
  static Map<String, dynamic> stateOf(Map? factory, [String? week]) {
    final s = (factory?['raid'] as Map?) ?? const {};
    return s['week'] == (week ?? League.weekKey()) ? Map<String, dynamic>.from(s) : {'week': week ?? League.weekKey()};
  }

  /// Quantas lutas ainda dá hoje.
  static int triesLeft(Map? factory, [String? week, String? day]) {
    final s = stateOf(factory, week);
    final used = s['day'] == (day ?? League.dayKey()) ? ((s['tries'] as num?) ?? 0).toInt() : 0;
    return triesPerDay - used;
  }

  /// A Factory depois de uma luta (gasta uma tentativa e soma o seu dano).
  static Map<String, dynamic> afterFight(Map<String, dynamic> factory, int damage, [String? week, String? day]) {
    day ??= League.dayKey();
    final s = stateOf(factory, week);
    final used = s['day'] == day ? ((s['tries'] as num?) ?? 0).toInt() : 0;
    return {...factory, 'raid': {...s, 'day': day, 'tries': used + 1, 'mine': ((s['mine'] as num?) ?? 0).toInt() + damage}};
  }

  static bool claimed(Map? factory, [String? week]) => stateOf(factory, week)['claimed'] == true;

  /// Pega o prêmio (uma vez por semana), se o grupo já derrubou o chefe.
  static Map<String, dynamic> claim(Map<String, dynamic> factory, int groupTotal, [String? week]) {
    if (groupTotal < pool || claimed(factory, week)) return factory;
    return {...factory, 'coins': ((factory['coins'] as num?) ?? 0).toInt() + coins, 'raid': {...stateOf(factory, week), 'claimed': true}};
  }

  // ------------------------------------------------------------ na conta (o dano de cada um)
  static DocumentReference<Map<String, dynamic>> _hit(String week, String uid) =>
      FirebaseFirestore.instance.collection('raids').doc(week).collection('hits').doc(uid);

  /// Soma o dano da luta na conta (o grupo vê).
  static Future<void> addHit(String uid, String name, int damage, [String? week]) => _hit(week ?? League.weekKey(), uid).set(
        {'dmg': FieldValue.increment(damage.clamp(0, maxHit)), 'name': name, 'at': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

  /// O dano de cada um do grupo nesta semana ({uid: dano}).
  static Future<Map<String, int>> hits(List<String> uids, [String? week]) async {
    final w = week ?? League.weekKey();
    final out = <String, int>{};
    await Future.wait([
      for (final uid in uids.toSet())
        _hit(w, uid).get().then((d) {
          final v = (d.data()?['dmg'] as num?)?.toInt() ?? 0;
          if (v > 0) out[uid] = v;
        }).catchError((_) {}),
    ]);
    return out;
  }
}
