import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;
import '../i18n/text.dart';
import '../services/damage_calc.dart';
import '../services/friends_service.dart';
import '../services/league.dart';
import '../services/online_battle.dart';
import '../services/turn_battle.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../widgets/pokemon_sprite.dart';
import 'turn_battle_screen.dart';

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
  int? _team;
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
  Future<void> _invite() async {
    setState(() { _busy = true; _errorText = null; });
    try {
      final f = FriendsService.instance.friends.firstWhere((f) => f.uid == _friend);
      final id = await OnlineBattles.invite(f.uid, f.name, _teams[_team!]);
      if (mounted) await Navigator.push(context, MaterialPageRoute(builder: (_) => OnlineBattleRoomScreen(id: id)));
    } catch (e) { if (mounted) setState(() => _errorText = _error(e)); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha online')),
      body: ReadableWidth(child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Convide um amigo. Cada jogador controla seu próprio time.'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _friend, isExpanded: true, decoration: const InputDecoration(labelText: 'Amigo'),
          items: [for (final f in FriendsService.instance.friends) DropdownMenuItem(value: f.uid, child: Text(f.name))],
          onChanged: _busy ? null : (v) => setState(() => _friend = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _team, isExpanded: true, decoration: const InputDecoration(labelText: 'Seu time'),
          items: [for (final (i, t) in _teams.indexed) DropdownMenuItem(value: i, child: Text('${t['name']}'))],
          onChanged: _busy ? null : (v) => setState(() => _team = v),
        ),
        if (_teams.isEmpty) const Text('Monte um time em Times para batalhar.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy || _friend == null || _team == null ? null : _invite, child: Text(_busy ? 'Enviando…' : 'Desafiar para batalha')),
        if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
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
  List<String> _logs = [];
  int _round = 0, _generation = 0;
  int? _team;
  bool _busy = false, _replaying = true;
  String? _errorText;
  String _gimmick = '';
  List<String> get _players => List<String>.from(_room!['players'] as List);
  int get _side => _players.indexOf(OnlineBattles.me);
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
    super.dispose();
  }
  Future<void> _replay() async {
    if (_room == null || _actions == null || _room!['status'] == 'pending' || !(_room!['teams'] as Map).containsKey(_players[1])) return;
    final generation = ++_generation;
    setState(() => _replaying = true);
    try {
      if (_room!['protocol'] != 1) throw StateError('Atualize o PocketDex para abrir esta partida.');
      final players = _players;
      final teams = _room!['teams'] as Map;
      final seed = (_room!['seed'] as num).toInt();
      final pairs = OnlineBattles.pairs(_actions!, players);
      final a = await TurnBattleSetup.mons(BattleTeam.fromMap(OnlineBattles.unpackTeam(teams[players[0]] as String))!.members, (row) => '${row['name']}');
      final b = await TurnBattleSetup.mons(BattleTeam.fromMap(OnlineBattles.unpackTeam(teams[players[1]] as String))!.members, (row) => '${row['name']}');
      if (a.isEmpty || b.isEmpty) throw StateError('Não foi possível preparar os times.');
      final hit = TurnBattleSetup.hitter(await DamageData.load());
      final battle = TurnBattle(a, b, League.seededRandom(seed));
      final events = [...battle.start()];
      for (final pair in pairs) { events.addAll(battle.playOnlineTurn(pair, hit)); }
      final logs = <String>[];
      for (final e in events.where((e) => e.t == 'text')) {
        // Ajusta as falas à perspectiva de quem está vendo.
        final args = [for (final v in e.args) v is (int, String) ? (v.$1 == players.indexOf(OnlineBattles.me) ? 0 : 1, v.$2) : v];
        final (template, values) = TurnBattle.lineOf(BattleEvent.text(e.key, args));
        var text = tr(template);
        for (final (i, value) in values.indexed) { text = text.replaceAll('{$i}', value); }
        logs.add(text);
      }
      if (!mounted || generation != _generation) return;
      setState(() { _battle = battle; _round = pairs.length; _logs = logs.skip(logs.length > 10 ? logs.length - 10 : 0).toList(); _replaying = false; _errorText = null; _gimmick = ''; });
    } catch (e) {
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
  Widget _mon(TurnBattle battle, int side) {
    final p = battle.active(side);
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
      Text('${(_room!['names'] as Map)[_players[side]]}', style: const TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 140, child: PokemonSprite(p.id, shiny: p.shiny, back: side == _side, battle: true)),
      Text('${p.name} ${p.status.isEmpty ? '' : '(${p.status.toUpperCase()})'}'),
      LinearProgressIndicator(value: p.hp.clamp(0, p.maxHp) / p.maxHp),
      Text('${p.hp}/${p.maxHp} HP'),
    ])));
  }
  @override
  Widget build(BuildContext context) {
    final room = _room, battle = _battle;
    return Scaffold(appBar: AppBar(title: const Text('Batalha online')),
      body: ReadableWidth(child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_errorText != null) Text(_errorText!, style: const TextStyle(color: Colors.redAccent)),
        if (room == null) const Center(child: CircularProgressIndicator())
        else ...[
          Text('Batalha com ${(room['names'] as Map)[_players[1 - _side]]}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text('Escolham uma ação. O turno acontece quando os dois enviarem.'),
          const SizedBox(height: 12),
          if (room['status'] == 'pending') ...[
            if (_side == 0) const Text('Convite enviado. Aguardando seu amigo aceitar e escolher o time.')
            else ...[
              const Text('Você recebeu um convite para batalhar!'),
              DropdownButtonFormField<int>(
                initialValue: _team, isExpanded: true, decoration: const InputDecoration(labelText: 'Seu time'),
                items: [for (final (i, t) in _teams.indexed) DropdownMenuItem(value: i, child: Text('${t['name']}'))],
                onChanged: _busy ? null : (v) => setState(() => _team = v)),
              if (_teams.isEmpty) const Text('Monte um time em Times para batalhar.'),
              FilledButton(onPressed: _busy || _team == null ? null : () => _run(() => OnlineBattles.accept(widget.id, _teams[_team!])), child: const Text('Aceitar e entrar')),
            ],
            TextButton(onPressed: _busy ? null : () => _run(() => OnlineBattles.close(widget.id)), child: Text(_side == 0 ? 'Cancelar convite' : 'Recusar')),
          ],
          if (room['status'] == 'closed') Text(room['endedBy'] == OnlineBattles.me ? 'Você encerrou a partida.' : 'Seu amigo encerrou a partida.'),
          if (battle != null) ...[
            Row(children: [Expanded(child: _mon(battle, 1 - _side)), Expanded(child: _mon(battle, _side))]),
            Builder(builder: (context) {
              final mine = battle.active(_side);
              final ownAction = _actions!.any((a) => a['round'] == _round && a['uid'] == OnlineBattles.me);
              final expired = room['createdAt'] is Timestamp && DateTime.now().difference((room['createdAt'] as Timestamp).toDate()).inDays >= 7;
              final disabled = _busy || ownAction || _replaying || room['status'] != 'active' || expired || _round >= OnlineBattles.maxRounds || battle.winner != null;
              final replacing = [0, 1].any((s) => battle.active(s).hp <= 0);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (battle.winner != null) Text(battle.winner == _side ? 'Você venceu! 🎉' : 'Seu amigo venceu!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
                else if (expired) const Text('Esta partida expirou. Crie uma nova batalha.')
                else if (_round >= OnlineBattles.maxRounds) const Text('Limite de turnos atingido. Partida encerrada.')
                else Text(ownAction ? 'Você já enviou sua ação. Aguardando seu amigo…'
                    : _replaying ? 'Atualizando batalha…' : replacing ? mine.hp <= 0 ? 'Escolha outro Pokémon.' : 'Seu amigo precisa trocar de Pokémon.' : 'Escolha sua ação para o turno ${battle.turn}'),
                if (!replacing) ...[
                  Wrap(spacing: 8, children: [
                    if (mine.moves.every((m) => m.pp <= 0))
                      FilledButton(onPressed: disabled ? null : () => _send({'kind': 'move', 'index': -1}), child: const Text('Struggle'))
                    else for (final (i, m) in mine.moves.indexed)
                      FilledButton(onPressed: disabled || m.pp <= 0 ? null : () => _send({'kind': 'move', 'index': i, if (_gimmick.isNotEmpty) 'gimmick': _gimmick}),
                        child: Text('${m.name} · PP ${m.pp}/${m.maxPp}')),
                  ]),
                  DropdownButtonFormField<String>(
                    key: ValueKey(_round), initialValue: _gimmick, decoration: const InputDecoration(labelText: 'Mecânica especial'),
                    items: [const DropdownMenuItem(value: '', child: Text('Mecânica do time')),
                      for (final g in TurnBattle.gimmickList.where((g) => battle.canGimmick(_side, g, 0))) DropdownMenuItem(value: g, child: Text(g))],
                    onChanged: disabled ? null : (v) => setState(() => _gimmick = v ?? '')),
                ],
                if (replacing && mine.hp > 0) FilledButton(onPressed: disabled ? null : () => _send({'kind': 'wait', 'index': 0}), child: const Text('Aguardar troca do amigo')),
                if (!replacing || mine.hp <= 0) Wrap(spacing: 8, children: [
                  for (final (i, p) in battle.teams[_side].indexed)
                    OutlinedButton(onPressed: disabled || p.hp <= 0 || i == battle.activeIndex[_side] ? null : () => _send({'kind': 'switch', 'index': i}), child: Text('Trocar: ${p.name} (${p.hp} HP)')),
                ]),
              ]);
            }),
            const SizedBox(height: 12),
            for (final line in _logs) Text(line),
          ],
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
