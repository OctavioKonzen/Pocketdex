// lib/widgets/pokemon_detail_panel.dart

import 'package:flutter/material.dart';
import 'dart:math';
import 'package:pocket_dex/models/alternate_form.dart';
import 'package:pocket_dex/models/pokemon_details.dart';
import 'package:pocket_dex/models/pokemon_move.dart';
import 'package:pocket_dex/models/type_relations.dart';
import 'package:pocket_dex/models/move.dart' as encyclopedia_move;
import 'package:pocket_dex/screens/move_detail_screen.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/utils/string_extensions.dart';
import 'package:pocket_dex/widgets/evolution_pokemon_card.dart';

class PokemonDetailPanel extends StatelessWidget {
  final PokemonDetails pokemon;
  final AlternateForm form;
  final TypeRelations typeRelations;
  final PageController pageController;
  final int selectedTabIndex;
  final Function(int) onPageChanged;
  final Function(int) onEvolutionSelected;

  const PokemonDetailPanel({
    super.key,
    required this.pokemon,
    required this.form,
    required this.typeRelations,
    required this.pageController,
    required this.selectedTabIndex,
    required this.onPageChanged,
    required this.onEvolutionSelected,
  });

  String _heightToFeetInches(int decimetres) {
    double inches = decimetres * 3.93701;
    int feet = inches ~/ 12;
    int remainingInches = (inches % 12).round();
    return "$feet' ${remainingInches.toString().padLeft(2, '0')}\"";
  }

  String _weightToLbs(int hectograms) {
    double lbs = hectograms * 0.220462;
    return '${lbs.toStringAsFixed(1)} lbs';
  }

  List<PokemonMove> _generateMovesForForm(AlternateForm form) {
    final List<PokemonMove> movesList = [];
    final bool isGMax = form.apiName.contains('gmax');

    for (var moveData in form.rawMoves) {
      final String moveName = moveData['move']['name'] as String;

      if (isGMax) {
        if (moveName.contains('gmax')) {
          final moveJson = pokemon.allMoveDetails[moveName];
          if (moveJson != null) {
            movesList.add(_createPokemonMove(moveJson, 'machine', 0));
          }
        }
      } else {
        final learnDetailsList = moveData['version_group_details'] as List;
        final learnDetail = learnDetailsList.lastWhere(
          (d) => (d['move_learn_method']['name'] == 'level-up' &&
              (d['level_learned_at'] as int) > 0),
          orElse: () => null,
        );

        if (learnDetail != null) {
          final moveJson = pokemon.allMoveDetails[moveName];
          if (moveJson != null) {
            movesList.add(_createPokemonMove(
                moveJson, 'level-up', learnDetail['level_learned_at']));
          }
        }
      }
    }

    if (!isGMax) {
      movesList.sort((a, b) => a.levelLearnedAt.compareTo(b.levelLearnedAt));
    }
    return movesList;
  }

  PokemonMove _createPokemonMove(
      Map<String, dynamic> moveJson, String learnMethod, int level) {
    String effectText = "No effect description available.";
    var effectEntries = moveJson['effect_entries'] as List;
    var englishEffect = effectEntries
        .firstWhere((e) => e['language']['name'] == 'en', orElse: () => null);
    if (englishEffect != null && englishEffect['short_effect'] != null) {
      effectText = (englishEffect['short_effect'] as String).replaceAll(
          '\$effect_chance', moveJson['effect_chance']?.toString() ?? '');
    }

    return PokemonMove(
      name: (moveJson['name'] as String).replaceAll('-', ' ').capitalise(),
      apiName: moveJson['name'],
      learnMethod: learnMethod,
      levelLearnedAt: level,
      type: moveJson['type']['name'],
      power: moveJson['power'],
      accuracy: moveJson['accuracy'],
      pp: moveJson['pp'],
      effect: effectText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.45,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Padding(
        padding:
            const EdgeInsets.only(top: 20, left: 24, right: 24, bottom: 20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTab('About', 0, theme),
                _buildTab('Base Stats', 1, theme),
                _buildTab('Evolution', 2, theme),
                _buildTab('Moves', 3, theme),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PageView(
                controller: pageController,
                onPageChanged: onPageChanged,
                children: [
                  _buildAboutTab(form, typeRelations, theme),
                  _buildBaseStatsTab(form, theme),
                  _buildEvolutionTab(form, theme),
                  _buildMovesTab(form, theme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, int index, ThemeData theme) {
    bool isSelected = selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected
                  ? theme.textTheme.bodyLarge?.color
                  : theme.hintColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected)
            Container(
              height: 3,
              width: 24,
              decoration: BoxDecoration(
                color: getColorForType(pokemon.forms.first.types.first),
                borderRadius: BorderRadius.circular(2),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildHeightWeightInfo(AlternateForm currentForm, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Height: ",
                style: TextStyle(color: theme.hintColor, fontSize: 12)),
            Text(
              _heightToFeetInches(currentForm.height),
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            )
          ],
        ),
        Container(
            height: 15, width: 1, color: theme.dividerColor.withAlpha(128)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Weight: ",
                style: TextStyle(color: theme.hintColor, fontSize: 12)),
            Text(
              _weightToLbs(currentForm.weight),
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            )
          ],
        )
      ],
    );
  }

  Widget _buildAboutTab(
      AlternateForm currentForm, TypeRelations typeRelations, ThemeData theme) {
    final int eggSteps = (pokemon.hatchCounter + 1) * 255;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pokemon.description,
              style: TextStyle(
                  color: theme.colorScheme.onSurface.withAlpha(178),
                  height: 1.5,
                  fontSize: 14)),
          const SizedBox(height: 16),
          _buildHeightWeightInfo(currentForm, theme),
          const SizedBox(height: 16),
          Text("Breeding",
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildGenderRow('Gender', pokemon.genderRate, theme),
          _buildInfoRow(
              'Egg Groups', pokemon.eggGroups.join(', ').capitalise(), theme),
          _buildInfoRow('Egg Cycle',
              '$eggSteps steps (${pokemon.hatchCounter} cycles)', theme),
        ],
      ),
    );
  }

  Widget _buildBaseStatsTab(AlternateForm currentForm, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: currentForm.stats.entries.map((entry) {
          String statName = entry.key
              .replaceAll('special-attack', 'Sp. Atk')
              .replaceAll('special-defense', 'Sp. Def')
              .replaceAll('-', ' ')
              .capitalise();
          return _buildStatRow(statName, entry.value, theme);
        }).toList(),
      ),
    );
  }

  Widget _buildEvolutionTab(AlternateForm currentForm, ThemeData theme) {
    if (pokemon.evolutionChain.isEmpty) {
      return Center(
        child: Text(
          "This Pokémon does not evolve.",
          style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(178)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 2),
      itemCount: pokemon.evolutionChain.length,
      itemBuilder: (context, index) {
        final entry = pokemon.evolutionChain[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              EvolutionPokemonCard(
                pokemonName: entry.fromPokemonName,
                pokemonId: entry.fromPokemonId,
                currentFormName: currentForm.formName,
                onPokemonSelected: onEvolutionSelected,
                size: 70,
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_forward,
                      color: theme.colorScheme.onSurface, size: 20),
                  const SizedBox(height: 2),
                  Text(
                    entry.trigger,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              EvolutionPokemonCard(
                pokemonName: entry.toPokemonName,
                pokemonId: entry.toPokemonId,
                currentFormName: currentForm.formName,
                onPokemonSelected: onEvolutionSelected,
                size: 70,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMovesTab(AlternateForm form, ThemeData theme) {
    final moves = _generateMovesForForm(form);

    if (moves.isEmpty) {
      return Center(
        child: Text(
          "This form has no moves to display.",
          textAlign: TextAlign.center,
          style: TextStyle(
              color: theme.colorScheme.onSurface.withAlpha(178), fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: moves.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final PokemonMove pokemonMove = moves[index];
        final moveJson = pokemon.allMoveDetails[pokemonMove.apiName];

        if (moveJson == null) return const SizedBox.shrink();

        final encyclopedia_move.Move moveForDetail =
            encyclopedia_move.Move.fromApiJson(moveJson);

        return Card(
          color: theme.colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  pokemonMove.name,
                  style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                Text(
                  pokemonMove.learnMethod == 'machine'
                      ? 'TM'
                      : 'Lvl ${pokemonMove.levelLearnedAt}',
                  style: TextStyle(color: theme.hintColor, fontSize: 14),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: [
                  Chip(
                    label: Text(pokemonMove.type.capitalise()),
                    backgroundColor: getColorForType(pokemonMove.type),
                    labelStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    moveForDetail.category == 'physical'
                        ? Icons.sports_mma
                        : moveForDetail.category == 'special'
                            ? Icons.star
                            : Icons.adjust,
                    color: theme.colorScheme.onSurface.withAlpha(178),
                    size: 20,
                  ),
                ],
              ),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.hintColor),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        MoveDetailScreen(move: moveForDetail)),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: theme.hintColor, fontSize: 14)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRow(String label, int genderRate, ThemeData theme) {
    if (genderRate == -1) {
      return _buildInfoRow(label, "Genderless", theme);
    }
    double femalePercentage = genderRate * 12.5;
    double malePercentage = 100 - femalePercentage;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(color: theme.hintColor, fontSize: 14)),
          ),
          if (malePercentage > 0)
            Row(
              children: [
                const Icon(Icons.male, color: Colors.blue, size: 18),
                Text(' ${malePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 15)),
              ],
            ),
          const SizedBox(width: 20),
          if (femalePercentage > 0)
            Row(
              children: [
                const Icon(Icons.female, color: Colors.pink, size: 18),
                Text(' ${femalePercentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface, fontSize: 15)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String name, int value, ThemeData theme) {
    double normalizedValue = min(value / 255.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(name, style: TextStyle(color: theme.hintColor)),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toString(),
              style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: normalizedValue,
                backgroundColor: theme.dividerColor.withAlpha(128),
                valueColor: AlwaysStoppedAnimation<Color>(
                  getColorForType(pokemon.forms.first.types.first),
                ),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
