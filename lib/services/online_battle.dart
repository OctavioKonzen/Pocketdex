import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'party_battle.dart';
import 'turn_battle.dart';

class OnlineBattles {
  static const protocol = 5;
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
    return inviteGame([me, friendUid], 1, {me: AuthService.instance.user!.name ?? '', friendUid: friendName}, team);
  }
  static Future<String> inviteGame(List<String> seats, int count, Map<String, String> names, Map<String, dynamic> team,
      {String npcDifficulty = 'normal', List<String> rules = const []}) async {
    if (rules.contains('species') && repeatedSpecies(team)) throw StateError('Com a regra "sem Pokémon repetido", o time não pode repetir Pokémon.');
    final players = [me, ...seats.toSet().where((uid) => uid != me && !PartyBattle.isNpc(uid))];
    if (players.length < 2 || players.length > 6 || seats.length != count * 2 || seats[0] != me || players.any((uid) => seats.take(count).contains(uid) && seats.skip(count).contains(uid))) {
      throw StateError('Escolha os participantes de cada equipe, com pelo menos um amigo.');
    }
    final npcTeams = <String, String>{};
    validateParticipantTeam(team, seats, me);
    final random = Random();
    for (final uid in seats.toSet().where(PartyBattle.isNpc)) {
      final members = await TurnBattleSetup.randomTeam(random.nextDouble, difficulty: npcDifficulty);
      npcTeams[uid] = packTeam({'name': 'NPC', 'pokemon': [for (final member in members) member.$1], 'sets': [for (final member in members) member.$2]});
    }
    final ref = await rooms.add({
      'protocol': protocol, 'players': players, 'mode': PartyBattle.modeOf(count), 'seats': seats, 'npcTeams': npcTeams,
      'names': names,
      'teams': {me: packTeam(team)}, 'status': 'pending',
      'seed': Random().nextInt(1 << 31), 'createdAt': FieldValue.serverTimestamp(), 'endedBy': null,
      if (rules.isNotEmpty) 'rules': rules,
    });
    return ref.id;
  }
  static Future<void> accept(String id, Map<String, dynamic> team) async {
    final ref = rooms.doc(id);
    await db.runTransaction((tx) async {
      final room = (await tx.get(ref)).data();
      if (room == null || room['status'] != 'pending' || (room['teams'] as Map).containsKey(me)) throw StateError('Este convite já foi respondido.');
      if (((room['rules'] as List?) ?? const []).contains('species') && repeatedSpecies(team)) {
        throw StateError('Com a regra "sem Pokémon repetido", o time não pode repetir Pokémon.');
      }
      validateParticipantTeam(team, PartyBattle.seatsOf(room), me);
      final teams = {...room['teams'] as Map, me: packTeam(team)};
      tx.update(ref, {'teams': teams, 'status': (room['players'] as List).every(teams.containsKey) ? 'active' : 'pending'});
    });
  }
  static Future<void> close(String id) => rooms.doc(id).update({'status': 'closed', 'endedBy': me});
  // ------------------------------------------- tempo, emotes e ranking (igual ao site)

  /// Tempo para escolher a ação; depois disso o jogo escolhe por você.
  static const turnSeconds = 90;
  /// Sem jogar por esse tempo depois da sua ação: dá para reivindicar a vitória.
  static const idle = Duration(minutes: 3);

  /// O adversário sumiu na rodada [round] (você já jogou há 3 min): você vence.
  static Future<void> claimTimeout(String id, int round, String other) =>
      rooms.doc(id).update({'status': 'closed', 'endedBy': other, 'timeout': round});

  static const emotes = ['👍', '😂', '😮', '😡', '🔥', 'GG'];
  static Future<void> sendEmote(String id, String e) =>
      rooms.doc(id).collection('emotes').add({'uid': me, 'e': e, 'at': FieldValue.serverTimestamp()});
  static Stream<List<Map<String, dynamic>>> watchEmotes(String id) => rooms
      .doc(id)
      .collection('emotes')
      .orderBy('at', descending: true)
      .limit(6)
      .snapshots()
      .map((s) => [for (final d in s.docs) {'id': d.id, ...d.data()}]);

  /// Temporada do ranking: o mês ("AAAA-MM").
  static String currentSeason([DateTime? now]) {
    final d = now ?? DateTime.now();
    return '${d.year}-${'${d.month}'.padLeft(2, '0')}';
  }

  /// Elo (K = 32): os pontos depois da partida, no máximo ±40.
  static int eloAfter(int rating, int opponent, bool won) {
    final expected = 1 / (1 + pow(10, (opponent - rating) / 400));
    final change = (32 * ((won ? 1 : 0) - expected)).round().clamp(-40, 40);
    return rating + change;
  }

  /// Depois de uma partida da fila: atualiza o seu ranking (uma vez por sala). Devolve a mudança.
  static Future<int?> rateMatch(String roomId, String opponent, bool won, {int? avatar}) async {
    final season = currentSeason();
    final mine = await db.doc('ratings/$me').get();
    final theirs = await db.doc('ratings/$opponent').get();
    if (mine.data()?['lastRoom'] == roomId) return null;
    final old = mine.data()?['season'] == season ? mine.data() : null;
    final base = (old?['rating'] as num?)?.toInt() ?? 1000;
    final opp = theirs.data()?['season'] == season ? (theirs.data()!['rating'] as num).toInt() : 1000;
    final rating = eloAfter(base, opp, won);
    await db.doc('ratings/$me').set({
      'name': AuthService.instance.user!.name ?? '', 'avatar': avatar, 'rating': rating,
      'wins': ((old?['wins'] as num?)?.toInt() ?? 0) + (won ? 1 : 0), 'losses': ((old?['losses'] as num?)?.toInt() ?? 0) + (won ? 0 : 1),
      'season': season, 'lastRoom': roomId, 'updatedAt': FieldValue.serverTimestamp(),
    });
    return rating - base;
  }

  /// Os melhores da temporada (sem índice composto: pega os maiores e filtra aqui).
  static Stream<List<Map<String, dynamic>>> watchLeaderboard(String season) => db
      .collection('ratings')
      .orderBy('rating', descending: true)
      .limit(100)
      .snapshots()
      .map((s) => [for (final d in s.docs) if (d.data()['season'] == season) {'uid': d.id, ...d.data()}].take(20).toList());

  /// Regras opcionais do convite: Pokémon repetido no time.
  static bool repeatedSpecies(Map<String, dynamic> team) {
    final ids = [for (final id in (team['pokemon'] as List? ?? const [])) if (id != null) id];
    return ids.length != ids.toSet().length;
  }

  static void validateParticipantTeam(Map<String, dynamic> team, List<String> seats, String uid) {
    final required = seats.where((p) => p == uid).length;
    final available = (team['pokemon'] as List).take(6).where((id) => id is int && id > 0).length;
    if (required == 0 || available < required) throw StateError('Escolha um time com pelo menos ${required == 0 ? 1 : required} Pokémon para suas posições.');
  }
  // ------------------------------------------------------ adversário aleatório
  // Fila matchQueue/{uid} = {name, team, mode, at, claimedBy} (firestore.rules):
  // cada um deixa o nome e o time; quem procura pega da fila só quem tem uid
  // maior que o seu (assim dois não se pegam ao mesmo tempo) e, na mesma
  // escrita, marca a vaga e cria a sala já pronta (match: true). O outro vê a
  // sala aparecer na lista dele e entra. Igual ao site (lib/onlineBattle.js).

  /// Quanto tempo uma vaga na fila vale sem ser renovada.
  static const queueTtl = Duration(minutes: 2);

  static Future<void> joinQueue(Map<String, dynamic> team) => db.doc('matchQueue/$me').set({
        'name': AuthService.instance.user!.name ?? '',
        'team': packTeam(team),
        'mode': 'singles',
        'at': FieldValue.serverTimestamp(),
        'claimedBy': null,
      });

  static Future<void> leaveQueue() async {
    final user = AuthService.instance.user;
    if (user == null) return;
    try {
      await db.doc('matchQueue/${user.uid}').delete();
    } catch (_) {}
  }

  /// Procura alguém na fila; achou: cria a sala e devolve o id (senão null).
  static Future<String?> tryMatch(Map<String, dynamic> team) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final snap = await db.collection('matchQueue').where('mode', isEqualTo: 'singles').get();
    final candidates = snap.docs
        .where((d) => d.id.compareTo(me) > 0 && d.data()['claimedBy'] == null &&
            now - ((d.data()['at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0) < queueTtl.inMilliseconds)
        .toList()
      ..sort((a, b) => ((a.data()['at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((b.data()['at'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
    for (final other in candidates) {
      final room = rooms.doc();
      try {
        await db.runTransaction((tx) async {
          final ref = db.doc('matchQueue/${other.id}');
          final current = await tx.get(ref);
          final q = current.data();
          if (q == null || q['claimedBy'] != null) throw StateError('já pego');
          tx.update(ref, {'claimedBy': me});
          tx.set(room, {
            'protocol': protocol, 'mode': 'singles', 'players': [me, other.id], 'seats': [me, other.id], 'npcTeams': <String, dynamic>{},
            'names': {me: AuthService.instance.user!.name ?? '', other.id: q['name']}, 'teams': {me: packTeam(team), other.id: q['team']},
            'status': 'active', 'seed': Random().nextInt(1 << 31), 'createdAt': FieldValue.serverTimestamp(), 'endedBy': null, 'match': true,
          });
        });
        return room.id;
      } catch (_) {
        // Outro pegou antes: tenta o próximo.
      }
    }
    return null;
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> watchMine() => rooms.where('players', arrayContains: me).snapshots();
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String id) => rooms.doc(id).snapshots();
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchActions(String id) =>
      rooms.doc(id).collection('actions').limit(maxRounds * 6).snapshots();
  static Future<void> submit(String id, int round, Map<String, dynamic> action) async {
    final ref = rooms.doc(id).collection('actions').doc('${round}_$me');
    await db.runTransaction((tx) async {
      final room = (await tx.get(rooms.doc(id))).data()!;
      final old = await tx.get(ref);
      if (old.exists) throw StateError('Você já enviou sua ação neste turno.');
      final seats = PartyBattle.seatsOf(room), count = PartyBattle.countOf(room), side = PartyBattle.sideOf(room, me);
      final raw = action['kind'] == 'team' ? action['choices'] as List : [{'seat': seats.indexOf(me), ...action}];
      final choices = [for (final dynamic value in raw) <String, dynamic>{...value as Map<String, dynamic>, 'index': value['index'] ?? 0, 'gimmick': value['gimmick'] == null || value['gimmick'] == '' ? 'none' : value['gimmick'], 'target': value['target'] ?? 0}];
      final teammates = seats.skip(side * count).take(count).toSet().where((uid) => uid != me && !PartyBattle.isNpc(uid));
      final existing = <Map<String, dynamic>>[];
      for (final uid in teammates) {
        final other = await tx.get(rooms.doc(id).collection('actions').doc('${round}_$uid'));
        if (other.exists) { existing.addAll((other.data()!['choices'] as List).map((c) => Map<String, dynamic>.from(c as Map))); }
      }
      validateGroupChoices([...existing, ...choices]);
      tx.set(ref, {'uid': me, 'round': round, 'kind': 'team', 'choices': choices, 'at': FieldValue.serverTimestamp()});
    });
  }
  static void validateGroupChoices(List<Map<String, dynamic>> choices) {
    final switches = [for (final choice in choices) if (choice['kind'] == 'switch') choice['index']];
    if (switches.toSet().length != switches.length) throw StateError('Esse Pokémon já foi escolhido para outra posição. Escolha outra reserva.');
    final mechanics = [for (final choice in choices) if (choice['kind'] == 'move' && choice['gimmick'] != null && choice['gimmick'] != '' && choice['gimmick'] != 'none') choice['gimmick']];
    if (mechanics.toSet().length != mechanics.length) throw StateError('Seu parceiro já escolheu essa transformação neste turno.');
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
