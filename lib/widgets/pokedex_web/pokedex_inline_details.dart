// lib/widgets/pokedex_web/pokedex_inline_details.dart
//
// Painel de detalhes que abre dentro da própria Pokédex no site (PC), logo
// abaixo da linha do Pokémon clicado. À esquerda: Pokémon com a Pokébola
// girando, nome, tipos, formas e shiny. À direita: as mesmas abas do app
// (About, Base Stats, Evolution e Moves).

import 'package:flutter/material.dart';

import '../../models/alternate_form.dart';
import '../../models/pokemon_details.dart';
import '../../services/pokemon_service.dart';
import '../../utils/app_images.dart';
import '../../utils/pokemon_colors.dart';
import '../../utils/string_extensions.dart';
import '../../utils/type_relations_builder.dart';
import '../hover_scale.dart';
import '../pikachu_loading_indicator.dart';
import '../pokemon_detail_panel.dart';
import 'pokeball_reveal.dart';

class PokedexInlineDetails extends StatefulWidget {
  final int pokemonId;
  final VoidCallback onClose;

  /// Chamado ao navegar para outro Pokémon (anterior/próximo ou evolução).
  final ValueChanged<int> onNavigate;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Altura do painel; a grade calcula para caber na tela, entre
  /// [minHeight] e [maxHeight].
  final double height;
  static const double minHeight = 460;
  static const double maxHeight = 756;

  const PokedexInlineDetails({
    super.key,
    required this.pokemonId,
    required this.onClose,
    required this.onNavigate,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
    this.height = maxHeight,
  });

  @override
  State<PokedexInlineDetails> createState() => _PokedexInlineDetailsState();
}

class _PokedexInlineDetailsState extends State<PokedexInlineDetails>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pokeball =
      AnimationController(vsync: this, duration: const Duration(seconds: 20))
        ..repeat();
  final PageController _pageController = PageController(keepPage: false);

  PokemonDetails? _details;
  AlternateForm? _form;
  bool _isShiny = false;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PokedexInlineDetails oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pokemonId != widget.pokemonId) _load();
  }

  @override
  void dispose() {
    _pokeball.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final details =
        await PokemonService().fetchPokemonDetails(widget.pokemonId);
    if (!mounted) return;
    setState(() {
      _details = details;
      _form = details.forms.first;
      _isShiny = false;
    });
    // Mantém a aba escolhida ao trocar de Pokémon (as abas são recriadas).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients && _tab != 0) {
        _pageController.jumpToPage(_tab);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final details = _details;
    final form = _form;
    final loaded =
        details != null && form != null && details.id == widget.pokemonId;
    final color =
        loaded ? getColorForType(form.types.first) : Colors.grey.shade700;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: widget.height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: color.withAlpha(90),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: !loaded
          ? const Center(child: PikachuLoadingIndicator(size: 80))
          : Row(
              children: [
                Expanded(flex: 5, child: _buildShowcase(details, form)),
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: PokemonDetailPanel(
                      pokemon: details,
                      form: form,
                      typeRelations: buildTypeRelations(details, form),
                      pageController: _pageController,
                      selectedTabIndex: _tab,
                      onPageChanged: (index) => setState(() => _tab = index),
                      onEvolutionSelected: widget.onNavigate,
                      height: widget.height - 12,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildShowcase(PokemonDetails details, AlternateForm form) {
    final image = _isShiny ? form.shinyPixelImageUrl : form.pixelImageUrl;

    return Stack(
      children: [
        // Pokébola girando atrás do Pokémon.
        Positioned.fill(
          top: 70,
          child: Center(
            child: RotationTransition(
              turns: _pokeball,
              child: Opacity(
                opacity: 0.18,
                child: Image.asset('assets/images/pokeball.png',
                    width: widget.height * 0.6,
                    height: widget.height * 0.6,
                    color: Colors.white),
              ),
            ),
          ),
        ),
        // Pokémon (troca com animação ao mudar forma/shiny/Pokémon).
        // O Pokémon preenche toda a área entre os tipos e o seletor de formas.
        Positioned.fill(
          top: 110,
          bottom: 50,
          left: 56,
          right: 56,
          // Ao abrir (ou trocar de Pokémon) ele sai da Pokébola; ao trocar
          // forma/shiny, só faz a transição.
          child: PokeballReveal(
            key: ValueKey('reveal-${details.id}'),
            ballSize: 110,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => ScaleTransition(
                scale: Tween(begin: 0.8, end: 1.0).animate(CurvedAnimation(
                    parent: animation, curve: Curves.easeOutBack)),
                child: FadeTransition(opacity: animation, child: child),
              ),
              child: HoverScale(
                key: ValueKey(image),
                scale: 1.08,
                cursor: SystemMouseCursors.basic,
                child: Image(
                  image: AppImages.provider(image),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  errorBuilder: (_, __, ___) => const Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 60),
                ),
              ),
            ),
          ),
        ),
        // Anterior / próximo.
        if (widget.hasPrevious)
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: HoverIconButton(
                  icon: Icons.chevron_left,
                  tooltip: 'Anterior',
                  onPressed: widget.onPrevious,
                  size: 28),
            ),
          ),
        if (widget.hasNext)
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Center(
              child: HoverIconButton(
                  icon: Icons.chevron_right,
                  tooltip: 'Próximo',
                  onPressed: widget.onNext,
                  size: 28),
            ),
          ),
        // Nome, número, tipos e ações.
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${details.id.toString().padLeft(3, '0')}',
                          style: TextStyle(
                              color: Colors.white.withAlpha(200),
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        Text(
                          details.name.capitalise(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w900),
                        ),
                        if (details.genus.isNotEmpty)
                          Text(
                            '${details.genus} Pokémon',
                            style: TextStyle(
                                color: Colors.white.withAlpha(220),
                                fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                  HoverIconButton(
                    icon: Icons.auto_awesome,
                    tooltip: _isShiny ? 'Ver normal' : 'Ver shiny',
                    iconColor: _isShiny ? Colors.yellowAccent : Colors.white,
                    onPressed: () => setState(() => _isShiny = !_isShiny),
                  ),
                  const SizedBox(width: 8),
                  HoverIconButton(
                      icon: Icons.close,
                      tooltip: 'Fechar',
                      onPressed: widget.onClose),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final type in form.types)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: getColorForType(type),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withAlpha(150)),
                      ),
                      child: Text(type.capitalise(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                ],
              ),
              const Spacer(),
              if (details.forms.length > 1) _buildFormSelector(details, form),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormSelector(PokemonDetails details, AlternateForm selected) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: details.forms.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final form = details.forms[index];
          final isSelected = form.apiName == selected.apiName;
          return HoverScale(
            scale: 1.08,
            child: GestureDetector(
              onTap: () => setState(() => _form = form),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withAlpha(51),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Text(
                  form.formName,
                  style: TextStyle(
                    color: isSelected
                        ? getColorForType(form.types.first)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
