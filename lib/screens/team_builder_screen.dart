// lib/screens/team_builder_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';

import '../models/team.dart';
import '../models/type_relations.dart';
import '../models/pokemon_details.dart';
import '../models/alternate_form.dart';
import '../services/pokemon_service.dart';
import '../services/team_service.dart';
import '../widgets/team_pokemon_card.dart';
import '../widgets/type_relations_section.dart';
import '../widgets/pikachu_loading_indicator.dart';
import 'pokedex_screen.dart';
import '../utils/responsive.dart';
import '../utils/site_ui.dart';

class TeamBuilderScreen extends StatefulWidget {
  final Team team;

  const TeamBuilderScreen({super.key, required this.team});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen>
    with SingleTickerProviderStateMixin {
  final TeamService _teamService = TeamService();
  final PokemonService _pokemonService = PokemonService();
  late TextEditingController _nameController;
  late Team _editableTeam;

  late final AnimationController _animationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 25),
  )..repeat();

  final Map<String, PokemonDetails> _teamDetailsCache = {};
  TypeRelations? _teamAnalysis;
  bool _isAnalysisLoading = false;
  double _teamScore = 0.0;
  Color? _selectedColor;

  final List<String> allTypes = [
    'normal',
    'fire',
    'water',
    'electric',
    'grass',
    'ice',
    'fighting',
    'poison',
    'ground',
    'flying',
    'psychic',
    'bug',
    'rock',
    'ghost',
    'dragon',
    'dark',
    'steel',
    'fairy'
  ];

  @override
  void initState() {
    super.initState();
    _editableTeam = Team.fromMap(widget.team.toMap());
    _nameController = TextEditingController(text: _editableTeam.name);

    if (_editableTeam.color != null) {
      _selectedColor = Color(int.parse(_editableTeam.color!, radix: 16));
    }

    _updateTeamAnalysis();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Salva na hora (como no site): cada mudança já vai para a conta.
  Future<void> _persist() async {
    final name = _nameController.text.trim();
    _editableTeam.name = name.isEmpty ? _editableTeam.name : name;
    _editableTeam.score = _teamScore;
    _editableTeam.color = _selectedColor?.toARGB32().toRadixString(16);
    await _teamService.updateTeam(_editableTeam);
  }

  Future<void> _saveTeam() async {
    await _persist();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _selectPokemon(int slotIndex) async {
    final navigator = Navigator.of(context);

    final result = await navigator.push<Map<String, String>?>(
      MaterialPageRoute(
        builder: (context) => const PokedexScreen(isForTeamSelection: true),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        while (_editableTeam.pokemons.length <= slotIndex) {
          _editableTeam.pokemons.add({});
        }
        _editableTeam.pokemons[slotIndex] = result;
      });
      await _updateTeamAnalysis();
      _persist();
    }
  }

  void _handleSlotTap(int slotIndex) {
    final existingPokemon = pokemonDataForSlot(slotIndex);
    if (existingPokemon != null) {
      _confirmRemovePokemon(slotIndex);
    } else {
      _selectPokemon(slotIndex);
    }
  }

  Map<String, String>? pokemonDataForSlot(int index) {
    if (_editableTeam.pokemons.length > index &&
        _editableTeam.pokemons[index].isNotEmpty) {
      return _editableTeam.pokemons[index];
    }
    return null;
  }

  void _confirmRemovePokemon(int slotIndex) {
    final theme = Theme.of(context);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (dialogContext) => Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20.0),
                  topRight: Radius.circular(20.0),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Remover Pokémon?',
                      style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text('Deseja remover este Pokémon do time?',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancelar',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurface
                                      .withAlpha(178),
                                  fontSize: 16))),
                      const SizedBox(width: 12),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          onPressed: () {
                            setState(() {
                              _editableTeam.pokemons[slotIndex] = {};
                            });
                            Navigator.pop(dialogContext);
                            _updateTeamAnalysis().then((_) => _persist());
                          },
                          child: const Text('Remover',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold))),
                    ],
                  )
                ],
              ),
            ));
  }

  double _calculateTeamScore(TypeRelations analysis) {
    double score = 5.0;

    analysis.weaknesses.forEach((type, multiplier) {
      score -= (multiplier - 1) * 0.4;
    });
    analysis.resistances.forEach((type, multiplier) {
      score += (1 - multiplier) * 0.2;
    });
    score += analysis.immunities.length * 0.5;

    final uniqueAdvantages = analysis.advantages.keys.toSet();
    score += (uniqueAdvantages.length / allTypes.length) * 2.5;

    return max(0.0, min(10.0, score));
  }

  Future<void> _updateTeamAnalysis() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isAnalysisLoading = true;
    });

    final pokemonInTeam =
        _editableTeam.pokemons.where((p) => p.isNotEmpty).toList();
    if (pokemonInTeam.isEmpty) {
      if (mounted) {
        setState(() {
          _teamAnalysis = null;
          _teamScore = 0.0;
          _isAnalysisLoading = false;
        });
      }
      return;
    }

    for (var pokemonData in pokemonInTeam) {
      final id = pokemonData['id']!;
      if (!_teamDetailsCache.containsKey(id)) {
        try {
          _teamDetailsCache[id] =
              await _pokemonService.fetchPokemonDetails(int.parse(id));
        } catch (e) {}
      }
    }

    final Map<String, double> combinedMultiplier = {};
    for (var type in allTypes) {
      combinedMultiplier[type] = 1.0;
    }

    final Map<String, int> teamAdvantages = {};

    for (var pokemonData in pokemonInTeam) {
      final details = _teamDetailsCache[pokemonData['id']];
      if (details != null) {
        final form = details.forms.firstWhere(
            (f) => f.imageUrl == pokemonData['imageUrl'],
            orElse: () => details.forms.first);

        final relations = _generateTypeRelationsForPokemon(details, form);

        for (var attackingType in allTypes) {
          if (relations.immunities.contains(attackingType)) {
            combinedMultiplier[attackingType] = 0;
          } else if (combinedMultiplier[attackingType] != 0) {
            if (relations.weaknesses.containsKey(attackingType)) {
              combinedMultiplier[attackingType] =
                  (combinedMultiplier[attackingType] ?? 1.0) *
                      (relations.weaknesses[attackingType] ?? 1.0);
            }
            if (relations.resistances.containsKey(attackingType)) {
              combinedMultiplier[attackingType] =
                  (combinedMultiplier[attackingType] ?? 1.0) *
                      (relations.resistances[attackingType] ?? 1.0);
            }
          }
        }

        for (var typeName in form.types) {
          final typeJson = details.allTypeDetails[typeName];
          if (typeJson != null && typeJson['damage_relations'] != null) {
            final doubleDamageTo =
                typeJson['damage_relations']['double_damage_to'] as List;
            for (var type in doubleDamageTo) {
              final typeName = type['name'] as String;
              teamAdvantages.update(typeName, (count) => count + 1,
                  ifAbsent: () => 1);
            }
          }
        }
      }
    }

    final Map<String, double> finalWeaknesses = {};
    final Map<String, double> finalResistances = {};
    final List<String> finalImmunities = [];

    combinedMultiplier.forEach((type, multiplier) {
      if (multiplier == 0) {
        finalImmunities.add(type);
      } else if (multiplier > 1.5) {
        finalWeaknesses[type] = multiplier;
      } else if (multiplier < 0.75) {
        finalResistances[type] = multiplier;
      }
    });

    final currentAnalysis = TypeRelations(
      weaknesses: finalWeaknesses,
      resistances: finalResistances,
      immunities: finalImmunities..sort(),
      advantages: teamAdvantages,
    );

    if (mounted) {
      setState(() {
        _teamAnalysis = currentAnalysis;
        _teamScore = _calculateTeamScore(currentAnalysis);
        _isAnalysisLoading = false;
      });
    }
  }

  TypeRelations _generateTypeRelationsForPokemon(
      PokemonDetails details, AlternateForm form) {
    final Map<String, double> weaknesses = {};
    final Map<String, double> resistances = {};
    final List<String> immunities = [];
    final Map<String, double> damageTaken = {};

    for (String typeName in form.types) {
      final typeJson = details.allTypeDetails[typeName];
      if (typeJson != null) {
        final relations = typeJson['damage_relations'] as Map<String, dynamic>;
        for (var relation in relations.entries) {
          double multiplier = 1.0;
          if (relation.key == 'double_damage_from') {
            multiplier = 2.0;
          } else if (relation.key == 'half_damage_from') {
            multiplier = 0.5;
          } else if (relation.key == 'no_damage_from') {
            multiplier = 0.0;
          } else {
            continue;
          }
          for (var type in (relation.value as List)) {
            String attackingTypeName = type['name'];
            damageTaken.update(attackingTypeName, (value) => value * multiplier,
                ifAbsent: () => multiplier);
          }
        }
      }
    }

    damageTaken.forEach((type, multiplier) {
      if (multiplier >= 2.0) {
        weaknesses[type] = multiplier;
      } else if (multiplier > 0 && multiplier < 1) {
        resistances[type] = multiplier;
      } else if (multiplier == 0) {
        immunities.add(type);
      }
    });

    return TypeRelations(
        weaknesses: weaknesses,
        resistances: resistances,
        immunities: immunities,
        advantages: {});
  }

  static const _teamColors = [
    Color(0xFFFF5252), Color(0xFFFFA726), Color(0xFFFFCA28), Color(0xFF66BB6A), Color(0xFF26A69A), Color(0xFF42A5F5),
    Color(0xFF5C6BC0), Color(0xFFAB47BC), Color(0xFFEC407A), Color(0xFF8D6E63), Color(0xFF78909C),
  ];

  Color get _scoreColor => _teamScore >= 7.5
      ? const Color(0xFF43A047)
      : _teamScore >= 4.5
          ? const Color(0xFFFB8C00)
          : const Color(0xFFE53935);

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final accent = _selectedColor ?? SectionColors.teams;
    final hasPokemon = _editableTeam.pokemons.any((p) => p.isNotEmpty);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _persist();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Editar time'),
          actions: [
            TextButton.icon(
              onPressed: _saveTeam,
              icon: const Icon(Icons.check),
              label: const Text('Concluir'),
            ),
          ],
        ),
        body: ReadableWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SiteCard(
                accentLeft: accent,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nome do time', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      onChanged: (_) => _persist(),
                      style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: c.surface,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text('Cor do time', style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final color in _teamColors)
                          GestureDetector(
                            onTap: () {
                              setState(() => _selectedColor = color);
                              _persist();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: color.toARGB32() == accent.toARGB32() ? c.text : Colors.transparent, width: 3),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text('Pokémon', style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Toque num espaço vazio para adicionar; num Pokémon para tirar.',
                  style: TextStyle(color: c.muted, fontSize: 13)),
              const SizedBox(height: 10),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: 6,
                itemBuilder: (context, index) =>
                    TeamPokemonCard(pokemonData: pokemonDataForSlot(index), onTap: () => _handleSlotTap(index)),
              ),
              const SizedBox(height: 18),
              SiteCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('Análise do time',
                              style: TextStyle(color: c.text, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        if (!_isAnalysisLoading && _teamAnalysis != null && hasPokemon)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Nota (0 a 10)', style: TextStyle(color: c.muted, fontSize: 12)),
                              Text(_teamScore.toStringAsFixed(1),
                                  style: TextStyle(color: _scoreColor, fontSize: 28, fontWeight: FontWeight.w900)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_isAnalysisLoading)
                      const Center(child: PikachuLoadingIndicator())
                    else if (_teamAnalysis == null || !hasPokemon)
                      Text('Adicione Pokémon para ver a análise.', style: TextStyle(color: c.muted))
                    else ...[
                      TypeRelationsSection(title: 'Vantagens ofensivas', relations: _teamAnalysis!.advantages),
                      const SizedBox(height: 14),
                      TypeRelationsSection(title: 'Fraquezas', relations: _teamAnalysis!.weaknesses),
                      const SizedBox(height: 14),
                      TypeRelationsSection(title: 'Resistências', relations: _teamAnalysis!.resistances),
                      const SizedBox(height: 14),
                      TypeRelationsSection(title: 'Imunidades', relations: _teamAnalysis!.immunities),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
