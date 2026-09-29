// lib/widgets/team_set_summary.dart
//
// Resumo dos dados completos de cada Pokémon de um time (apelido, nível,
// item, Tera, habilidade, Nature, EVs e golpes) — igual ao site.

import 'package:flutter/material.dart' hide Text;

import '../services/local_database.dart';
import '../services/team_sets.dart';
import '../utils/site_ui.dart';
import '../utils/string_extensions.dart';
import 'pokemon_sprite.dart';
import 'package:pocket_dex/i18n/text.dart';

class TeamSetSummary extends StatelessWidget {
  final List<int?> slots;
  final List<Map<String, dynamic>?> sets;
  const TeamSetSummary({super.key, required this.slots, required this.sets});

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    return FutureBuilder<Map<int, String>>(
      future: () async {
        final names = <int, String>{};
        for (final id in slots.whereType<int>()) {
          final row = await LocalDatabase.instance.pokemonRow(id);
          if (row != null) names[id] = row['name'] as String;
        }
        return names;
      }(),
      builder: (context, snap) {
        final names = snap.data ?? const {};
        return Column(
          children: [
            for (var i = 0; i < slots.length; i++)
              if (slots[i] != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 64, height: 64, child: PokemonSprite(slots[i]!, fill: 0.85)),
                      const SizedBox(width: 10),
                      Expanded(child: _details(c, names[slots[i]] ?? '', i < sets.length ? sets[i] : null)),
                    ],
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _details(SiteColors c, String name, Map<String, dynamic>? set) {
    final species = name.replaceAll('-', ' ').capitalise();
    final muted = TextStyle(color: c.muted, fontSize: 12);
    if (set == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(species, style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
        Text('Sem detalhes', style: muted),
      ]);
    }
    final nick = set['nickname'] as String;
    final evs = [for (final k in statKeys) if (set['evs'][k] != 0) '${set['evs'][k]} ${statLabels[k]}'].join(' / ');
    final moves = [for (final m in set['moves'] as List) if ((m as String).isNotEmpty) prettySlug(m)].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${nick.isNotEmpty ? '$nick ($species)' : species}${set['shiny'] == true ? ' ✨' : ''}',
            style: TextStyle(color: c.text, fontWeight: FontWeight.bold)),
        Text(
          'Nv. ${set['level']}'
          '${(set['item'] as String).isNotEmpty ? ' · @ ${prettySlug(set['item'])}' : ''}'
          '${(set['tera'] as String).isNotEmpty ? ' · Tera ${prettySlug(set['tera'])}' : ''}',
          style: muted,
        ),
        if ((set['ability'] as String).isNotEmpty) Text(prettySlug(set['ability']), style: muted),
        Text(natureLabel(set['nature'] as String), style: muted),
        if (evs.isNotEmpty) Text('EVs: $evs', style: muted),
        if (moves.isNotEmpty) Text(moves, style: TextStyle(color: c.text, fontSize: 12)),
      ],
    );
  }
}
