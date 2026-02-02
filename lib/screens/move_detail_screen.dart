// lib/screens/move_detail_screen.dart

import 'package:flutter/material.dart';
import '../models/move.dart';
import '../models/pokemon_listing.dart';
import '../services/pokemon_service.dart';
import '../utils/pokemon_colors.dart';
import '../utils/string_extensions.dart';
import '../widgets/pikachu_loading_indicator.dart';
import '../widgets/pokemon_card.dart';

class MoveDetailScreen extends StatelessWidget {
  final Move move;

  const MoveDetailScreen({super.key, required this.move});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color cardBackgroundColor = getColorForType(move.type);

    return Scaffold(
      appBar: AppBar(
        title: Text(move.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: cardBackgroundColor.withAlpha(200),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      label: Text(move.type.capitalise(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      backgroundColor: cardBackgroundColor,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      move.category == 'physical' ? Icons.sports_mma : move.category == 'special' ? Icons.star : Icons.adjust,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      move.category.capitalise(),
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  move.effect,
                  style: const TextStyle(color: Colors.white, height: 1.5, fontSize: 16),
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white30),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatInfo('Power', move.power?.toString() ?? '--'),
                    _buildStatInfo('Accuracy', move.accuracy != null ? '${move.accuracy}%' : '--'),
                    _buildStatInfo('PP', move.pp?.toString() ?? '--'),
                  ],
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Pokémon que aprendem este Golpe:',
              style: theme.textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<PokemonListing>>(
              future: PokemonService().fetchPokemonWhoLearnMove(move.name),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: PikachuLoadingIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('Nenhum Pokémon encontrado.', style: TextStyle(color: theme.hintColor)));
                }
                final pokemonList = snapshot.data!;
                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
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

  Widget _buildStatInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}