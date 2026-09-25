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
}
