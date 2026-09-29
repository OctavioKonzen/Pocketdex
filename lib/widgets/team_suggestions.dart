// lib/widgets/team_suggestions.dart
//
// Sugestões para completar o time: Pokémon que aguentam as fraquezas do time
// e acertam os tipos que ele ainda não cobre (os mesmos do site).

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';
import '../utils/team_analysis.dart';
import 'pokemon_sprite.dart';

class TeamSuggestionsView extends StatelessWidget {
  final List<TeamSuggestion> suggestions;
  final ValueChanged<int> onAdd;
  const TeamSuggestionsView({super.key, required this.suggestions, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const Text('Sugestões para completar o time', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('Aguentam as fraquezas do time e acertam tipos que ele ainda não cobre.',
            style: TextStyle(color: theme.hintColor, fontSize: 12)),
        const SizedBox(height: 8),
        for (final s in suggestions)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.onSurface.withAlpha(15), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                SizedBox(width: 52, height: 52, child: PokemonSprite(s.pokemon['id'] as int)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(I18n.pokemonName((s.pokemon['name'] as String).split('-').first.capitalise()),
                              overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        for (final t in (s.pokemon['types'] as List).cast<String>())
                          Container(
                            margin: const EdgeInsets.only(left: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: getColorForType(t), borderRadius: BorderRadius.circular(10)),
                            child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ]),
                      if (s.resists.isNotEmpty)
                        Text(tr('Aguenta: {0}').replaceAll('{0}', s.resists.join(', ')),
                            style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 12)),
                      if (s.covers.isNotEmpty)
                        Text(tr('Acerta: {0}').replaceAll('{0}', s.covers.join(', ')),
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: () => onAdd(s.pokemon['id'] as int),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                  child: const Text('+ Adicionar'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
