// lib/screens/pokemon_detail_screen.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../services/account_format.dart';
import '../widgets/pokemon_sprite.dart';
import '../widgets/pokedex_web/pokeball_reveal.dart';
import 'package:flutter/services.dart';
import 'package:pocket_dex/models/alternate_form.dart';
import 'package:pocket_dex/models/pokemon_details.dart';
import 'package:pocket_dex/services/pokemon_service.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/utils/type_relations_builder.dart';
import 'package:pocket_dex/utils/responsive.dart';
import 'package:pocket_dex/widgets/pikachu_loading_indicator.dart';
import 'package:pocket_dex/widgets/pokemon_detail_panel.dart';
import 'package:pocket_dex/widgets/pokemon_display.dart';
import 'package:pocket_dex/utils/app_images.dart';

enum _AnimationDirection { next, previous }

class PokemonDetailScreen extends StatefulWidget {
  final int initialPokemonId;

  const PokemonDetailScreen({
    super.key,
    required this.initialPokemonId,
  });

  @override
  State<PokemonDetailScreen> createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> with TickerProviderStateMixin {
  final PokemonService _pokemonService = PokemonService();
  final Map<int, PokemonDetails> _loadedDetails = {};

  late AnimationController _slideController;
  late AnimationController _pokeballAnimationController;
  final PageController _pageController = PageController();

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

    _pokeballAnimationController = AnimationController(vsync: this, duration: const Duration(seconds: 25))..repeat();
    // "Roda" de Pokémon: 0 = o atual no centro; 1 = o próximo chegou ao
    // centro; -1 = o anterior chegou. Acompanha o dedo ao arrastar.
    _slideController = AnimationController(
        vsync: this, lowerBound: -1, upperBound: 1, value: 0, duration: const Duration(milliseconds: 320));

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
    final idsToLoad = [centerId - 3, centerId - 2, centerId - 1, centerId, centerId + 1, centerId + 2, centerId + 3]
        .where((id) => id > 0 && id <= _allPokemonIds.length && !_loadedDetails.containsKey(id))
        .toSet()
        .toList();

    if (idsToLoad.isNotEmpty) {
      final futures = idsToLoad.map((id) => _pokemonService.fetchPokemonDetails(id));
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

  /// Pokémon que sai da Pokébola: o que foi aberto (ou escolhido na
  /// evolução). Ao girar a roda, não repete a animação.
  late int _revealId = widget.initialPokemonId;

  int get _currentIndex => _allPokemonIds.indexOf(_currentPokemonId);
  bool get _hasNext =>
      _currentIndex >= 0 &&
      _currentIndex < _allPokemonIds.length - 1 &&
      _loadedDetails.containsKey(_allPokemonIds[_currentIndex + 1]);
  bool get _hasPrev => _currentIndex > 0 && _loadedDetails.containsKey(_allPokemonIds[_currentIndex - 1]);

  /// Termina o giro: o vizinho que chegou ao centro vira o atual.
  void _finishTurn(int direction) {
    final newIndex = (_currentIndex + direction).clamp(0, _allPokemonIds.length - 1);
    setState(() {
      _currentPokemonId = _allPokemonIds[newIndex];
      _isShiny = false;
      _selectedForm = _loadedDetails[_currentPokemonId]?.forms.first;
      _slideController.value = 0;
    });
    _loadPokemonFamily(_currentPokemonId);
  }

  Future<void> _turnTo(double target) async {
    await _slideController.animateTo(target, curve: Curves.easeOutCubic);
    if (!mounted) return;
    if (target == 1) _finishTurn(1);
    if (target == -1) _finishTurn(-1);
  }

  void _slideTo(_AnimationDirection direction) {
    if (_slideController.isAnimating) return;
    if (direction == _AnimationDirection.next && _hasNext) _turnTo(1);
    if (direction == _AnimationDirection.previous && _hasPrev) _turnTo(-1);
  }

  /// Arrastando: o dedo para a esquerda leva ao próximo.
  void _onDrag(double dx) {
    if (_slideController.isAnimating) _slideController.stop();
    final min = _hasPrev ? -1.0 : -0.12; // na ponta, só "balança" um pouco
    final max = _hasNext ? 1.0 : 0.12;
    _slideController.value = (_slideController.value - dx).clamp(min, max);
  }

  void _onDragEnd(double velocity) {
    final v = _slideController.value;
    if ((v > 0.3 || velocity < -1.2) && _hasNext) {
      _turnTo(1);
    } else if ((v < -0.3 || velocity > 1.2) && _hasPrev) {
      _turnTo(-1);
    } else {
      _turnTo(0);
    }
  }

  void _navigateToPokemonById(int newId) {
    if (newId == _currentPokemonId || !_allPokemonIds.contains(newId)) return;
    // Evolução escolhida: vai direto (a Pokébola abre de novo).
    setState(() {
      _currentPokemonId = newId;
      _revealId = newId;
      _isShiny = false;
      _selectedForm = _loadedDetails[newId]?.forms.first;
      _slideController.value = 0;
    });
    _loadPokemonFamily(newId);
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
                            color: _selectedForm?.apiName == form.apiName ? theme.primaryColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: PokemonSprite(AccountFormat.pokemonIdFromImage(form.pixelImageUrl) ?? pokemon.id,
                            fill: 0.85),
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

    final PokemonDetails? prevPokemon = currentIndex > 0 ? _loadedDetails[_allPokemonIds[currentIndex - 1]] : null;
    final PokemonDetails? nextPokemon =
        currentIndex < _allPokemonIds.length - 1 ? _loadedDetails[_allPokemonIds[currentIndex + 1]] : null;

    if (_isLoading && pokemon == null) {
      return const Scaffold(body: Center(child: PikachuLoadingIndicator()));
    }

    if (pokemon == null || _selectedForm == null) {
      return Scaffold(
          backgroundColor: Colors.grey[900],
          body: const Center(child: Text("Carregando Pokémon...", style: TextStyle(color: Colors.white))));
    }

    final Color backgroundColor = getColorForType(_selectedForm!.types.first);

    // No site: setas do teclado e botões laterais também trocam de Pokémon.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          if (nextPokemon != null) _slideTo(_AnimationDirection.next);
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          if (prevPokemon != null) _slideTo(_AnimationDirection.previous);
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: backgroundColor,
          // Degradê dos tipos na tela toda: com 2 tipos, a cor atrás dos cantos
          // arredondados do painel de baixo continua o degradê de cima.
          body: DecoratedBox(
            decoration: _detailBackground(_selectedForm!.types),
            child: Column(
              children: [
                PokemonDisplay(
                  pokemon: pokemon,
                  form: _selectedForm!,
                  isShiny: _isShiny,
                  pokeballAnimation: _pokeballAnimationController,
                  onShinyToggle: () => setState(() => _isShiny = !_isShiny),
                  onFormSelect: () => _showFormSelection(pokemon),
                  // O Pokémon fica parado (só o painel de baixo rola); arrastar
                  // para o lado vai para o próximo/anterior da Pokédex.
                  onDrag: _onDrag,
                  onDragEnd: _onDragEnd,
                  imageGestureArea: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Camada própria para a animação de troca de Pokémon.
                      RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _slideController,
                          builder: (context, child) {
                            final t = _slideController.value;
                            // Cada Pokémon numa posição da roda (-1 anterior,
                            // 0 atual, 1 próximo), deslocada pelo giro.
                            final items = <(double, Widget)>[
                              if (prevPokemon != null)
                                (-1 - t, _PokemonAnimatedImage(details: prevPokemon, position: -1 - t)),
                              if (nextPokemon != null)
                                (1 - t, _PokemonAnimatedImage(details: nextPokemon, position: 1 - t)),
                              (
                                -t,
                                _PokemonAnimatedImage(
                                    details: pokemon,
                                    form: _selectedForm,
                                    isShiny: _isShiny,
                                    position: -t,
                                    reveal: pokemon.id == _revealId)
                              ),
                            ]..sort((a, b) => b.$1.abs().compareTo(a.$1.abs())); // o mais perto do centro por cima
                            return Stack(
                              alignment: Alignment.center,
                              clipBehavior: Clip.none,
                              children: [for (final item in items) item.$2],
                            );
                          },
                        ),
                      ),
                      if (Responsive.isWide(context) && prevPokemon != null)
                        Positioned(
                          left: 8,
                          child: _NavArrow(
                            icon: Icons.chevron_left,
                            tooltip: 'Anterior',
                            onPressed: () => _slideTo(_AnimationDirection.previous),
                          ),
                        ),
                      if (Responsive.isWide(context) && nextPokemon != null)
                        Positioned(
                          right: 8,
                          child: _NavArrow(
                            icon: Icons.chevron_right,
                            tooltip: 'Próximo',
                            onPressed: () => _slideTo(_AnimationDirection.next),
                          ),
                        ),
                    ],
                  ),
                ),
                PokemonDetailPanel(
                  pokemon: pokemon,
                  form: _selectedForm!,
                  typeRelations: buildTypeRelations(pokemon, _selectedForm!),
                  pageController: _pageController,
                  selectedTabIndex: _selectedTabIndex,
                  onPageChanged: (index) => setState(() => _selectedTabIndex = index),
                  onEvolutionSelected: _navigateToPokemonById,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PokemonAnimatedImage extends StatelessWidget {
  final PokemonDetails details;
  final AlternateForm? form;
  final bool? isShiny;

  /// Posição na roda: 0 = centro, 1 = à direita, -1 = à esquerda.
  final double position;

  /// Pokémon saindo da Pokébola ao abrir (como no site).
  final bool reveal;

  const _PokemonAnimatedImage({
    required this.details,
    this.form,
    this.isShiny,
    required this.position,
    this.reveal = false,
  });

  @override
  Widget build(BuildContext context) {
    // Como numa roda vista de frente: indo para o lado ele diminui, desce um
    // pouco e some; o que vem chega crescendo até o centro.
    final angle = (position.clamp(-1.0, 1.0)) * pi / 2;
    final width = MediaQuery.of(context).size.width;
    final double x = sin(angle) * width * 0.62;
    final double y = (1 - cos(angle)) * 60;
    final double scale = 0.35 + 0.65 * cos(angle);
    final double opacity = pow(cos(angle).clamp(0.0, 1.0), 0.8).toDouble();

    final AlternateForm displayForm = form ?? details.forms.first;
    final bool displayShiny = isShiny ?? false;
    final String imageUrl = displayShiny ? displayForm.shinyPixelImageUrl : displayForm.pixelImageUrl;

    return Transform.translate(
      offset: Offset(x, y),
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: _image(imageUrl, displayShiny),
        ),
      ),
    );
  }

  Widget _image(String imageUrl, bool shiny) {
    final id = AccountFormat.pokemonIdFromImage(imageUrl);
    // Mesmo tamanho visual para todos os Pokémon.
    final Widget image = SizedBox.square(
      dimension: 300,
      child: id != null
          ? PokemonSprite(id, shiny: shiny, fill: 0.78)
          : Image(image: AppImages.provider(imageUrl), fit: BoxFit.contain, filterQuality: FilterQuality.none),
    );
    return reveal ? PokeballReveal(key: ValueKey('reveal-${details.id}'), ballSize: 80, child: image) : image;
  }
}

class _NavArrow extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavArrow({required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 36,
      color: Colors.white,
      style: IconButton.styleFrom(backgroundColor: Colors.black.withAlpha(40)),
      icon: Icon(icon),
    );
  }
}

/// Fundo da tela de detalhes: o degradê dos 2 tipos termina na altura do
/// painel de baixo (fica igual ao do card), e continua atrás dele.
BoxDecoration _detailBackground(List<String> types) {
  final base = typeBackground(types);
  final gradient = base.gradient as LinearGradient?;
  if (gradient == null) return base;
  return BoxDecoration(
    color: base.color,
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: const Alignment(1, 0.15),
      colors: gradient.colors,
      stops: gradient.stops,
    ),
  );
}
