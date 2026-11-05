// lib/screens/tools/tera_raid_screen.dart
//
// Guia de Tera Raids (igual ao site, TeraRaid.jsx): escolhe o chefe e o tipo
// Tera dele e vê os melhores Pokémon para a raid. Na raid o chefe só tem o
// tipo Tera na defesa, mas ataca com os tipos dele e com o Tera; os melhores
// atacantes batem super efetivo no Tera com o próprio tipo (STAB), têm ataque
// alto e resistem aos golpes do chefe.

import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;

import '../../i18n/i18n.dart';
import '../../i18n/text.dart';
import '../../services/battle.dart';
import '../../services/damage_calc.dart';
import '../../services/local_database.dart';
import '../../utils/pokemon_colors.dart';
import '../../utils/responsive.dart';
import '../../utils/site_ui.dart';
import '../../utils/string_extensions.dart';
import '../../widgets/pokemon_sprite.dart';
import '../../widgets/type_chip.dart';
import '../pokedex_screen.dart';
import '../pokemon_detail_screen.dart';

/// Um atacante sugerido: id, nome, tipo do STAB que bate no Tera, multiplicador
/// do ataque, pior multiplicador que ele leva do chefe e a nota.
class RaidPick {
  final int id;
  final String name;
  final String attackType;
  final double offense, taken, score;
  const RaidPick(this.id, this.name, this.attackType, this.offense, this.taken, this.score);
}

/// Melhores atacantes contra um chefe com [bossTypes] e Tera [tera].
List<RaidPick> teraRaidPicks({
  required List<Map<String, dynamic>> rows,
  required Map<String, Map<String, List<String>>> chart,
  required List<String> bossTypes,
  required String tera,
  bool Function(Map<String, dynamic> row)? allowed,
  int count = 24,
}) {
  final bossAttacks = {...bossTypes, tera};
  final picks = <RaidPick>[];
  for (final r in rows) {
    if (allowed != null && !allowed(r)) continue;
    final types = (r['types'] as List).cast<String>();
    final stats = [for (final s in r['stats'] as List) (s as List).first as int];
    var offense = 0.0;
    var attackType = types.first;
    for (final t in types) {
      final e = Battle.effectiveness(t, [tera], chart);
      if (e > offense) {
        offense = e;
        attackType = t;
      }
    }
    if (offense < 2) continue; // só quem bate super efetivo com o próprio tipo
    final taken = bossAttacks.map((b) => Battle.effectiveness(b, types, chart)).reduce(math.max);
    final attack = math.max(stats[1], stats[3]);
    final bulk = stats[0] + (stats[2] + stats[4]) / 2;
    final score = offense * attack * (bulk / 100) / math.max(taken, 0.25);
    picks.add(RaidPick(r['id'] as int, r['name'] as String, attackType, offense, taken, score));
  }
  picks.sort((a, b) => b.score.compareTo(a.score));
  return picks.take(count).toList();
}

class TeraRaidScreen extends StatefulWidget {
  const TeraRaidScreen({super.key});

  @override
  State<TeraRaidScreen> createState() => _TeraRaidScreenState();
}

class _TeraRaidScreenState extends State<TeraRaidScreen> {
  int? _boss;
  String _bossName = '';
  List<String> _bossTypes = const [];
  String? _tera;
  List<RaidPick>? _picks;

  Future<void> _pickBoss() async {
    final picked = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const PokedexScreen(isForTeamSelection: true)),
    );
    final id = int.tryParse('${picked?['id']}');
    if (id == null) return;
    final row = await LocalDatabase.instance.pokemonRow(id);
    if (row == null) return;
    setState(() {
      _boss = id;
      _bossName = I18n.pokemonName((row['name'] as String).replaceAll('-', ' ').capitalise());
      _bossTypes = (row['types'] as List).cast<String>();
      _tera ??= _bossTypes.first;
    });
    _calc();
  }

  Future<void> _calc() async {
    final tera = _tera;
    if (_boss == null || tera == null) return;
    final data = await DamageData.load();
    final rows = await LocalDatabase.instance.defaultPokemon();
    final species = await LocalDatabase.instance.speciesById();
    final chart = await LocalDatabase.instance.typeChart();
    bool allowed(Map<String, dynamic> r) {
      final s = species[r['id']];
      if (s?['is_legendary'] == true || s?['is_mythical'] == true) return false;
      return !(data.species[toId(data.speciesName(r['name'] as String))]?.nfe ?? false);
    }

    final picks = teraRaidPicks(rows: rows, chart: chart, bossTypes: _bossTypes, tera: tera, allowed: allowed);
    if (mounted) setState(() => _picks = picks);
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final picks = _picks;
    return Scaffold(
      appBar: AppBar(title: const Text('Tera Raids')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Escolha o chefe da raid e o tipo Tera dele para ver os melhores Pokémon para levar.',
                style: TextStyle(color: c.muted, fontSize: 13)),
            const SizedBox(height: 12),
            SiteCard(
              onTap: _pickBoss,
              child: Row(children: [
                SizedBox.square(
                    dimension: 64, child: _boss == null ? const Icon(Icons.catching_pokemon, size: 40) : PokemonSprite(_boss!, fill: 0.95)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_boss == null ? tr('Escolher o chefe') : _bossName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_bossTypes.isNotEmpty) ...[const SizedBox(height: 4), TypeChips(_bossTypes)],
                  ]),
                ),
                const Icon(Icons.chevron_right),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('Tipo Tera do chefe', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in pokemonTypeColors.keys)
                  GestureDetector(
                    onTap: () {
                      setState(() => _tera = t);
                      _calc();
                    },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _tera == null || _tera == t ? 1 : 0.45,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: getColorForType(t),
                          borderRadius: BorderRadius.circular(12),
                          border: _tera == t ? Border.all(color: Colors.white, width: 2) : null,
                        ),
                        child: Text(t.capitalise(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (picks != null && picks.isEmpty) const EmptyMessage('Nenhum Pokémon bate super efetivo nesse Tera com o próprio tipo.'),
            if (picks != null && picks.isNotEmpty) ...[
              Text(tr('Melhores para a raid contra {0} Tera {1}').replaceAll('{0}', _bossName).replaceAll('{1}', _tera!.capitalise()),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              for (final p in picks)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PokemonDetailScreen(initialPokemonId: p.id))),
                    leading: SizedBox.square(dimension: 48, child: PokemonSprite(p.id, fill: 0.95)),
                    title: Text(I18n.pokemonName(p.name.replaceAll('-', ' ').capitalise()), style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      TypeChip(p.attackType),
                      Text('${p.offense == 4 ? '4×' : '2×'} · '),
                      Text(p.taken < 1
                          ? tr('resiste ao chefe')
                          : p.taken > 1
                              ? tr('leva super efetivo do chefe')
                              : tr('dano normal do chefe')),
                    ]),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
