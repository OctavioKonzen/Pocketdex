// lib/screens/pokemon_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:pocket_dex/models/alternate_form.dart';
import 'package:pocket_dex/models/pokemon_details.dart';
import 'package:pocket_dex/models/type_relations.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:pocket_dex/widgets/pokemon_detail_panel.dart';
import 'package:pocket_dex/widgets/pokemon_display.dart';

enum _AnimationDirection { none, next, previous }

class PokemonDetailScreen extends StatefulWidget {
  final int initialPokemonId;

  const PokemonDetailScreen({
    super.key,
    required this.initialPokemonId,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen>
    with TickerProviderStateMixin {
  final PokemonService _pokemonService = PokemonService();
  final Map<int, PokemonDetails> _loadedDetails = {};

  late AnimationController _slideController;
  late AnimationController _pokeballAnimationController;
  final PageController _pageController = PageController();

  _AnimationDirection _animationDirection = _AnimationDirection.none;
  int _currentPokemonId = 0;
  List<int> _allPokemonIds = [];
  bool _isLoading = true;

  bool _isShiny = false;
  AlternateForm? _selectedForm;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentPokemonId = widget.initialPokemonId;

    _pokeballAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 25))
          ..repeat();
    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));

    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        final int currentIndex = _allPokemonIds.indexOf(_currentPokemonId);
        int newIndex = currentIndex;

        if (_animationDirection == _AnimationDirection.next) {
          newIndex = (currentIndex + 1).clamp(0, _allPokemonIds.length - 1);
        } else if (_animationDirection == _AnimationDirection.previous) {
          newIndex = (currentIndex - 1).clamp(0, _allPokemonIds.length - 1);
        }

        setState(() {
          _currentPokemonId = _allPokemonIds[newIndex];
          _isShiny = false;
          _selectedForm = _loadedDetails[_currentPokemonId]?.forms.first;
          _animationDirection = _AnimationDirection.none;
          _slideController.reset();
        });
        _loadPokemonFamily(_currentPokemonId);
      }
    });

    _loadAllPokemonIds().then((_) {
      _loadPokemonFamily(_currentPokemonId);
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _pokeballAnimationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadAllPokemonIds() async {
    final pokemonList = await _pokemonService.fetchAllPokemonList();
    if (mounted) {
      setState(() {
        _allPokemonIds = pokemonList.map((p) => int.parse(p.id)).toList();
      });
    }
  }

  Future<void> _loadPokemonFamily(int centerId) {
    final idsToLoad = [
      centerId - 3,
      centerId - 2,
      centerId - 1,
      centerId,
      centerId + 1,
      centerId + 2,
      centerId + 3
    ]
        .where((id) =>
            id > 0 &&
            id <= _allPokemonIds.length &&
            !_loadedDetails.containsKey(id))
        .toSet()
        .toList();

    if (idsToLoad.isNotEmpty) {
      final futures =
          idsToLoad.map((id) => _pokemonService.fetchPokemonDetails(id));
      return Future.wait(futures).then((results) {
        if (mounted) {
          setState(() {
            for (var i = 0; i < results.length; i++) {
              _loadedDetails[idsToLoad[i]] = results[i];
            }
            _selectedForm ??= _loadedDetails[centerId]?.forms.first;
            if (_isLoading) _isLoading = false;
          });
        }
      });
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _selectedForm ??= _loadedDetails[centerId]?.forms.first;
        });
      }
      return Future.value();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_slideController.isAnimating) return;

    if (details.primaryVelocity! < -500) {
      setState(() => _animationDirection = _AnimationDirection.next);
      _slideController.forward();
    } else if (details.primaryVelocity! > 500) {
      setState(() => _animationDirection = _AnimationDirection.previous);
      _slideController.forward();
    }
  }

  void _navigateToPokemonById(int newId) {
    if (newId == _currentPokemonId) return;

    final currentIndex = _allPokemonIds.indexOf(_currentPokemonId);
    final newIndex = _allPokemonIds.indexOf(newId);

    if (newIndex == -1) return;

    final direction = newIndex > currentIndex
        ? _AnimationDirection.next
        : _AnimationDirection.previous;

    setState(() {
      _animationDirection = direction;
    });
    _slideController.forward();
  }

  void _showFormSelection(PokemonDetails pokemon) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Selecione uma Forma", style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: pokemon.forms.length,
                  itemBuilder: (context, index) {
                    final form = pokemon.forms[index];
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedForm = form);
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _selectedForm?.apiName == form.apiName
                              ? theme.primaryColor.withAlpha(75)
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedForm?.apiName == form.apiName
                                ? theme.primaryColor
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Image.network(
                          form.pixelImageUrl,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error_outline),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PokemonDetails? pokemon = _loadedDetails[_currentPokemonId];
    final int currentIndex = _allPokemonIds.indexOf(_currentPokemonId);

    final PokemonDetails? prevPokemon =
        currentIndex > 0 ? _loadedDetails[_allPokemonIds[currentIndex - 1]] : null;
    final PokemonDetails? nextPokemon = currentIndex < _allPokemonIds.length - 1
        ? _loadedDetails[_allPokemonIds[currentIndex + 1]]
        : null;

    if (_isLoading && pokemon == null) {
      return const Scaffold(body: Center(child: PikachuLoadingIndicator()));
    }

    if (pokemon == null || _selectedForm == null) {
      return Scaffold(
          backgroundColor: Colors.grey[900],
          body: const Center(
              child: Text("Carregando Pokémon...",
                  style: TextStyle(color: Colors.white))));
    }

    final Color backgroundColor = getColorForType(_selectedForm!.types.first);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          PokemonDisplay(
            pokemon: pokemon,
            form: _selectedForm!,
            isShiny: _isShiny,
            pokeballAnimation: _pokeballAnimationController,
            onShinyToggle: () => setState(() => _isShiny = !_isShiny),
            onFormSelect: () => _showFormSelection(pokemon),
            imageGestureArea: GestureDetector(
              onHorizontalDragEnd: _onHorizontalDragEnd,
              child: AnimatedBuilder(
                animation: _slideController,
                builder: (context, child) {
                  final currentOffset =
                      _animationDirection == _AnimationDirection.next
                          ? Offset(-_slideController.value, 0)
                          : (_animationDirection == _AnimationDirection.previous
                              ? Offset(_slideController.value, 0)
                              : Offset.zero);

                  final enteringOffset =
                      _animationDirection == _AnimationDirection.next
                          ? Offset(1.0 - _slideController.value, 0)
                          : (_animationDirection == _AnimationDirection.previous
                              ? Offset(-1.0 + _slideController.value, 0)
                              : const Offset(1.0, 0.0));

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_animationDirection == _AnimationDirection.next &&
                          nextPokemon != null)
                        _PokemonAnimatedImage(
                            details: nextPokemon, offset: enteringOffset),
                      if (_animationDirection == _AnimationDirection.previous &&
                          prevPokemon != null)
                        _PokemonAnimatedImage(
                            details: prevPokemon, offset: enteringOffset),
                      _PokemonAnimatedImage(
                          details: pokemon,
                          form: _selectedForm,
                          isShiny: _isShiny,
                          offset: currentOffset),
                    ],
                  );
                },
              ),
            ),
          ),
          PokemonDetailPanel(
            pokemon: pokemon,
            form: _selectedForm!,
            typeRelations:
                _generateTypeRelationsForForm(pokemon, _selectedForm!),
            pageController: _pageController,
            selectedTabIndex: _selectedTabIndex,
            onPageChanged: (index) => setState(() => _selectedTabIndex = index),
            onEvolutionSelected: _navigateToPokemonById,
          )
        ],
      ),
    );
  }

  TypeRelations _generateTypeRelationsForForm(
      PokemonDetails pokeDetails, AlternateForm form) {
    final Map<String, double> weaknesses = {};
    final Map<String, double> resistances = {};
    final List<String> immunities = [];
    final Map<String, int> advantages = {};
    final Map<String, double> damageTaken = {};

    for (String typeName in form.types) {
      final typeJson = pokeDetails.allTypeDetails[typeName];
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
          for (var typeData in (relation.value as List)) {
            String attackingTypeName = typeData['name'];
            damageTaken.update(attackingTypeName, (value) => value * multiplier,
                ifAbsent: () => multiplier);
          }
        }
        final doubleDamageTo = relations['double_damage_to'] as List;
        for (var typeData in doubleDamageTo) {
          advantages[typeData['name']] = 1;
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
        advantages: advantages);
  }
}

class _PokemonAnimatedImage extends StatelessWidget {
  final PokemonDetails details;
  final AlternateForm? form;
  final bool? isShiny;
  final Offset offset;

  const _PokemonAnimatedImage({
    required this.details,
    this.form,
    this.isShiny,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = offset.dx.abs();
    final double scale = (1.0 - progress * 0.4).clamp(0.0, 1.0);
    final double opacity = (1.0 - progress * 1.5).clamp(0.0, 1.0);

    final AlternateForm displayForm = form ?? details.forms.first;
    final bool displayShiny = isShiny ?? false;
    final String imageUrl =
        displayShiny ? displayForm.shinyPixelImageUrl : displayForm.pixelImageUrl;

    return FractionalTranslation(
      translation: offset,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Image.network(
            imageUrl,
            height: 300,
            width: 300,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          ),
        ),
      ),
    );
  }
}