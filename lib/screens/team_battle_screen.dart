// lib/screens/team_battle_screen.dart
//
// Batalha de times entre amigos (igual ao site, TeamBattlePage.jsx): escolhe
// um time seu e um time de um amigo e vê, 1 contra 1, quem ganha cada
// confronto com o melhor golpe de cada lado (lib/services/team_battle.dart).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' hide Text;

import '../i18n/text.dart';
import '../services/friends_service.dart';
import '../services/team_battle.dart';
import '../services/user_data.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/pokemon_sprite.dart';

/// Um time para a batalha: nome e membros (id + set).
class BattleTeam {
  final String name;
  final List<Member> members;
  const BattleTeam(this.name, this.members);

  static BattleTeam? fromMap(Map<String, dynamic> t) {
    final ids = (t['pokemon'] as List?) ?? const [];
    final sets = (t['sets'] as List?) ?? const [];
    final members = <Member>[
      for (var i = 0; i < ids.length && i < 6; i++)
        if (ids[i] is num) ((ids[i] as num).toInt(), i < sets.length && sets[i] is Map ? Map<String, dynamic>.from(sets[i] as Map) : null),
    ];
    return members.isEmpty ? null : BattleTeam('${t['name'] ?? 'Time'}', members);
  }
}

class TeamBattleScreen extends StatefulWidget {
  const TeamBattleScreen({super.key});

  @override
  State<TeamBattleScreen> createState() => _TeamBattleScreenState();
}

class _TeamBattleScreenState extends State<TeamBattleScreen> {
  int? _mine;
  String? _friend;
  List<BattleTeam>? _friendTeams;
  int? _theirs;
  List<List<Duel?>>? _result;
  bool _busy = false;

  List<BattleTeam> get _myTeams => [for (final t in UserData.instance.teams) BattleTeam.fromMap(t)].whereType<BattleTeam>().toList();

  Future<void> _pickFriend(String? uid) async {
    setState(() {
      _friend = uid;
      _friendTeams = null;
      _theirs = null;
      _result = null;
    });
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance.collection('publicTeams').where('ownerUid', isEqualTo: uid).get();
      final teams = [for (final d in snap.docs) BattleTeam.fromMap(d.data())].whereType<BattleTeam>().toList();
      if (mounted && _friend == uid) setState(() => _friendTeams = teams);
    } catch (_) {
      if (mounted) setState(() => _friendTeams = const []);
    }
  }

  Future<void> _fight() async {
    final mine = _myTeams[_mine!], theirs = _friendTeams![_theirs!];
    setState(() => _busy = true);
    final result = await TeamBattle.run(mine.members, theirs.members);
    if (mounted) {
      setState(() {
        _busy = false;
        _result = result;
      });
    }
  }

  Widget _teamRow(BattleTeam t) => Row(
        children: [
          Expanded(child: Text(t.name, overflow: TextOverflow.ellipsis)),
          for (final m in t.members) SizedBox.square(dimension: 28, child: PokemonSprite(m.$1, fill: 0.95)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final myTeams = _myTeams;
    final friends = FriendsService.instance.friends;
    InputDecoration deco(String label) => InputDecoration(labelText: tr(label), border: const OutlineInputBorder(), isDense: true);
    return Scaffold(
      appBar: AppBar(title: const Text('Batalha de times')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Cada Pokémon do seu time contra cada um do time do amigo, 1 contra 1, com o melhor golpe de cada lado.',
                style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 14),
            if (myTeams.isEmpty)
              const EmptyMessage('Monte um time em Times para batalhar.')
            else
              DropdownButtonFormField<int>(
                initialValue: _mine,
                isExpanded: true,
                decoration: deco('Seu time'),
                items: [for (final (i, t) in myTeams.indexed) DropdownMenuItem(value: i, child: _teamRow(t))],
                onChanged: (v) => setState(() {
                  _mine = v;
                  _result = null;
                }),
              ),
            const SizedBox(height: 12),
            if (friends.isEmpty)
              const EmptyMessage('Adicione amigos para batalhar com os times deles.')
            else
              DropdownButtonFormField<String>(
                initialValue: _friend,
                isExpanded: true,
                decoration: deco('Amigo'),
                items: [for (final f in friends) DropdownMenuItem(value: f.uid, child: Text(f.name))],
                onChanged: _pickFriend,
              ),
            if (_friend != null) ...[
              const SizedBox(height: 12),
              if (_friendTeams == null)
                const Center(child: CircularProgressIndicator())
              else if (_friendTeams!.isEmpty)
                Text('Esse amigo ainda não montou nenhum time.', style: TextStyle(color: c.muted))
              else
                DropdownButtonFormField<int>(
                  initialValue: _theirs,
                  isExpanded: true,
                  decoration: deco('Time do amigo'),
                  items: [for (final (i, t) in _friendTeams!.indexed) DropdownMenuItem(value: i, child: _teamRow(t))],
                  onChanged: (v) => setState(() {
                    _theirs = v;
                    _result = null;
                  }),
                ),
            ],
            const SizedBox(height: 16),
            PillButton(
              label: _busy ? tr('Calculando...') : '⚔️ ${tr('Batalhar!')}',
              expand: true,
              gradient: const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFF9333EA)]),
              onPressed: _busy || _mine == null || _theirs == null ? null : _fight,
            ),
            if (_result != null) ...[
              const SizedBox(height: 20),
              BattleResultView(result: _result!, mine: myTeams[_mine!], theirs: _friendTeams![_theirs!]),
            ],
          ],
        ),
      ),
    );
  }
}

/// Resultado da batalha de times (também usado no draft).
class BattleResultView extends StatelessWidget {
  final List<List<Duel?>> result;
  final BattleTeam mine, theirs;
  const BattleResultView({super.key, required this.result, required this.mine, required this.theirs});

  static const _win = Color(0xFF22C55E), _lose = Color(0xFFEF4444), _draw = Color(0xFF9CA3AF);

  static String _hits(int n) => n >= 99 ? '—' : '$n×';

  void _detail(BuildContext context, int i, int j, Duel d) {
    final me = mine.members[i].$1, them = theirs.members[j].$1;
    Widget side(int id, Hit h) => Row(
          children: [
            SizedBox.square(dimension: 48, child: PokemonSprite(id, fill: 0.95)),
            const SizedBox(width: 10),
            Expanded(
              child: h.hits >= 99
                  ? const Text('Não consegue causar dano.')
                  : Text(tr('{0}: {1}% por golpe · derrota em {2}')
                      .replaceAll('{0}', h.move)
                      .replaceAll('{1}', h.pct.toStringAsFixed(1).replaceAll('.', ','))
                      .replaceAll('{2}', tr(h.hits == 1 ? '1 golpe' : '{0} golpes').replaceAll('{0}', '${h.hits}'))),
            ),
          ],
        );
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(switch (d.result) { 1 => '✅ Você ganha', -1 => '❌ Você perde', _ => '🤝 Empate' },
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              side(me, d.mine),
              const SizedBox(height: 10),
              side(them, d.theirs),
              const SizedBox(height: 10),
              Text(d.sameSpeed ? 'Mesma velocidade.' : (d.faster ? 'O seu é mais rápido.' : 'O dele é mais rápido.'),
                  style: TextStyle(color: Theme.of(context).hintColor)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      for (final row in result)
        for (final d in row)
          if (d != null) d.result
    ];
    final wins = all.where((r) => r == 1).length, losses = all.where((r) => r == -1).length;
    final verdict = wins > losses ? '🏆 Seu time leva vantagem!' : (wins < losses ? '😬 O time do amigo leva vantagem.' : '🤝 Equilibrado.');
    const cell = 44.0;
    return SiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(verdict, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(tr('Você ganha {0}, perde {1} e empata {2} de {3} confrontos.')
              .replaceAll('{0}', '$wins')
              .replaceAll('{1}', '$losses')
              .replaceAll('{2}', '${all.length - wins - losses}')
              .replaceAll('{3}', '${all.length}')),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const SizedBox(width: cell),
                  for (final m in theirs.members) SizedBox.square(dimension: cell, child: PokemonSprite(m.$1, fill: 0.9)),
                ]),
                for (var i = 0; i < result.length; i++)
                  Row(children: [
                    SizedBox.square(dimension: cell, child: PokemonSprite(mine.members[i].$1, fill: 0.9)),
                    for (var j = 0; j < result[i].length; j++)
                      Padding(
                        padding: const EdgeInsets.all(2),
                        child: result[i][j] == null
                            ? const SizedBox.square(dimension: cell - 4)
                            : InkWell(
                                onTap: () => _detail(context, i, j, result[i][j]!),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: cell - 4,
                                  height: cell - 4,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: switch (result[i][j]!.result) { 1 => _win, -1 => _lose, _ => _draw }.withAlpha(200),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(_hits(result[i][j]!.mine.hits),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                      ),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text('Linhas: seu time. Colunas: o time do amigo. O número é quantos golpes o seu precisa. Toque num quadrado para ver os golpes.',
              style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
        ],
      ),
    );
  }
}
