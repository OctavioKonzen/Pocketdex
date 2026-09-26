// lib/screens/community_teams_screen.dart
//
// Times da comunidade (igual ao site): todos os times de quem tem conta
// aparecem aqui. Pesquise pelo nome da pessoa para ver os times dela, dê sua
// nota (1 a 5 estrelas) e salve uma cópia nos seus times. Se o dono excluir
// o time, ele some daqui.

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_sync.dart';
import '../services/auth_service.dart';
import '../services/local_database.dart';
import '../services/team_service.dart';
import '../services/team_share.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/team_analysis.dart';
import '../widgets/account_avatar.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/team_analysis_view.dart';
import 'team_builder_screen.dart';

Color _teamColor(Object? color) {
  if (color is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color)) {
    return Color(int.parse('FF${color.substring(1)}', radix: 16));
  }
  return SectionColors.teams;
}

List<int?> _slots(Map<String, dynamic> team) {
  final p = (team['pokemon'] as List?) ?? [];
  return [for (var i = 0; i < 6; i++) i < p.length ? (p[i] as num?)?.toInt() : null];
}

class CommunityTeamsScreen extends StatefulWidget {
  const CommunityTeamsScreen({super.key});
  @override
  State<CommunityTeamsScreen> createState() => _CommunityTeamsScreenState();
}

class _CommunityTeamsScreenState extends State<CommunityTeamsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>>? _list;
  String _searched = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _load(text.trim()));
  }

  Future<void> _load(String name) async {
    setState(() {
      _list = null;
      _error = null;
    });
    try {
      final list = await AccountSync.instance.searchPublicTeams(name);
      if (!mounted || _search.text.trim() != name) return;
      setState(() {
        _list = list;
        _searched = name;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Não foi possível carregar os times agora.');
    }
  }

  void _searchOwner(String name) {
    _search.text = name;
    _load(name);
  }

  Future<void> _open(Map<String, dynamic> team) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => _PublicTeamScreen(team: team)),
    );
    if (!mounted || _list == null) return;
    if (result == null) {
      _load(_searched); // o dono excluiu ou o time foi salvo: recarrega a lista
    } else {
      setState(() => _list = [for (final t in _list!) t['id'] == team['id'] ? result : t]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final me = AuthService.instance.user?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Times da comunidade')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const PageHeader(
              title: 'Times da comunidade',
              subtitle: 'Veja os times de outros treinadores, dê sua nota e salve os que gostar.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SiteSearchField(
                controller: _search,
                hint: 'Pesquisar pelo nome do treinador',
                onChanged: _onChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(_searched.isEmpty ? 'Times mais recentes' : 'Times de “$_searched”',
                  style: TextStyle(color: c.muted, fontSize: 13)),
            ),
            if (_error != null)
              EmptyMessage(_error!)
            else if (_list == null)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_list!.isEmpty)
              EmptyMessage(_searched.isEmpty
                  ? 'Ninguém publicou times ainda.'
                  : 'Nenhum treinador com esse nome ou ele ainda não tem times.')
            else
              for (final team in _list!)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SiteCard(
                    onTap: () => _open(team),
                    accentLeft: _teamColor(team['color']),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${team['name']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: c.text, fontWeight: FontWeight.bold, fontSize: 17)),
                                  RatingText(rating: team['rating'] as double?, count: team['ratingCount'] as int),
                                  if (team['ownerUid'] == me && ((team['reportCount'] as num?) ?? 0) >= AccountSync.reportLimit)
                                    const Text('Oculto para os outros por denúncias',
                                        style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => _searchOwner('${team['ownerName']}'),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
                                decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(30)),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    PlayerAvatar(pokemonId: (team['avatar'] as num?)?.toInt(), name: '${team['ownerName']}', size: 26),
                                    const SizedBox(width: 6),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 100),
                                      child: Text(team['ownerUid'] == me ? 'Você' : '${team['ownerName']}',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: c.text, fontWeight: FontWeight.w600, fontSize: 13)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _SpriteRow(slots: _slots(team)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SpriteRow extends StatelessWidget {
  final List<int?> slots;
  const _SpriteRow({required this.slots});
  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Row(
      children: [
        for (final id in slots)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle),
                  child: id == null ? null : PokemonSprite(id, fill: 0.8),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Um time da comunidade: análise, nota (estrelas) e "Salvar nos meus times".
/// Ao voltar devolve o time atualizado (ou null se o dono excluiu).
class _PublicTeamScreen extends StatefulWidget {
  final Map<String, dynamic> team;
  const _PublicTeamScreen({required this.team});
  @override
  State<_PublicTeamScreen> createState() => _PublicTeamScreenState();
}

class _PublicTeamScreenState extends State<_PublicTeamScreen> {
  late Map<String, dynamic>? _team = widget.team;
  TeamAnalysis? _analysis;
  int? _vote;
  String? _message;
  String? _reported;

  Future<void> _report() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Denunciar time', style: TextStyle(fontWeight: FontWeight.bold))),
            for (final r in ['Nome ofensivo', 'Spam', 'Outro'])
              ListTile(leading: const Icon(Icons.flag_outlined), title: Text(r), onTap: () => Navigator.pop(sheet, r)),
          ],
        ),
      ),
    );
    if (reason == null) return;
    try {
      await AccountSync.instance.reportTeam(widget.team['id'] as String, reason);
      if (mounted) setState(() => _reported = 'Denúncia enviada. Obrigado por ajudar a manter a comunidade legal!');
    } catch (e) {
      if (mounted) setState(() => _reported = e is StateError ? e.message : 'Não foi possível denunciar agora.');
    }
  }

  bool get _mine => widget.team['ownerUid'] == AuthService.instance.user?.uid;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sync = AccountSync.instance;
    // Confere se o dono não excluiu o time.
    try {
      final fresh = await sync.publicTeam(widget.team['id'] as String);
      if (!mounted) return;
      if (fresh == null) {
        setState(() => _team = null);
        return;
      }
      setState(() => _team = fresh);
    } catch (_) {}
    if (!_mine) {
      try {
        final v = await sync.myVote(widget.team['id'] as String);
        if (mounted) setState(() => _vote = v);
      } catch (_) {}
    }
    final db = LocalDatabase.instance;
    final types = <List<String>>[];
    for (final id in _slots(_team ?? widget.team)) {
      if (id == null) continue;
      final row = await db.pokemonRow(id);
      if (row != null) types.add((row['types'] as List).cast<String>());
    }
    final chart = await db.typeChart();
    if (mounted) setState(() => _analysis = TeamAnalysis.of(types, chart));
  }

  Future<void> _rate(int stars) async {
    setState(() => _message = null);
    try {
      final (rating, count) = await AccountSync.instance.rateTeam(widget.team['id'] as String, stars);
      if (!mounted) return;
      setState(() {
        _vote = stars;
        _team = {..._team!, 'rating': rating, 'ratingCount': count};
        _message = 'Obrigado pela nota!';
      });
    } catch (e) {
      if (mounted) setState(() => _message = e is StateError ? e.message : 'Não foi possível votar agora.');
    }
  }

  Future<void> _save() async {
    final team = _team!;
    final saved = await TeamService().importTeam(
      SharedTeam('${team['name']} (${team['ownerName']})', team['color'] as String?, _slots(team)),
    );
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => TeamBuilderScreen(team: saved)));
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final team = _team;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _team);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(team == null ? 'Time' : '${team['name']}')),
        body: team == null
            ? const EmptyMessage('Esse time foi excluído pelo dono.')
            : ReadableWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: [
                    SiteCard(
                      accentLeft: _teamColor(team['color']),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              PlayerAvatar(pokemonId: (team['avatar'] as num?)?.toInt(), name: '${team['ownerName']}'),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_mine ? 'Seu time' : 'Time de ${team['ownerName']}',
                                    style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                              ),
                              RatingText(rating: team['rating'] as double?, count: team['ratingCount'] as int),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _SpriteRow(slots: _slots(team)),
                        ],
                      ),
                    ),
                    if (!_mine) ...[
                      const SizedBox(height: 12),
                      SiteCard(
                        child: Column(
                          children: [
                            Text(_vote == null ? 'Dê sua nota' : 'Sua nota',
                                style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            StarRating(value: (_vote ?? 0).toDouble(), onRate: _rate, size: 38),
                            if (_message != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(_message!, style: const TextStyle(color: Colors.greenAccent)),
                              ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SiteCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Análise do time', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _analysis == null
                              ? const Center(child: CircularProgressIndicator())
                              : TeamAnalysisView(analysis: _analysis),
                        ],
                      ),
                    ),
                    if (!_mine) ...[
                      const SizedBox(height: 16),
                      PillButton(label: 'Salvar nos meus times', color: SectionColors.teams, expand: true, onPressed: _save),
                      const SizedBox(height: 8),
                      Center(
                        child: _reported != null
                            ? Text(_reported!, textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 13))
                            : TextButton.icon(
                                onPressed: _report,
                                icon: const Icon(Icons.flag_outlined, size: 18),
                                label: const Text('Denunciar'),
                                style: TextButton.styleFrom(foregroundColor: c.muted),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
