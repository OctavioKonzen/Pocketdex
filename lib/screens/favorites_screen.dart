// lib/screens/favorites_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/pokemon_listing.dart';
import '../providers/favorites_provider.dart';
import '../widgets/pokemon_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final favoritesProvider = context.watch<FavoritesProvider>();
    final favoriteIds = favoritesProvider.favoritePokemonIds;
    favoriteIds.sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    final List<PokemonListing> favoriteListings = favoriteIds.map((id) {
      return PokemonListing(
        name: 'pokemon-$id', 
        url: 'https://pokeapi.co/api/v2/pokemon/$id/',
        imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png'
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: favoriteListings.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Você ainda não favoritou nenhum Pokémon.\nDê um duplo clique em um card na Pokédex para adicioná-lo!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color
                    ),
                  ),
                ),
              )
            : GridView.builder(
                key: const PageStorageKey('favorites_grid'),
                padding: const EdgeInsets.only(top: 12.0, bottom: 20.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.8,
                ),
                itemCount: favoriteListings.length,
                itemBuilder: (context, index) {
                  final pokemon = favoriteListings[index];
                  return PokemonCard(
                    key: ValueKey(pokemon.id),
                    pokemonListing: pokemon,
                  );
                },
              ),
      ),
    );
  }
}