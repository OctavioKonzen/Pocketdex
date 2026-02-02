// lib/screens/ev_tracking_screen.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import 'package:pocket_dex/models/pokemon_listing.dart';
import 'package:pocket_dex/screens/ev_yield_pokemon_selection_screen.dart';
import 'package:pocket_dex/utils/string_extensions.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';

import '../models/training_pokemon.dart';

class EvTrackingScreen extends StatefulWidget {
  final TrainingPokemon pokemon;

  const EvTrackingScreen({super.key, required this.pokemon});

  @override
  State<EvTrackingScreen> createState() => _EvTrackingScreenState();
}

class _EvTrackingScreenState extends State<EvTrackingScreen> {
  late TrainingPokemon _currentPokemon;

  @override
  void initState() {
    super.initState();
    _currentPokemon = TrainingPokemon.fromMap(widget.pokemon.toMap());
  }

  Future<Map<String, int>> _fetchEvYield(String pokemonId) async {
    final evYields = <String, int>{};
    try {
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'));
      if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final statsData = data['stats'] as List;
          for (var statInfo in statsData) {
              if (statInfo['effort'] > 0) {
                  String statName = statInfo['stat']['name'];
                  evYields[statName] = (statInfo['effort'] as num).toInt();
              }
          }
      }
    } catch (e) {
      return {};
    }
    return evYields;
  }

  Future<void> _addDefeatedPokemon() async {
    final selectedPokemon = await Navigator.push<PokemonListing>(
      context,
      MaterialPageRoute(
        builder: (context) => const EvYieldPokemonSelectionScreen(),
      ),
    );

    if (selectedPokemon == null || !mounted) return;
    
    final evs = await _fetchEvYield(selectedPokemon.id);

    if (!mounted) return;

    if (evs.isNotEmpty) {
      setState(() {
        _currentPokemon.hpEVs += evs['hp'] ?? 0;
        _currentPokemon.attackEVs += evs['attack'] ?? 0;
        _currentPokemon.defenseEVs += evs['defense'] ?? 0;
        _currentPokemon.spAttackEVs += evs['special-attack'] ?? 0;
        _currentPokemon.spDefenseEVs += evs['special-defense'] ?? 0;
        _currentPokemon.speedEVs += evs['speed'] ?? 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Dados de EV não encontrados para ${selectedPokemon.name.capitalise()}')));
    }
  }

  void _resetEVs() {
    setState(() {
      _currentPokemon.hpEVs = 0;
      _currentPokemon.attackEVs = 0;
      _currentPokemon.defenseEVs = 0;
      _currentPokemon.spAttackEVs = 0;
      _currentPokemon.spDefenseEVs = 0;
      _currentPokemon.speedEVs = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;
        Navigator.of(context).pop(_currentPokemon);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Treino de ${_currentPokemon.pokemonName.capitalise()}'),
          leading: BackButton(
            onPressed: () {
              Navigator.of(context).pop(_currentPokemon);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Resetar EVs',
              onPressed: _resetEVs,
            )
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          child: Column(
            children: [
              Image.network(
                _currentPokemon.imageUrl,
                height: 150,
                errorBuilder: (c, e, s) =>
                    Icon(Icons.error, size: 120, color: theme.hintColor),
                loadingBuilder: (c, child, progress) => progress == null
                    ? child
                    : const PikachuLoadingIndicator(size: 100),
              ),
              const SizedBox(height: 16),
              Text(
                'Total EVs: ${_currentPokemon.totalEVs} / 510',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 24),
              _buildEvGrid(theme),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addDefeatedPokemon,
          backgroundColor: Colors.green.shade600,
          icon: const Icon(Icons.add),
          label: const Text('Adicionar Pokémon Derrotado'),
        ),
      ),
    );
  }

  Widget _buildEvGrid(ThemeData theme) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _EVStatTile(
            label: 'HP', value: _currentPokemon.hpEVs, color: Colors.green, theme: theme),
        _EVStatTile(
            label: 'Attack',
            value: _currentPokemon.attackEVs,
            color: Colors.red, theme: theme),
        _EVStatTile(
            label: 'Defense',
            value: _currentPokemon.defenseEVs,
            color: Colors.blue, theme: theme),
        _EVStatTile(
            label: 'Sp. Atk',
            value: _currentPokemon.spAttackEVs,
            color: Colors.purple, theme: theme),
        _EVStatTile(
            label: 'Sp. Def',
            value: _currentPokemon.spDefenseEVs,
            color: Colors.yellow.shade700, theme: theme),
        _EVStatTile(
            label: 'Speed',
            value: _currentPokemon.speedEVs,
            color: Colors.pink, theme: theme),
      ],
    );
  }
}

class _EVStatTile extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ThemeData theme;

  const _EVStatTile(
      {required this.label, required this.value, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: theme.textTheme.titleMedium),
          Text(value.toString(),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}