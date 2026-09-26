// lib/services/account_sync.dart
//
// Sincroniza UserData com a conta (users/{uid}.data no Firestore) em tempo
// real e nos dois sentidos — a mesma lógica do site (web-site/src/lib/sync.js):
//   • mudanças da conta (site / outro aparelho) chegam na hora;
//   • mudanças feitas aqui gravam só os campos alterados, para o app e o site
//     não sobrescreverem um ao outro;
//   • o recorde do Ranked vai para o ranking público (ranking/{uid}), com a
//     foto de perfil; o melhor da semana vai para weekly/{segunda}/scores/{uid}
//     e o desafio do dia para daily/{dia}/scores/{uid}.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/profanity.dart';
import 'auth_service.dart';
import 'user_data.dart';

class AccountSync {
  AccountSync._();
  static final AccountSync instance = AccountSync._();

  final _data = UserData.instance;
  final _auth = AuthService.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String? _uid;
  StreamSubscription? _remote;
  Timer? _timer;
  final Set<String> _dirty = {};
  bool _ready = false;

  /// Muda sempre que o ranking é atualizado (a tela do jogo recarrega).
  final rankingVersion = ValueNotifier<int>(0);

  /// Muda quando os times públicos da pessoa são atualizados.
  final teamsVersion = ValueNotifier<int>(0);
  Timer? _publishTimer;

  void start() {
    _data.onLocalChange = _onLocalChange;
    _auth.addListener(_onAuth);
    _onAuth();
  }

  void _onAuth() {
    final uid = _auth.status == AuthStatus.signedIn ? _auth.user?.uid : null;
    if (uid == _uid) return;
    final wasSignedIn = _uid != null;
    _stop();
    _uid = uid;
    if (uid != null) {
      _listen(uid);
    } else if (wasSignedIn) {
      // Saiu da conta: os dados dela não ficam no aparelho.
      _data.clearAll();
    }
  }

  void _stop() {
    _remote?.cancel();
    _remote = null;
    _timer?.cancel();
    _timer = null;
    _publishTimer?.cancel();
    _publishTimer = null;
    _dirty.clear();
    _ready = false;
  }

  void _listen(String uid) {
    _remote = _db.collection('users').doc(uid).snapshots().listen((snap) {
      // Ignora o "eco" das gravações feitas por este aparelho.
      if (snap.metadata.hasPendingWrites || _uid != uid) return;
      final remote = snap.data()?['data'];
      if (remote is Map) {
        // O que foi mudado aqui e ainda não foi gravado tem preferência.
        _data.applyRemote(Map<String, dynamic>.from(remote), except: _dirty);
      } else {
        // Conta nova: o que já estava no aparelho vai para ela.
        _dirty.addAll(UserData.keys);
      }
      if (!_ready) {
        _ready = true;
        _updateRanking(uid);
        _schedulePublish(uid);
      }
      if (_dirty.isNotEmpty) _scheduleSave();
    }, onError: (_) {});
  }

  void _onLocalChange(Set<String> keys) {
    final uid = _uid;
    if (uid == null) return;
    _dirty.addAll(keys);
    if (!_ready) return; // grava depois de receber a conta
    if (keys.contains('rankedRecord') || keys.contains('avatar')) _updateRanking(uid);
    if (keys.contains('teams') || keys.contains('avatar')) _schedulePublish(uid);
    _scheduleSave();
  }

  void _scheduleSave() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), flush);
  }

  /// Grava na hora o que estiver esperando (ex.: antes de sair da conta).
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final uid = _uid;
    if (uid == null || _dirty.isEmpty) return;
    final changes = _data.snapshot(_dirty.toList());
    _dirty.clear();
    try {
      await _db.collection('users').doc(uid).set(
        {'data': changes, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      _dirty.addAll(changes.keys); // tenta de novo na próxima mudança
    }
  }

  Future<void> _updateRanking(String uid) async {
    final name = _auth.user?.name;
    if (name == null) return;
    final ref = _db.collection('ranking').doc(uid);
    final score = _data.rankedRecord;
    try {
      if (score > 0) {
        await ref.set({'name': name, 'score': score, 'avatar': _data.avatar, 'updatedAt': FieldValue.serverTimestamp()});
      } else {
        await ref.delete();
      }
      rankingVersion.value++;
    } catch (_) {}
  }

  /// Sai da conta, salvando antes o que faltava.
  Future<void> logout() async {
    await flush();
    await _auth.signOut();
  }

  /// Para a sincronização (enquanto a conta é excluída, para não recriar os dados).
  void pause() {
    _stop();
    _uid = null;
  }

  /// Volta a sincronizar a conta conectada (se a exclusão não foi até o fim).
  void resume() {
    _uid = null;
    _onAuth();
  }

  // ---------------------------------------------------------------- ranking
  //   board: 'all' (geral), 'week' (semana) ou 'day' (desafio do dia)

  CollectionReference<Map<String, dynamic>> _board(String board, String key) => switch (board) {
        'week' => _db.collection('weekly').doc(key).collection('scores'),
        'day' => _db.collection('daily').doc(key).collection('scores'),
        _ => _db.collection('ranking'),
      };

  Future<List<Map<String, dynamic>>> topRanking([int count = 10, String board = 'all', String key = '']) async {
    final snap = await _board(board, key).orderBy('score', descending: true).limit(count).get();
    return [
      for (final d in snap.docs) {'uid': d.id, ...d.data()},
    ];
  }

  /// O ranking em tempo real: uma lista nova sempre que alguém faz pontos.
  Stream<List<Map<String, dynamic>>> watchRanking([int count = 10, String board = 'all', String key = '']) =>
      _board(board, key).orderBy('score', descending: true).limit(count).snapshots().map(
            (snap) => [for (final d in snap.docs) {'uid': d.id, ...d.data()}],
          );

  Future<int> rankingPosition(int score, [String board = 'all', String key = '']) async {
    final snap = await _board(board, key).where('score', isGreaterThan: score).count().get();
    return (snap.count ?? 0) + 1;
  }

  /// A linha da pessoa num ranking (ou null).
  Future<Map<String, dynamic>?> myScore(String board, String key) async {
    final uid = _uid;
    if (uid == null) return null;
    if (board == 'all') return _data.rankedRecord > 0 ? {'score': _data.rankedRecord} : null;
    return (await _board(board, key).doc(uid).get()).data();
  }

  /// Guarda a pontuação da semana, se for maior que a já guardada.
  Future<void> saveWeekly(String week, int score) async {
    final uid = _uid, name = _auth.user?.name;
    if (uid == null || name == null || score <= 0) return;
    try {
      final ref = _board('week', week).doc(uid);
      final current = await ref.get();
      if (current.exists && ((current.data()?['score'] as num?) ?? 0) >= score) return;
      await ref.set({'name': name, 'score': score, 'avatar': _data.avatar, 'updatedAt': FieldValue.serverTimestamp()});
      rankingVersion.value++;
    } catch (_) {}
  }

  /// Resultado do desafio do dia (uma vez só por dia).
  Future<void> saveDaily(String day, {required int score, required int correct, required int seconds}) async {
    final uid = _uid, name = _auth.user?.name;
    if (uid == null || name == null || score <= 0) return;
    try {
      await _board('day', day).doc(uid).set({
        'name': name,
        'score': score,
        'correct': correct,
        'seconds': seconds,
        'avatar': _data.avatar,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      rankingVersion.value++;
    } catch (_) {}
  }

  // ---------------------------------------------------------------- times públicos
  //   publicTeams/{teamId} → {ownerUid, ownerName, ownerKey, avatar, name, color,
  //                           pokemon: [id|null x6], ratingSum, ratingCount}
  //   publicTeams/{teamId}/ratings/{uid} → {stars: 1..5}
  // Igual ao site (web-site/src/lib/auth.js): os times de quem tem conta
  // aparecem para todos; se o dono excluir o time, ele some da lista.

  CollectionReference<Map<String, dynamic>> get _public => _db.collection('publicTeams');

  void _schedulePublish(String uid) {
    _publishTimer?.cancel();
    _publishTimer = Timer(const Duration(milliseconds: 1500), () => publishTeams(uid));
  }

  /// Deixa os times públicos iguais aos times da conta (a nota da comunidade fica).
  Future<void> publishTeams(String uid) async {
    final name = _auth.user?.name;
    if (name == null || _uid != uid) return;
    try {
      final snap = await _public.where('ownerUid', isEqualTo: uid).get();
      final current = {for (final d in snap.docs) d.id: d.data()};
      final batch = _db.batch();
      var changes = 0;
      final wanted = <String>{};
      for (final team in _data.teams) {
        final slots = (team['pokemon'] as List?) ?? [];
        final pokemon = [for (var i = 0; i < 6; i++) i < slots.length ? (slots[i] as num?)?.toInt() : null];
        if (pokemon.every((p) => p == null)) continue; // time vazio não aparece
        if (isOffensive('${team['name'] ?? ''}')) continue; // nome com palavrão não aparece para os outros
        final id = team['id'] as String;
        wanted.add(id);
        final fields = <String, dynamic>{
          'ownerUid': uid,
          'ownerName': name,
          'ownerKey': AuthService.nameKey(name),
          'avatar': _data.avatar,
          'name': team['name'] ?? 'Time',
          'color': team['color'],
          'pokemon': pokemon,
        };
        final old = current[id];
        final same = old != null && fields.entries.every((e) => '${old[e.key]}' == '${e.value}');
        if (same) continue;
        batch.set(_public.doc(id), {
          ...fields,
          'ratingSum': old?['ratingSum'] ?? 0,
          'ratingCount': old?['ratingCount'] ?? 0,
          'reportCount': old?['reportCount'] ?? 0,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        changes++;
      }
      for (final id in current.keys) {
        if (!wanted.contains(id)) {
          batch.delete(_public.doc(id));
          changes++;
        }
      }
      if (changes > 0) await batch.commit();
      teamsVersion.value++;
    } catch (_) {}
  }

  static Map<String, dynamic> _publicTeam(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data()!;
    final count = (data['ratingCount'] as num?)?.toInt() ?? 0;
    final sum = (data['ratingSum'] as num?)?.toInt() ?? 0;
    return {'id': d.id, ...data, 'rating': count > 0 ? sum / count : null, 'ratingCount': count};
  }

  /// Times com 3 ou mais denúncias somem da busca (o dono ainda vê os seus).
  static const reportLimit = 3;

  /// Denuncia um time (uma vez por pessoa); a contagem do time sobe junto.
  Future<void> reportTeam(String teamId, String reason) async {
    final uid = _uid;
    if (uid == null) throw StateError('Entre na sua conta para denunciar.');
    final teamRef = _public.doc(teamId);
    final reportRef = teamRef.collection('reports').doc(uid);
    await _db.runTransaction((tx) async {
      final team = await tx.get(teamRef);
      if (!team.exists) throw StateError('Esse time foi excluído pelo dono.');
      final already = await tx.get(reportRef);
      if (already.exists) throw StateError('Você já denunciou esse time.');
      tx.set(reportRef, {'reason': reason, 'createdAt': FieldValue.serverTimestamp()});
      tx.update(teamRef, {'reportCount': ((team.data()!['reportCount'] as num?)?.toInt() ?? 0) + 1});
    });
  }

  /// Times públicos de uma pessoa (pelo nome) ou os mais recentes.
  Future<List<Map<String, dynamic>>> searchPublicTeams(String name) async {
    final key = AuthService.nameKey(name);
    final query = key.isEmpty
        ? _public.orderBy('updatedAt', descending: true).limit(30)
        : _public.where('ownerKey', isEqualTo: key).limit(50);
    final snap = await query.get();
    return snap.docs
        .map(_publicTeam)
        .where((t) => ((t['reportCount'] as num?) ?? 0) < reportLimit || t['ownerUid'] == _uid)
        .toList();
  }

  /// Nota da comunidade dos times da pessoa: {teamId: (nota, votos)}.
  Future<Map<String, (double?, int)>> myTeamRatings() async {
    final uid = _uid;
    if (uid == null) return {};
    final snap = await _public.where('ownerUid', isEqualTo: uid).get();
    return {
      for (final d in snap.docs) d.id: (_publicTeam(d)['rating'] as double?, _publicTeam(d)['ratingCount'] as int),
    };
  }

  /// Um time público (ou null, se o dono excluiu).
  Future<Map<String, dynamic>?> publicTeam(String id) async {
    final snap = await _public.doc(id).get();
    return snap.exists ? _publicTeam(snap) : null;
  }

  /// O voto da pessoa num time (1 a 5) ou null.
  Future<int?> myVote(String teamId) async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _public.doc(teamId).collection('ratings').doc(uid).get();
    return (snap.data()?['stars'] as num?)?.toInt();
  }

  /// Vota (ou muda o voto) num time; devolve a nova nota e os votos.
  Future<(double, int)> rateTeam(String teamId, int stars) async {
    final uid = _uid;
    if (uid == null) throw StateError('Entre na sua conta para votar.');
    final teamRef = _public.doc(teamId);
    final voteRef = teamRef.collection('ratings').doc(uid);
    return _db.runTransaction((tx) async {
      final team = await tx.get(teamRef);
      if (!team.exists) throw StateError('Esse time foi excluído pelo dono.');
      final vote = await tx.get(voteRef);
      final old = (vote.data()?['stars'] as num?)?.toInt() ?? 0;
      final sum = ((team.data()!['ratingSum'] as num?)?.toInt() ?? 0) + stars - old;
      final count = ((team.data()!['ratingCount'] as num?)?.toInt() ?? 0) + (vote.exists ? 0 : 1);
      tx.set(voteRef, {'stars': stars});
      tx.update(teamRef, {'ratingSum': sum, 'ratingCount': count});
      return (sum / count, count);
    });
  }
}
