// lib/widgets/team_suggestions.dart
//
// Sugestões para completar o time: Pokémon que aguentam as fraquezas do time
// e acertam os tipos que ele ainda não cobre (os mesmos do site).

import 'package:flutter/material.dart' hide Text;

import '../i18n/i18n.dart';
import '../i18n/text.dart';
import '../utils/string_extensions.dart';
import '../utils/team_analysis.dart';
import 'pokemon_sprite.dart';
import 'type_chip.dart';

/// "Aguenta: [fire] [ground]" com os tipos na cor de cada um.
Widget _typeLine(String label, Color color, List<String> types) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('${tr(label)}:', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          for (final t in types) TypeChip(t),
        ],
      ),
    );

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
                        const SizedBox(width: 6),
                        TypeChips((s.pokemon['types'] as List).cast<String>()),
                      ]),
                      if (s.resists.isNotEmpty) _typeLine('Aguenta', const Color(0xFF4ADE80), s.resists),
                      if (s.covers.isNotEmpty) _typeLine('Acerta', const Color(0xFF38BDF8), s.covers),
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
