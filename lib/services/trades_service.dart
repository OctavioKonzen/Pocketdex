// lib/services/trades_service.dart
//
// Trocas entre amigos (as mesmas do site, web-site/src/lib/trades.js):
//   trades/{uid} → {dupes: [id], caught: [id], updatedAt}
// dupes = Pokémon que a pessoa tem repetidos; caught = todos os que ela já
// pegou (da Coleção). Só a própria pessoa escreve; os amigos leem, e assim
// cada um vê o que pode dar e o que pode receber.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'user_data.dart';

class TradeList {
  final List<int> dupes;
  final Set<int> caught;
  const TradeList(this.dupes, this.caught);

  static List<int> _ints(Object? v) => v is List
      ? [
          for (final x in v)
            if (x is num) x.toInt()
        ]
      : const [];
  factory TradeList.fromMap(Map<String, dynamic>? d) => TradeList(_ints(d?['dupes']), _ints(d?['caught']).toSet());
}

class TradesService {
  TradesService._();
  static final TradesService instance = TradesService._();

  static const max = 1100;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String get _me => AuthService.instance.user!.uid;
  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection('trades').doc(uid);

  /// A minha lista, em tempo real.
  Stream<TradeList> mine() => _doc(_me).snapshots().map((s) => TradeList.fromMap(s.data()));

  /// Grava os repetidos (e atualiza os pegos a partir da Coleção).
  Future<void> setDupes(List<int> dupes) => _doc(_me).set({
        'dupes': dupes.take(max).toList(),
        'caught': _caught(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  List<int> _caught() => (UserData.instance.allCaught.toList()..sort()).take(max).toList();

  /// Deixa os pegos em dia com a Coleção (só grava se mudou).
  Future<void> syncCaught() async {
    if (AuthService.instance.user == null) return;
    final snap = await _doc(_me).get();
    final now = _caught();
    final saved = TradeList.fromMap(snap.data());
    if (snap.exists && saved.caught.length == now.length && saved.caught.containsAll(now)) return;
    await _doc(_me).set({
      'dupes': saved.dupes,
      'caught': now,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Listas dos amigos (quem ainda não marcou nada fica de fora).
  Future<Map<String, TradeList>> ofFriends(List<String> uids) async {
    final out = <String, TradeList>{};
    await Future.wait(uids.map((uid) async {
      try {
        final snap = await _doc(uid).get();
        if (snap.exists) out[uid] = TradeList.fromMap(snap.data());
      } catch (_) {}
    }));
    return out;
  }

  /// Apaga a lista (ao excluir a conta).
  Future<void> deleteMine(String uid) => _doc(uid).delete();
}
