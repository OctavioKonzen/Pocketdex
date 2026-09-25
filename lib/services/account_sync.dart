// lib/services/account_sync.dart
//
// Sincroniza UserData com a conta (users/{uid}.data no Firestore) em tempo
// real e nos dois sentidos — a mesma lógica do site (web-site/src/lib/sync.js):
//   • mudanças da conta (site / outro aparelho) chegam na hora;
//   • mudanças feitas aqui gravam só os campos alterados, para o app e o site
//     não sobrescreverem um ao outro;
//   • o recorde do Ranked vai para o ranking público (ranking/{uid}).

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
    if (keys.contains('rankedRecord')) _updateRanking(uid);
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
        await ref.set({'name': name, 'score': score, 'updatedAt': FieldValue.serverTimestamp()});
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

  // ---------------------------------------------------------------- ranking

  Future<List<Map<String, dynamic>>> topRanking([int count = 10]) async {
    final snap = await _db.collection('ranking').orderBy('score', descending: true).limit(count).get();
    return [
      for (final d in snap.docs) {'uid': d.id, 'name': d.data()['name'], 'score': d.data()['score']},
    ];
  }

  Future<int> rankingPosition(int score) async {
    final snap = await _db.collection('ranking').where('score', isGreaterThan: score).count().get();
    return (snap.count ?? 0) + 1;
  }
}
