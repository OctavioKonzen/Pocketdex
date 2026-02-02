// lib/screens/team_builder_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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

class TeamBuilderScreen extends StatefulWidget {
  final Team team;

  const TeamBuilderScreen({super.key, required this.team});

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> with SingleTickerProviderStateMixin {
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
    'normal', 'fire', 'water', 'electric', 'grass', 'ice', 'fighting', 'poison',
    'ground', 'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy'
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

  Future<void> _saveTeam() async {
    _editableTeam.name = _nameController.text.trim();
    _editableTeam.score = _teamScore;
    _editableTeam.color = _selectedColor?.value.toRadixString(16);
    
    await _teamService.updateTeam(_editableTeam);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Time salvo com sucesso!')),
      );
      Navigator.of(context).pop();
    }
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
      _updateTeamAnalysis();
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
     if (_editableTeam.pokemons.length > index && _editableTeam.pokemons[index].isNotEmpty) {
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
              Text('Remover Pokémon?', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Deseja remover este Pokémon do time?', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancelar', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(178), fontSize: 16))
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                     style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {
                      setState(() {
                        _editableTeam.pokemons[slotIndex] = {};
                      });
                      Navigator.pop(dialogContext);
                      _updateTeamAnalysis();
                    },
                    child: const Text('Remover', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                  ),
                ],
              )
            ],
          ),
      )
    );
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

    final pokemonInTeam = _editableTeam.pokemons.where((p) => p.isNotEmpty).toList();
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
          _teamDetailsCache[id] = await _pokemonService.fetchPokemonDetails(int.parse(id));
        } catch (e) {
        }
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
            (f) => f.imageUrl == pokemonData['imageUrl'], orElse: () => details.forms.first);
        
        final relations = _generateTypeRelationsForPokemon(details, form);
        
        for(var attackingType in allTypes) {
           if (relations.immunities.contains(attackingType)) {
             combinedMultiplier[attackingType] = 0;
           } else if (combinedMultiplier[attackingType] != 0) { 
             if(relations.weaknesses.containsKey(attackingType)) {
                combinedMultiplier[attackingType] = (combinedMultiplier[attackingType] ?? 1.0) * (relations.weaknesses[attackingType] ?? 1.0);
             }
             if(relations.resistances.containsKey(attackingType)) {
                combinedMultiplier[attackingType] = (combinedMultiplier[attackingType] ?? 1.0) * (relations.resistances[attackingType] ?? 1.0);
             }
           }
        }

        for (var typeName in form.types) {
          final typeJson = details.allTypeDetails[typeName];
          if (typeJson != null && typeJson['damage_relations'] != null) {
            final doubleDamageTo = typeJson['damage_relations']['double_damage_to'] as List;
            for (var type in doubleDamageTo) {
              final typeName = type['name'] as String;
              teamAdvantages.update(typeName, (count) => count + 1, ifAbsent: () => 1);
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

  TypeRelations _generateTypeRelationsForPokemon(PokemonDetails details, AlternateForm form) {
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
            damageTaken.update(attackingTypeName, (value) => value * multiplier, ifAbsent: () => multiplier);
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

    return TypeRelations(weaknesses: weaknesses, resistances: resistances, immunities: immunities, advantages: {});
  }
  
  void _showColorPickerDialog() {
    final theme = Theme.of(context);
    Color pickerColor = _selectedColor ?? Colors.grey[850]!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('Escolha uma cor', style: theme.textTheme.headlineSmall),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: pickerColor,
            onColorChanged: (color) {
              pickerColor = color;
            },
            colorPickerWidth: 300.0,
            pickerAreaHeightPercent: 0.7,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hex],
            displayThumbColor: true,
            paletteType: PaletteType.hsv,
            pickerAreaBorderRadius: const BorderRadius.only(
              topLeft: Radius.circular(2.0),
              topRight: Radius.circular(2.0),
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: Text('OK', style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(178))),
            onPressed: () {
              setState(() => _selectedColor = pickerColor);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Time'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Salvar Time',
            onPressed: _saveTeam,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            top: 200,
            left: -100,
            child: RotationTransition(
              turns: _animationController,
              child: Opacity(
                opacity: 0.05,
                child: Image.asset(
                  'assets/images/pokeball.png',
                  width: 400,
                  height: 400,
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nome do Time',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cor do Time',
                      style: theme.textTheme.titleLarge,
                    ),
                    GestureDetector(
                      onTap: _showColorPickerDialog,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: _selectedColor ?? theme.colorScheme.surface,
                        child: Icon(Icons.edit, color: theme.colorScheme.onSurface, size: 18),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                Text(
                  'Pokémon',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final pokemonData = pokemonDataForSlot(index);
                    return TeamPokemonCard(
                      pokemonData: pokemonData,
                      onTap: () => _handleSlotTap(index),
                    );
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                 Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Análise do Time',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (!_isAnalysisLoading && _teamAnalysis != null && _editableTeam.pokemons.where((p) => p.isNotEmpty).isNotEmpty)
                      Chip(
                        label: Text('Nota: ${_teamScore.toStringAsFixed(1)} / 10', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        backgroundColor: _teamScore >= 7.5 ? Colors.green.shade700 : _teamScore >= 4.5 ? Colors.orange.shade700 : Colors.red.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      )
                  ],
                ),
                const SizedBox(height: 16),
                if (_isAnalysisLoading)
                  const Center(child: PikachuLoadingIndicator())
                else if (_teamAnalysis == null ||
                    (_teamAnalysis!.weaknesses.isEmpty &&
                        _teamAnalysis!.resistances.isEmpty &&
                        _teamAnalysis!.immunities.isEmpty &&
                        _teamAnalysis!.advantages.isEmpty))
                  Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Adicione Pokémon para ver a análise.',
                          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(178))))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TypeRelationsSection(
                          title: "Vantagens Ofensivas",
                          relations: _teamAnalysis!.advantages),
                      const SizedBox(height: 16),
                      TypeRelationsSection(
                          title: "Fraquezas Defensivas",
                          relations: _teamAnalysis!.weaknesses),
                      const SizedBox(height: 16),
                      TypeRelationsSection(
                          title: "Resistências Defensivas",
                          relations: _teamAnalysis!.resistances),
                      const SizedBox(height: 16),
                      TypeRelationsSection(
                          title: "Imunidades Defensivas",
                          relations: _teamAnalysis!.immunities),
                    ],
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}