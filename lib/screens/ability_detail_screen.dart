// lib/screens/ability_detail_screen.dart
import 'package:flutter/material.dart';
import '../models/ability.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../widgets/pokemon_card.dart';
import '../widgets/pikachu_loading_indicator.dart';

class AbilityDetailScreen extends StatelessWidget {
  final Ability ability;

  const AbilityDetailScreen({super.key, required this.ability});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final PokemonService pokemonService = PokemonService();
    return Scaffold(
      appBar: AppBar(
        title: Text(ability.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(ability.description, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Pokémon com esta Habilidade:', style: theme.textTheme.titleLarge),
          ),
          Expanded(
            child: FutureBuilder<List<PokemonListing>>(
              future: pokemonService.fetchPokemonWithAbility(ability.name),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: PikachuLoadingIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Nenhum Pokémon encontrado.', style: TextStyle(color: theme.hintColor)));
                }
                final pokemonList = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8,
                  ),
                  itemCount: pokemonList.length,
                  itemBuilder: (context, index) {
                    return PokemonCard(pokemonListing: pokemonList[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}