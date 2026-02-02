// lib/screens/ev_counter_screen.dart

import 'package:flutter/material.dart';
import 'package:pocket_dex/models/pokemon_details.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/services/training_service.dart';
import 'package:pocket_dex/utils/string_extensions.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:uuid/uuid.dart';

import '../models/training_pokemon.dart';
import 'pokedex_screen.dart';
import 'ev_tracking_screen.dart';

class EvCounterScreen extends StatefulWidget {
  const EvCounterScreen({super.key});

  @override
  State<EvCounterScreen> createState() => _EvCounterScreenState();
}

class _EvCounterScreenState extends State<EvCounterScreen> {
  final TrainingService _trainingService = TrainingService();
  List<TrainingPokemon> _trainingPokemon = [];
  bool _isLoading = true;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadTrainingPokemon();
  }

  Future<void> _loadTrainingPokemon() async {
    final savedList = await _trainingService.getTrainingList();
    if (mounted) {
      setState(() {
        _trainingPokemon = savedList;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveTrainingList() async {
    await _trainingService.saveTrainingList(_trainingPokemon);
  }

  Future<void> _addPokemonToTraining() async {
    final selectedPokemon = await Navigator.push<Map<String, String>?>(
      context,
      MaterialPageRoute(
        builder: (context) => const PokedexScreen(isForTeamSelection: true),
      ),
    );

    if (!mounted || selectedPokemon == null) return;

    final PokemonDetails details =
        await PokemonService().fetchPokemonDetails(int.parse(selectedPokemon['id']!));
    final pokemonName = details.name;

    setState(() {
      _trainingPokemon.add(
        TrainingPokemon(
          id: _uuid.v4(),
          pokemonId: selectedPokemon['id']!,
          pokemonName: pokemonName,
          imageUrl: selectedPokemon['imageUrl']!,
        ),
      );
    });
    await _saveTrainingList();
  }

  Future<void> _removePokemon(String trainingId) async {
    setState(() {
      _trainingPokemon.removeWhere((p) => p.id == trainingId);
    });
    await _saveTrainingList();
  }

  Future<void> _navigateToTracking(TrainingPokemon pokemon) async {
    final result = await Navigator.push<TrainingPokemon>(
      context,
      MaterialPageRoute(builder: (context) => EvTrackingScreen(pokemon: pokemon)),
    );

    if (result != null && mounted) {
      setState(() {
        final index = _trainingPokemon.indexWhere((p) => p.id == result.id);
        if (index != -1) {
          _trainingPokemon[index] = result;
        }
      });
      await _saveTrainingList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contador de EVs'),
      ),
      body: _isLoading
          ? const PikachuLoadingIndicator()
          : _trainingPokemon.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Nenhum Pokémon em treinamento.\nClique no "+" para adicionar.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _trainingPokemon.length,
                  itemBuilder: (context, index) {
                    final pokemon = _trainingPokemon[index];
                    return _TrainingPokemonCard(
                      pokemon: pokemon,
                      onTap: () => _navigateToTracking(pokemon),
                      onDelete: () => _removePokemon(pokemon.id),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPokemonToTraining,
        backgroundColor: Colors.green.shade600,
        tooltip: 'Adicionar Pokémon',
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }
}

class _TrainingPokemonCard extends StatelessWidget {
  final TrainingPokemon pokemon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TrainingPokemonCard({
    required this.pokemon,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Image.network(
                pokemon.imageUrl,
                width: 70,
                height: 70,
                loadingBuilder: (context, child, progress) {
                  return progress == null
                      ? child
                      : const PikachuLoadingIndicator(size: 40);
                },
                errorBuilder: (context, error, stack) =>
                    Icon(Icons.error, size: 50, color: theme.hintColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pokemon.pokemonName.capitalise(),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total EVs: ${pokemon.totalEVs}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
                tooltip: 'Remover Pokémon',
              )
            ],
          ),
        ),
      ),
    );
  }
}