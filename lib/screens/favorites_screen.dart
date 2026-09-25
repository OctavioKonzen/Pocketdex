// lib/screens/favorites_screen.dart
//
// Favoritos no estilo do site: cabeçalho com a quantidade e os cards em grade.
// Os favoritos ficam na conta (aparecem no site e em outros aparelhos).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pokemon_listing.dart';
import '../providers/favorites_provider.dart';
import '../utils/app_images.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';
import '../widgets/pokemon_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ids = [...context.watch<FavoritesProvider>().favoritePokemonIds]
      ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
    final favorites = [
      for (final id in ids) PokemonListing(name: 'pokemon-$id', url: 'pokemon/$id/', imageUrl: AppImages.pokemonArtwork(id)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: CustomScrollView(
        key: const PageStorageKey('favorites_scroll'),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: 'Favoritos',
              subtitle: favorites.isEmpty ? null : '${favorites.length} Pokémon · toque duas vezes num card para tirar',
            ),
          ),
          if (favorites.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyMessage(
                  'Você ainda não favoritou nenhum Pokémon.\nToque duas vezes em um card na Pokédex para adicioná-lo!'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: Responsive.columns(context, min: 3),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: favorites.length,
                itemBuilder: (context, index) =>
                    PokemonCard(key: ValueKey(favorites[index].id), pokemonListing: favorites[index]),
              ),
            ),
        ],
      ),
    );
  }
}
