import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import '../services/damage_calc.dart';
import '../services/friends_service.dart';
import '../services/league.dart';
import '../services/online_battle.dart';
import '../services/party_battle.dart';
import '../services/auth_service.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import 'turn_battle_screen.dart';

Future<Map<String, dynamic>> _selectedTeam(int index, List<Map<String, dynamic>> teams) async {
  if (index >= 0) return teams[index];
  final members = await TurnBattleSetup.randomTeam(Random().nextDouble);
  return {'name': 'Time aleatório', 'pokemon': [for (final m in members) m.$1], 'sets': [for (final m in members) m.$2]};
}

String _error(Object e) => e is FirebaseException
    ? e.code == 'permission-denied' ? 'Sem permissão para esta partida. Confira se vocês ainda são amigos e se o app está atualizado.' : 'Confira sua conexão e tente novamente.'
    : e is StateError ? e.message : 'Não foi possível atualizar a partida. Tente novamente.';

class OnlineBattleScreen extends StatefulWidget {
  final String? friendUid;
  const OnlineBattleScreen({super.key, this.friendUid});
  @override
  State<OnlineBattleScreen> createState() => _OnlineBattleScreenState();
}
class _OnlineBattleScreenState extends State<OnlineBattleScreen> {
  String? _friend;
  int? _team = -1;
  int _count = 1;
  String _npcDifficulty = 'normal';
  final Map<int, String> _participants = {};
  bool _busy = false;
  String? _errorText;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _rooms;
  @override
  void initState() {
    super.initState();
    _friend = widget.friendUid;
    _rooms = OnlineBattles.watchMine();
  }
  List<Map<String, dynamic>> get _teams => UserData.instance.teams.where((t) => BattleTeam.fromMap(t) != null).toList();
  /// O amigo escolhido, se ele está na lista (os menus quebram com um valor fora da lista).
  String? get _knownFriend => FriendsService.instance.friends.any((f) => f.uid == _friend) ? _friend : null;

  Future<void> _invite() async {
    setState(() { _busy = true; _errorText = null; });
    try {
      final seats = [for (var seat = 0; seat < _count * 2; seat++) seat == 0 ? OnlineBattles.me : _participants[seat] ?? (seat < _count ? OnlineBattles.me : _friend ?? 'npc$seat')];
      // Quem não está (mais) na lista de amigos não entra: avisa em vez de quebrar.
      final friendNames = {for (final f in FriendsService.instance.friends) f.uid: f.name};
      final humans = seats.toSet().where((uid) => !PartyBattle.isNpc(uid));
      if (humans.any((uid) => uid != OnlineBattles.me && !friendNames.containsKey(uid))) throw StateError('Escolha amigos da sua lista.');
      final names = {for (final uid in humans) uid: uid == OnlineBattles.me ? AuthService.instance.user!.name ?? '' : friendNames[uid]!};
      final id = await OnlineBattles.inviteGame(seats, _count, names, await _selectedTeam(_team!, _teams), npcDifficulty: _npcDifficulty);
      if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineBattleRoomScreen(id: id)));
    } catch (e) { if (mounted) setState(() => _errorText = _error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha online')),
      body: ReadableWidth(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Monte as equipes com amigos e NPCs. Você também pode controlar todas as posições da sua equipe.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(initialValue: _count, isExpanded: true, decoration: const InputDecoration(labelText: 'Formato'), items: const [DropdownMenuItem(value: 1, child: Text('Individual')), DropdownMenuItem(value: 2, child: Text('Dupla')), DropdownMenuItem(value: 3, child: Text('Tripla'))], onChanged: _busy ? null : (v) => setState(() { _count = v!; _participants.clear(); })),
        const SizedBox(height: 12),
        if (_count == 1) DropdownButtonFormField<String>(
          initialValue: _knownFriend, isExpanded: true, decoration: const InputDecoration(labelText: 'Amigo'),
          items: [for (final f in FriendsService.instance.friends) DropdownMenuItem(value: f.uid, child: Text(f.name))],
          onChanged: _busy ? null : (v) => setState(() => _friend = v),
        ),
        if (_count > 1) ...[
          const Text('Sua equipe começa com você. Escolha quem controla cada posição; a mesma pessoa pode controlar mais de uma.'),
          for (var seat = 1; seat < _count * 2; seat++) Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: DropdownButtonFormField<String>(key: ValueKey((_count, seat)),
            initialValue: _participants[seat] ?? (seat < _count ? OnlineBattles.me : _knownFriend ?? 'npc$seat'), isExpanded: true,
            decoration: InputDecoration(labelText: '${seat < _count ? 'Sua equipe' : 'Equipe adversária'} · posição ${seat % _count + 1}'),
            items: [if (seat < _count) DropdownMenuItem(value: OnlineBattles.me, child: const Text('Você')), DropdownMenuItem(value: 'npc$seat', child: const Text('NPC')), for (final friend in FriendsService.instance.friends) DropdownMenuItem(value: friend.uid, child: Text(friend.name))],
            onChanged: _busy ? null : (value) => setState(() => _participants[seat] = value!))),
          const Text('Dupla: até quatro jogadores. Tripla: até seis. Também vale você e um amigo contra NPCs.'),
        ],
        const SizedBox(height: 12),
        if (_count > 1) DropdownButtonFormField<String>(isExpanded: true, initialValue: _npcDifficulty, decoration: const InputDecoration(labelText: 'Dificuldade dos NPCs'), items: const [DropdownMenuItem(value: 'normal', child: Text('Normal')), DropdownMenuItem(value: 'hard', child: Text('Difícil'))], onChanged: _busy ? null : (v) => setState(() => _npcDifficulty = v!)),
        if (_count > 1) const Padding(padding: EdgeInsets.only(top: 6, bottom: 12), child: Text('Normal: IVs e EVs aleatórios.\nDifícil: sets competitivos.')),
        DropdownButtonFormField<int>(
          initialValue: _team, isExpanded: true, decoration: const InputDecoration(labelText: 'Seu time'),
          items: [const DropdownMenuItem(value: -1, child: Text('🎲 Time aleatório')), for (final (i, t) in _teams.indexed) DropdownMenuItem(value: i, child: Text('${t['name']}'))],
          onChanged: _busy ? null : (v) => setState(() => _team = v),
        ),

        const SizedBox(height: 12),
        FilledButton(onPressed: _busy || _count == 1 && _friend == null || _team == null ? null : _invite, child: Text(_busy ? 'Enviando…' : 'Desafiar para batalha')),
        if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 24),
        _RandomMatch(teams: _teams),
        const SizedBox(height: 24),
        const Text('Convites e partidas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _rooms,
          builder: (context, snap) {
            if (snap.hasError) return Text(_error(snap.error!));
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final docs = [...snap.data!.docs]..sort((a, b) =>
              ((b.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0).compareTo((a.data()['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0));
            if (docs.isEmpty) return const Text('Nenhum convite ainda.');
            return Column(children: [for (final d in docs.take(50))
              Builder(builder: (context) {
                final r = d.data(), players = List<String>.from(d.data()['players'] as List);
                final other = players.firstWhere((p) => p != OnlineBattles.me);
                final status = r['status'] == 'pending' ? players[0] == OnlineBattles.me ? 'Convite enviado' : 'Convite recebido'
                    : r['status'] == 'closed' ? 'Encerrada' : 'Continuar batalha';
                return ListTile(title: Text('${(r['names'] as Map)[other]}'), subtitle: Text(status),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineBattleRoomScreen(id: d.id))));
              }),
            ]);
          },
        ),
      ])),
    );
  }
}

/// Adversário aleatório (OnlineBattles.tryMatch, matchQueue): entra na fila
/// com o time e procura a cada 3 s; quando alguém pega você (ou você pega
/// alguém), a sala aparece e a batalha abre sozinha. Igual ao site.
class _RandomMatch extends StatefulWidget {
  final List<Map<String, dynamic>> teams;
  const _RandomMatch({required this.teams});
  @override
  State<_RandomMatch> createState() => _RandomMatchState();
}

class _RandomMatchState extends State<_RandomMatch> {
  int? _team = -1;
  DateTime? _since;
  Map<String, dynamic>? _chosen;
  Timer? _timer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _watch;
  String? _errorText;
  DateTime _renewed = DateTime.now();

  Future<void> _start() async {
    setState(() => _errorText = null);
    try {
      final team = await _selectedTeam(_team!, widget.teams);
      _chosen = team;
      await OnlineBattles.joinQueue(team);
      final since = DateTime.now();
      _renewed = since;
      setState(() => _since = since);
      // Alguém pegou você: a sala nova aparece na sua lista.
      _watch = OnlineBattles.watchMine().listen((snap) {
        for (final d in snap.docs) {
          final r = d.data();
          final at = (r['createdAt'] as Timestamp?)?.toDate() ?? since;
          if (r['match'] == true && r['status'] == 'active' && !at.isBefore(since.subtract(const Duration(seconds: 5)))) {
            _found(d.id);
            return;
          }
        }
      });
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
      _tick();
    } catch (e) {
      if (mounted) setState(() => _errorText = _error(e));
    }
  }

  Future<void> _tick() async {
    final team = _chosen;
    if (_since == null || team == null) return;
    try {
      if (DateTime.now().difference(_renewed) > const Duration(minutes: 1)) {
        _renewed = DateTime.now();
        await OnlineBattles.joinQueue(team);
      }
      final id = await OnlineBattles.tryMatch(team);
      if (id != null) _found(id);
    } catch (e) {
      if (mounted) setState(() => _errorText = _error(e));
    }
  }

  void _found(String id) {
    if (_since == null) return;
    _stop();
    OnlineBattles.leaveQueue();
    if (mounted) Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineBattleRoomScreen(id: id)));
  }

  void _stop() {
    _timer?.cancel();
    _watch?.cancel();
    _timer = null;
    _watch = null;
    if (mounted) setState(() => _since = null);
  }

  void _cancel() {
    _stop();
    OnlineBattles.leaveQueue();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _watch?.cancel();
    if (_since != null) OnlineBattles.leaveQueue();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('random-match'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('🎲 Adversário aleatório', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Batalha individual com qualquer pessoa que também esteja procurando agora.'),
            const SizedBox(height: 12),
            if (_since == null) ...[
              DropdownButtonFormField<int>(
                initialValue: _team,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Seu time'),
                items: [const DropdownMenuItem(value: -1, child: Text('🎲 Time aleatório')), for (final (i, t) in widget.teams.indexed) DropdownMenuItem(value: i, child: Text('${t['name']}'))],
                onChanged: (v) => setState(() => _team = v),
              ),
              const SizedBox(height: 12),
              FilledButton(onPressed: _team == null ? null : _start, child: const Text('Procurar adversário')),
            ] else
              Row(children: [
                const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Procurando um adversário…')),
                OutlinedButton(onPressed: _cancel, child: const Text('Cancelar')),
              ]),
            if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
    );
  }
}

class OnlineBattleRoomScreen extends StatefulWidget {
  final String id;
  const OnlineBattleRoomScreen({super.key, required this.id});
  @override
  State<OnlineBattleRoomScreen> createState() => _OnlineBattleRoomScreenState();
}
class _OnlineBattleRoomScreenState extends State<OnlineBattleRoomScreen> {
  StreamSubscription? _roomSub, _actionsSub;
  Map<String, dynamic>? _room;
  List<Map<String, dynamic>>? _actions;
  TurnBattle? _battle;
  BattleHit? _hit;
  double Function(String, List<String>)? _typeEff;
  List<BattleEvent> _events = [];
  List<int>? _before;
  int _round = 0, _generation = 0;
  int? _team = -1;
  bool _busy = false, _replaying = true;
  String? _errorText;
  List<String> get _players => List<String>.from(_room!['players'] as List);
  int get _side => PartyBattle.sideOf(_room!, OnlineBattles.me);
  List<Map<String, dynamic>> get _teams => UserData.instance.teams.where((t) => BattleTeam.fromMap(t) != null).toList();
  @override
  void initState() {
    super.initState();
    _roomSub = OnlineBattles.watch(widget.id).listen((s) {
      if (!mounted) return;
      setState(() => _room = s.data());
      _replay();
    }, onError: (Object e) { if (mounted) setState(() => _errorText = _error(e)); });
    _actionsSub = OnlineBattles.watchActions(widget.id).listen((s) {
      _actions = [for (final d in s.docs) d.data()];
      _replay();
    }, onError: (Object e) { if (mounted) setState(() => _errorText = _error(e)); });
  }
  @override
  void dispose() {
    _generation++;
    _roomSub?.cancel(); _actionsSub?.cancel();
    _battle?.dispose();
    super.dispose();
  }
  Future<void> _replay() async {
    if (_room == null || _actions == null || _room!['status'] == 'pending' || !_players.every((_room!['teams'] as Map).containsKey)) return;
    final generation = ++_generation;
    final previousRound = _battle == null ? null : _round;
    final side = _side;
    setState(() => _replaying = true);
    TurnBattle? pendingBattle;
    try {
      if (_room!['protocol'] != OnlineBattles.protocol) throw StateError('Atualize o PocketDex e crie uma nova partida para usar as regras atuais de batalha.');
      final players = _players;
      final teams = _room!['teams'] as Map;
      final seed = (_room!['seed'] as num).toInt();
      final pairs = OnlineBattles.pairs(_actions!, players);
      final seats = PartyBattle.seatsOf(_room!);
      final rosters = <String, List<BattleMon>>{};
      for (final uid in seats.toSet()) {
        final packed = PartyBattle.isNpc(uid) ? (_room!['npcTeams'] as Map)[uid] : teams[uid];
        rosters[uid] = await TurnBattleSetup.mons(BattleTeam.fromMap(OnlineBattles.unpackTeam(packed as String))!.members, battleMonName);
        if (rosters[uid]!.isEmpty) throw StateError('Não foi possível preparar os times.');
      }
      final data = await DamageData.load();
      final hit = TurnBattleSetup.hitter(data);
      final battle = PartyBattle.create(rosters, seats, PartyBattle.countOf(_room!), League.seededRandom(seed));
      pendingBattle = battle;
      battle.start();
      final events = <BattleEvent>[];
      List<int>? before;
      for (final (i, pair) in pairs.indexed) {
        final animate = previousRound != null && i >= previousRound;
        if (animate && before == null) before = [battle.active(side).id, battle.active(1 - side).id];
        final next = PartyBattle.play(battle, pair);
        if (animate) events.addAll(next.map((e) => BattleEvent.viewFor(e, side)));
      }
      if (!mounted || generation != _generation) { battle.dispose(); pendingBattle = null; return; }
      _battle?.dispose();
      setState(() {
        _battle = battle; _round = pairs.length; _hit = hit;
        _typeEff = TurnBattleSetup.typeEffect(data); _events = events; _before = before;
        _replaying = false; _errorText = null;
      });
      pendingBattle = null;
    } catch (e) {
      pendingBattle?.dispose();
      if (mounted && generation == _generation) setState(() { _errorText = _error(e); _replaying = false; });
    }
  }
  Future<void> _run(Future<void> Function() fn) async {
    setState(() { _busy = true; _errorText = null; });
    try { await fn(); }
    catch (e) { if (mounted) setState(() => _errorText = _error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  void _send(Map<String, dynamic> action) => _run(() => OnlineBattles.submit(widget.id, _round, action));
  @override
  Widget build(BuildContext context) {
    final room = _room, battle = _battle;
    return Scaffold(appBar: AppBar(title: const Text('Batalha online')),
      body: ReadableWidth(child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
        if (room == null) const Center(child: CircularProgressIndicator())
        else ...[
          Text('Batalha com ${_players.where((uid) => uid != OnlineBattles.me).map((uid) => (room['names'] as Map)[uid]).join(', ')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Nível máximo 50. O turno acontece quando todos os jogadores enviarem suas escolhas.'),
          const SizedBox(height: 12),
          if (room['status'] == 'pending' && room['protocol'] == OnlineBattles.protocol) ...[
            for (final uid in _players) Text('${(room['names'] as Map)[uid]}: ${(room['teams'] as Map).containsKey(uid) ? 'pronto' : 'aguardando aceite e time'}'),
            if ((room['teams'] as Map).containsKey(OnlineBattles.me)) const Text('Aguardando os outros participantes.')
            else ...[
              const Text('Você recebeu um convite para batalhar!'),
              DropdownButtonFormField<int>(
                initialValue: _team, isExpanded: true, decoration: const InputDecoration(labelText: 'Seu time'),
                items: [const DropdownMenuItem(value: -1, child: Text('🎲 Time aleatório')), for (final (i, t) in _teams.indexed) DropdownMenuItem(value: i, child: Text('${t['name']}'))],
                onChanged: _busy ? null : (v) => setState(() => _team = v)),
      
              FilledButton(onPressed: _busy || _team == null ? null : () => _run(() async => OnlineBattles.accept(widget.id, await _selectedTeam(_team!, _teams))), child: const Text('Aceitar e entrar')),
            ],
            TextButton(onPressed: _busy ? null : () => _run(() => OnlineBattles.close(widget.id)), child: Text(_side == 0 ? 'Cancelar convite' : 'Recusar')),
          ],
          if (room['status'] == 'pending' && room['protocol'] != OnlineBattles.protocol) ...[
            const Text('Atualize o PocketDex e crie uma nova partida para usar as regras atuais de batalha.'),
            TextButton(onPressed: _busy ? null : () => _run(() => OnlineBattles.close(widget.id)), child: const Text('Encerrar convite antigo')),
          ],
          if (room['status'] == 'closed' && battle == null) Text(room['endedBy'] == OnlineBattles.me ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.'),
          if (battle != null && _hit != null && _typeEff != null)
            Builder(builder: (context) {
              final mine = battle.active(_side);
              final ownAction = _actions!.any((a) => a['round'] == _round && a['uid'] == OnlineBattles.me);
              final expired = room['createdAt'] is Timestamp && DateTime.now().difference((room['createdAt'] as Timestamp).toDate()).inDays >= 7;
              final disabled = _busy || ownAction || _replaying || room['status'] != 'active' || expired || _round >= OnlineBattles.maxRounds || battle.winner != null;
              final replacing = battle.forceSwitch.any((s) => s) || [0, 1].any((s) => battle.active(s).hp <= 0);
              final message = room['status'] == 'closed'
                  ? room['endedBy'] == OnlineBattles.me ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.'
                  : battle.winner != null ? battle.winner == -1 ? 'A batalha terminou empatada!' : battle.winner == _side ? 'Você venceu! 🎉' : 'Seu amigo venceu!'
                  : expired ? 'Esta partida expirou. Crie uma nova batalha.'
                  : _round >= OnlineBattles.maxRounds ? 'Limite de turnos atingido. Partida encerrada.'
                  : ownAction ? 'Você já enviou sua ação. Aguardando seu amigo…'
                  : _replaying ? 'Atualizando batalha…'
                  : replacing ? mine.hp <= 0 ? 'Escolha outro Pokémon.' : 'Seu amigo precisa trocar de Pokémon.'
                  : 'Escolha sua ação para o turno ${battle.turn}';
              return BattleView(
                battle: battle.mode == 'singles' ? battle.viewFor(_side) : battle, hit: _hit!, typeEff: _typeEff!,
                foeName: _players.where((uid) => uid != OnlineBattles.me).map((uid) => (room['names'] as Map)[uid]).join(', '),
                onAgain: () {}, onExit: () => Navigator.pop(context),
                online: OnlineBattleControl(
                  round: _round, events: _events, before: _before, uid: OnlineBattles.me, names: Map<String, dynamic>.from(room['names'] as Map),
                  locked: disabled, message: message,
                  waitForSwitch: replacing && !battle.viewFor(_side).needSwitch,
                  onAction: _send, onClose: () => _run(() => OnlineBattles.close(widget.id)),
                ),
              );
            }),
          if (room['status'] == 'active') TextButton(onPressed: _busy ? null : () => _run(() => OnlineBattles.close(widget.id)), child: const Text('Desistir / encerrar partida')),
        ],
      ])),
    );
  }
}

class OnlineBattleInvites extends StatefulWidget {
  const OnlineBattleInvites({super.key});
  @override
  State<OnlineBattleInvites> createState() => _OnlineBattleInvitesState();
}
class _OnlineBattleInvitesState extends State<OnlineBattleInvites> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = OnlineBattles.watchMine();
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      final docs = snapshot.data?.docs.where((d) => d.data()['status'] != 'closed' &&
        d.data()['createdAt'] is Timestamp && DateTime.now().difference((d.data()['createdAt'] as Timestamp).toDate()).inDays < 7).toList() ?? [];
      if (docs.isEmpty) return const SizedBox.shrink();
      return Card(child: Column(children: [
        const Padding(padding: EdgeInsets.all(12), child: Text('Batalhas com amigos', style: TextStyle(fontWeight: FontWeight.bold))),
        for (final d in docs.take(10)) Builder(builder: (context) {
          final r = d.data(), players = List<String>.from(d.data()['players'] as List);
          final other = players.firstWhere((p) => p != OnlineBattles.me);
          return ListTile(title: Text('${(r['names'] as Map)[other]}'),
            subtitle: Text(r['status'] == 'pending' ? players[0] == OnlineBattles.me ? 'Convite enviado' : 'Te desafiou para uma batalha!' : 'Continuar partida'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineBattleRoomScreen(id: d.id))));
        }),
      ]));
    },
  );
}
