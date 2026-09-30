// lib/services/friends_service.dart
//
// Amigos da conta (os mesmos do site, web-site/src/lib/friends.js):
//   friends/{uid}/list/{outro} → {name, avatar, status, since, challenge?}
//   status: 'sent' (pedido enviado) | 'received' (pedido recebido) | 'friends'
// Quem pede grava dos dois lados; quem recebe aceita; qualquer um desfaz.
// Amigos podem deixar um desafio (código do jogo) um para o outro.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'user_data.dart';

class Friend {
  final String uid;
  final String name;
  final int? avatar;
  final String status;
  final Map<String, dynamic>? challenge;
  const Friend(this.uid, this.name, this.avatar, this.status, this.challenge);

  factory Friend.fromDoc(String uid, Map<String, dynamic> d) => Friend(
        uid,
        d['name'] as String? ?? '',
        (d['avatar'] as num?)?.toInt(),
        d['status'] as String? ?? 'sent',
        d['challenge'] is Map ? Map<String, dynamic>.from(d['challenge'] as Map) : null,
      );

  bool get isFriend => status == 'friends';
  bool get hasChallenge => isFriend && (challenge?['code'] as String?)?.isNotEmpty == true;
}

class FriendsService extends ChangeNotifier {
  FriendsService._();
  static final FriendsService instance = FriendsService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  final _auth = AuthService.instance;
  StreamSubscription? _sub;
  String? _uid;
  List<Friend> list = [];
  bool ready = false;

  List<Friend> get friends => list.where((f) => f.isFriend).toList();
  List<Friend> get incoming => list.where((f) => f.status == 'received').toList();
  List<Friend> get outgoing => list.where((f) => f.status == 'sent').toList();
  List<Friend> get challenges => list.where((f) => f.hasChallenge).toList();

  /// Pedidos recebidos + desafios esperando (o aviso no avatar).
  int get pending => incoming.length + challenges.length;

  void start() {
    _auth.addListener(_onAuth);
    _onAuth();
  }

  void _onAuth() {
    final uid = _auth.status == AuthStatus.signedIn ? _auth.user?.uid : null;
    if (uid == _uid) return;
    _uid = uid;
    _sub?.cancel();
    _sub = null;
    list = [];
    ready = false;
    notifyListeners();
    if (uid == null) return;
    _sub = _db.collection('friends').doc(uid).collection('list').snapshots().listen((snap) {
      list = [for (final d in snap.docs) Friend.fromDoc(d.id, d.data())];
      ready = true;
      notifyListeners();
    }, onError: (_) {
      ready = true;
      notifyListeners();
    });
  }

  String get _me => _auth.user!.uid;
  String get _myName => _auth.user!.name ?? '';
  int? get _myAvatar => UserData.instance.avatar;

  DocumentReference<Map<String, dynamic>> _doc(String owner, String other) =>
      _db.collection('friends').doc(owner).collection('list').doc(other);

  /// Procura uma conta pelo nome exato; null se não existe.
  Future<(String, String)?> findAccount(String name) async {
    final snap = await _db.collection('usernames').doc(AuthService.nameKey(name)).get();
    final d = snap.data();
    return d == null ? null : (d['uid'] as String, d['name'] as String);
  }

  Future<void> sendRequest(String otherUid, String otherName) async {
    final batch = _db.batch()
      ..set(_doc(_me, otherUid), {'name': otherName, 'avatar': null, 'status': 'sent', 'since': FieldValue.serverTimestamp()})
      ..set(_doc(otherUid, _me),
          {'name': _myName, 'avatar': _myAvatar, 'status': 'received', 'since': FieldValue.serverTimestamp()});
    await batch.commit();
  }

  Future<void> accept(String otherUid) async {
    final batch = _db.batch()
      ..update(_doc(_me, otherUid), {'status': 'friends'})
      ..update(_doc(otherUid, _me), {'status': 'friends', 'name': _myName, 'avatar': _myAvatar});
    await batch.commit();
  }

  /// Desfaz a amizade, recusa ou cancela um pedido (apaga os dois lados).
  Future<void> remove(String otherUid) async {
    final batch = _db.batch()
      ..delete(_doc(_me, otherUid))
      ..delete(_doc(otherUid, _me));
    await batch.commit();
  }

  Future<void> sendChallenge(String friendUid, String code, int score) => _doc(friendUid, _me).update({
        'name': _myName,
        'avatar': _myAvatar,
        'challenge': {'code': code, 'score': score, 'at': DateTime.now().millisecondsSinceEpoch},
      });

  Future<void> clearChallenge(String friendUid) => _doc(_me, friendUid).update({'challenge': null});

  /// Recorde do Ranked de cada amigo (ranking/{uid}), ou 0.
  Future<Map<String, int>> records(List<String> uids) async {
    final out = <String, int>{};
    await Future.wait(uids.map((uid) async {
      try {
        final snap = await _db.collection('ranking').doc(uid).get();
        out[uid] = (snap.data()?['score'] as num?)?.toInt() ?? 0;
      } catch (_) {
        out[uid] = 0;
      }
    }));
    return out;
  }
}
