// lib/services/draft_service.dart
//
// Draft entre amigos (o mesmo do site, web-site/src/lib/drafts.js):
//   drafts/{id} → {players: [a, b], names: {uid: nome}, picks: {uid: [id]},
//                  turn: uid, size, status: 'picking' | 'done', createdAt}
// Quem cria começa; cada um escolhe um Pokémon na sua vez, sem repetir, até
// os dois terem [size]. Depois dá para batalhar com os dois times.

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

class Draft {
  final String id;
  final List<String> players;
  final Map<String, String> names;
  final Map<String, List<int>> picks;
  final String turn;
  final int size;
  final String status;
  final DateTime? createdAt;
  const Draft(this.id, this.players, this.names, this.picks, this.turn, this.size, this.status, this.createdAt);

  factory Draft.fromDoc(String id, Map<String, dynamic> d) => Draft(
        id,
        ((d['players'] as List?) ?? const []).cast<String>(),
        {for (final e in ((d['names'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
        {
          for (final e in ((d['picks'] as Map?) ?? const {}).entries) '${e.key}': [for (final x in (e.value as List)) (x as num).toInt()],
        },
        d['turn'] as String? ?? '',
        (d['size'] as num?)?.toInt() ?? 6,
        d['status'] as String? ?? 'picking',
        (d['createdAt'] as Timestamp?)?.toDate(),
      );

  String other(String me) => players.firstWhere((p) => p != me, orElse: () => '');
  List<int> of(String uid) => picks[uid] ?? const [];
  bool get done => status == 'done';
  Set<int> get taken => {for (final l in picks.values) ...l};
}

class DraftService {
  DraftService._();
  static final DraftService instance = DraftService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _drafts => _db.collection('drafts');
  String get _me => AuthService.instance.user!.uid;

  /// Os meus drafts (mais novos primeiro).
  Stream<List<Draft>> mine() => _drafts.where('players', arrayContains: _me).snapshots().map((s) {
        final list = [for (final d in s.docs) Draft.fromDoc(d.id, d.data())];
        list.sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        return list;
      });

  Stream<Draft?> watch(String id) => _drafts.doc(id).snapshots().map((s) => s.exists ? Draft.fromDoc(s.id, s.data()!) : null);

  /// Novo draft com um amigo; eu começo escolhendo.
  Future<String> create(String friendUid, String friendName, {int size = 6}) async {
    final ref = _drafts.doc();
    await ref.set({
      'players': [_me, friendUid],
      'names': {_me: AuthService.instance.user?.name ?? '', friendUid: friendName},
      'picks': <String, dynamic>{},
      'turn': _me,
      'size': size,
      'status': 'picking',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Escolhe um Pokémon (só na minha vez e se ninguém escolheu).
  /// Devolve uma mensagem de erro, ou null se deu certo.
  Future<String?> pick(String id, int pokemonId) => _db.runTransaction((tx) async {
        final snap = await tx.get(_drafts.doc(id));
        if (!snap.exists) return 'Esse draft foi apagado.';
        final d = Draft.fromDoc(snap.id, snap.data()!);
        if (d.done) return 'O draft já acabou.';
        if (d.turn != _me) return 'Não é a sua vez.';
        if (d.taken.contains(pokemonId)) return 'Esse Pokémon já foi escolhido.';
        final mine = [...d.of(_me), pokemonId];
        final other = d.other(_me);
        final theirs = d.of(other);
        final finished = mine.length == d.size && theirs.length == d.size;
        tx.update(_drafts.doc(id), {
          'picks': {_me: mine, if (theirs.isNotEmpty) other: theirs},
          if (finished) 'status': 'done' else 'turn': theirs.length < d.size ? other : _me,
        });
        return null;
      });

  Future<void> delete(String id) => _drafts.doc(id).delete();

  /// Apaga todos os drafts de uma conta (ao excluir a conta).
  Future<void> deleteAllOf(String uid) async {
    final snap = await _drafts.where('players', arrayContains: uid).get();
    await Future.wait([for (final d in snap.docs) d.reference.delete()]);
  }
}
