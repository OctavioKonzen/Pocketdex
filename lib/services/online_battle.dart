import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';

class OnlineBattles {
  static const protocol = 2;
  static const maxRounds = 500;
  static FirebaseFirestore get db => FirebaseFirestore.instance;
  static String get me => AuthService.instance.user!.uid;
  static CollectionReference<Map<String, dynamic>> get rooms => db.collection('onlineBattles');

  static String packTeam(Map<String, dynamic> team) {
    final ids = (team['pokemon'] as List).take(6).toList();
    if (!ids.any((id) => id is num && id > 0)) throw StateError('Escolha um time com Pokémon.');
    final value = jsonEncode({'name': '${team['name'] ?? 'Time'}', 'pokemon': ids, 'sets': ((team['sets'] as List?) ?? []).take(6).toList()});
    if (value.length > 20000) throw StateError('Time muito grande.');
    return value;
  }
  static Map<String, dynamic> unpackTeam(String value) {
    final d = Map<String, dynamic>.from(jsonDecode(value) as Map);
    final ids = d['pokemon'];
    final sets = d['sets'];
    if (ids is! List || ids.length > 6 || !ids.any((id) => id is int && id > 0) ||
        ids.any((id) => id != null && (id is! int || id < 1 || id > 20000)) || sets is! List || sets.length > 6) {
      throw StateError('Time inválido.');
    }
    return d;
  }
  static Future<String> invite(String friendUid, String friendName, Map<String, dynamic> team) async {
    final ref = await rooms.add({
      'protocol': protocol, 'players': [me, friendUid],
      'names': {me: AuthService.instance.user!.name ?? '', friendUid: friendName},
      'teams': {me: packTeam(team)}, 'status': 'pending',
      'seed': Random().nextInt(1 << 31), 'createdAt': FieldValue.serverTimestamp(), 'endedBy': null,
    });
    return ref.id;
  }
  static Future<void> accept(String id, Map<String, dynamic> team) =>
      rooms.doc(id).update({'teams.$me': packTeam(team), 'status': 'active'});
  static Future<void> close(String id) => rooms.doc(id).update({'status': 'closed', 'endedBy': me});
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMine() => rooms.where('players', arrayContains: me).snapshots();
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String id) => rooms.doc(id).snapshots();
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchActions(String id) =>
      rooms.doc(id).collection('actions').limit(maxRounds * 2).snapshots();
  static Future<void> submit(String id, int round, Map<String, dynamic> action) async {
    final ref = rooms.doc(id).collection('actions').doc('${round}_$me');
    await db.runTransaction((tx) async {
      final old = await tx.get(ref);
      if (old.exists) throw StateError('Você já enviou sua ação neste turno.');
      tx.set(ref, {'uid': me, 'round': round, ...action, 'at': FieldValue.serverTimestamp()});
    });
  }
  static List<List<Map<String, dynamic>>> pairs(List<Map<String, dynamic>> actions, List<String> players) {
    final grouped = <int, Map<String, Map<String, dynamic>>>{};
    for (final a in actions) {
      grouped.putIfAbsent((a['round'] as num).toInt(), () => {})[a['uid'] as String] = a;
    }
    final out = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < maxRounds; i++) {
      final row = grouped[i];
      if (row == null || !players.every(row.containsKey)) break;
      out.add([for (final p in players) row[p]!]);
    }
    return out;
  }
}
