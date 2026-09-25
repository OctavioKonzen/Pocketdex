// lib/screens/ev_counter_screen.dart

import 'package:flutter/material.dart';
import 'package:pocket_dex/models/pokemon_details.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/services/training_service.dart';
import 'package:pocket_dex/utils/string_extensions.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:uuid/uuid.dart';

import '../models/training_pokemon.dart';
import '../services/user_data.dart';
import 'pokedex_screen.dart';
import 'ev_tracking_screen.dart';
import 'package:pocket_dex/utils/responsive.dart';
import 'package:pocket_dex/services/account_format.dart';
import 'package:pocket_dex/utils/site_ui.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';

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
    // Mudanças vindas da conta (site ou outro aparelho) aparecem na hora.
    UserData.instance.addListener(_onUserData);
    _loadTrainingPokemon();
  }

  void _onUserData() {
    if (mounted) _loadTrainingPokemon();
  }

  @override
  void dispose() {
    UserData.instance.removeListener(_onUserData);
    super.dispose();
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

    final PokemonDetails details = await PokemonService()
        .fetchPokemonDetails(int.parse(selectedPokemon['id']!));
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
      MaterialPageRoute(
          builder: (context) => EvTrackingScreen(pokemon: pokemon)),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Contador de EVs')),
      body: ReadableWidth(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            PageHeader(
              title: 'Contador de EVs',
              subtitle: 'Acompanhe o treino dos seus Pokémon (máx. 252 por atributo e 510 no total).',
              action: PillButton(label: '+ Adicionar', color: const Color(0xFF66BB6A), onPressed: _addPokemonToTraining),
            ),
            if (_isLoading)
              const PikachuLoadingIndicator()
            else if (_trainingPokemon.isEmpty)
              const EmptyMessage('Nenhum Pokémon em treinamento. Toque em “Adicionar” para começar.')
            else
              for (final pokemon in _trainingPokemon)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _TrainingPokemonCard(
                    pokemon: pokemon,
                    onTap: () => _navigateToTracking(pokemon),
                    onDelete: () => _removePokemon(pokemon.id),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _TrainingPokemonCard extends StatelessWidget {
  final TrainingPokemon pokemon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _TrainingPokemonCard({required this.pokemon, required this.onTap, required this.onDelete});

  // Mesmas cores do site para cada atributo.
  static const _stats = [
    ('HP', Color(0xFF4CAF50)),
    ('Atk', Color(0xFFF44336)),
    ('Def', Color(0xFF2196F3)),
    ('SpA', Color(0xFF9C27B0)),
    ('SpD', Color(0xFFFBC02D)),
    ('Spe', Color(0xFFE91E63)),
  ];

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final values = [
      pokemon.hpEVs, pokemon.attackEVs, pokemon.defenseEVs,
      pokemon.spAttackEVs, pokemon.spDefenseEVs, pokemon.speedEVs,
    ];
    final id = AccountFormat.pokemonIdFromImage(pokemon.imageUrl) ?? int.tryParse(pokemon.pokemonId) ?? 0;
    return SiteCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(width: 64, height: 64, child: PokemonSprite(id, fill: 0.9)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pokemon.pokemonName.capitalise(),
                        style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pokemon.totalEVs / 510,
                        minHeight: 8,
                        backgroundColor: c.surface,
                        valueColor: const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${pokemon.totalEVs}/510 EVs', style: TextStyle(color: c.muted, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: c.muted),
                onPressed: onDelete,
                tooltip: 'Remover Pokémon',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      children: [
                        Text(_stats[i].$1, style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: values[i] / 252,
                            minHeight: 6,
                            backgroundColor: c.surface,
                            valueColor: AlwaysStoppedAnimation(_stats[i].$2),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('${values[i]}', style: TextStyle(color: c.text, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
