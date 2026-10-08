// lib/screens/official_teams_screen.dart
//
// Times dos personagens (igual ao site): os times oficiais dos líderes,
// Elite Four, campeões, vilões e rivais, exatamente como estão nos jogos
// (nível, golpes, item, IVs/DVs, EVs, nature e habilidade). Separados por
// jogo; ao abrir um personagem aparecem todas as lutas dele em todos os jogos.

import 'package:flutter/material.dart' hide Text;

import '../services/local_database.dart';
import '../services/official_teams.dart';
import '../services/team_sets.dart';
import '../services/trainers.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/trainer_sprite.dart';
import 'package:pocket_dex/i18n/text.dart';

typedef _Data = ({List<OfficialGame> games, Map<int, String> names, Map<String, Trainer> trainers});

Future<_Data> _loadData() async {
  final games = await OfficialTeams.load();
  final rows = await LocalDatabase.instance.allPokemonRows();
  final trainers = await Trainers.load();
  return (
    games: games,
    names: {for (final r in rows) (r['id'] as num).toInt(): (r['name'] as String).replaceAll('-', ' ').capitalise()},
    trainers: {for (final t in trainers) t.id: t},
  );
}

class OfficialTeamsScreen extends StatefulWidget {
  const OfficialTeamsScreen({super.key});

  @override
  State<OfficialTeamsScreen> createState() => _OfficialTeamsScreenState();
}

class _OfficialTeamsScreenState extends State<OfficialTeamsScreen> {
  final _data = _loadData();
  String? _gameId;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Times dos personagens')),
      body: ReadableWidth(
        child: FutureBuilder<_Data>(
          future: _data,
          builder: (context, snap) {
            final data = snap.data;
            if (data == null) return const Center(child: CircularProgressIndicator());
            final game = data.games.firstWhere((g) => g.id == _gameId, orElse: () => data.games.first);
            final list = game.filter(_query);
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const PageHeader(
                  title: 'Times dos personagens',
                  subtitle: 'Os times oficiais dos jogos: nível, golpes, item, IVs, EVs, nature e habilidade de cada Pokémon, em todas as lutas.',
                ),
                for (final gen in {for (final g in data.games) g.generation})
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: Row(children: [
                      SizedBox(width: 78, child: Text('$genª geração', style: TextStyle(color: c.muted, fontSize: 12))),
                      Expanded(
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final g in data.games.where((g) => g.generation == gen))
                            _GameChip(label: g.name, selected: g.id == game.id, onTap: () => setState(() => _gameId = g.id)),
                        ]),
                      ),
                    ]),
                  ),
                if (game.community)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      '📖 ${game.name}: dados da comunidade (calculadoras de Nuzlocke, tirados dos jogos por fãs). Podem ter pequenas diferenças do jogo.',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SiteSearchField(hint: 'Buscar personagem ou classe', onChanged: (t) => setState(() => _query = t)),
                ),
                if (list.isEmpty) EmptyMessage('Ninguém com esse nome em ${game.name}.'),
                for (final t in list)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: SiteCard(
                      padding: const EdgeInsets.all(10),
                      radius: 18,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => _TrainerScreen(data: data, name: t.name, gameId: game.id)),
                      ),
                      child: Row(children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: data.trainers[t.trainer] == null ? null : TrainerSprite(data.trainers[t.trainer]!, box: 64, still: true),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t.name, style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
                            Text('${t.trainerClass} · ${t.battles.length} ${t.battles.length == 1 ? 'luta' : 'lutas'}',
                                style: TextStyle(color: c.muted, fontSize: 12)),
                            const SizedBox(height: 2),
                            Wrap(children: [
                              for (final m in t.battles.last.team) SizedBox(width: 30, height: 30, child: PokemonSprite(m.id, fill: 0.9)),
                            ]),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'Dados tirados do código dos jogos: da 1ª à 4ª geração pelos projetos de desmontagem do pret (github.com/pret), Black 2/White 2 pela desmontagem pokebw2 e Scarlet/Violet (versão 1.0, sem as DLCs) pelos arquivos do jogo. Os outros jogos (marcados com 📖) vêm dos dados de treinadores do Trevenant/VanillaNuzlockeCalc, feitos pela comunidade.',
                    style: TextStyle(color: c.muted, fontSize: 11),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GameChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return Material(
      color: selected ? SectionColors.teams : c.surface,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: selected ? Colors.white : c.text)),
        ),
      ),
    );
  }
}

/// Todas as aparições do personagem: um botão por jogo e as lutas daquele jogo.
class _TrainerScreen extends StatefulWidget {
  final _Data data;
  final String name, gameId;
  const _TrainerScreen({required this.data, required this.name, required this.gameId});

  @override
  State<_TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<_TrainerScreen> {
  late final _all = OfficialTeams.appearances(widget.data.games, widget.name);
  late int _pick = _all.indexWhere((a) => a.game.id == widget.gameId).clamp(0, _all.length - 1);

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final current = _all[_pick];
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_all.length > 1) ...[
              Text('Todas as aparições:', style: TextStyle(color: c.muted, fontSize: 12)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (var i = 0; i < _all.length; i++)
                  _GameChip(
                    label: '${_all[i].game.name} · ${_all[i].trainer.trainerClass}',
                    selected: i == _pick,
                    onTap: () => setState(() => _pick = i),
                  ),
              ]),
              const SizedBox(height: 12),
            ],
            Text('${current.trainer.trainerClass} em ${current.game.name} (${current.game.region})', style: TextStyle(color: c.muted, fontSize: 13)),
            for (final battle in current.trainer.battles) ...[
              const SizedBox(height: 14),
              Text(battle.label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c.text)),
              const SizedBox(height: 8),
              for (final mon in battle.team) _MonCard(mon: mon, name: widget.data.names[mon.id] ?? ''),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonCard extends StatelessWidget {
  final OfficialMon mon;
  final String name;
  const _MonCard({required this.mon, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final muted = TextStyle(color: c.muted, fontSize: 12);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 64, height: 64, child: PokemonSprite(mon.id, fill: 0.85)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$name${mon.shiny ? ' ✨' : ''}', style: TextStyle(fontWeight: FontWeight.bold, color: c.text)),
            Text('Nv. ${mon.level}${mon.item != null ? ' · @ ${prettySlug(mon.item!)}' : ''}${mon.tera != null ? ' · Tera ${prettySlug(mon.tera!)}' : ''}',
                style: muted),
            if (mon.abilityText(prettySlug) != null) Text(mon.abilityText(prettySlug)!, style: muted),
            if (mon.nature != null)
              Text(natureLabel(mon.nature!), style: muted)
            else if (mon.dv == null)
              Text('Nature sorteada', style: muted),
            Text(mon.ivText, style: muted),
            Text(mon.evText, style: muted),
            Text(mon.moves.map(prettySlug).join(' · '), style: TextStyle(color: c.text, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
