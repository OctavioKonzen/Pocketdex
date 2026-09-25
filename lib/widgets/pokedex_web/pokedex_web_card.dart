// lib/widgets/pokedex_web/pokedex_web_card.dart
//
// Card de Pokémon da Pokédex no layout de PC (site).
//
// Para mudar o visual do card, edite as constantes em [PokedexCardStyle]
// logo abaixo: tamanho, cantos, sombra, tamanho da Pokébola e do Pokémon,
// fontes e o efeito de hover.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pokemon_listing.dart';
import '../../providers/favorites_provider.dart';
import '../../services/pokemon_service.dart';
import '../../utils/app_images.dart';
import '../../utils/pokemon_colors.dart';
import '../../utils/string_extensions.dart';

class PokedexCardStyle {
  /// Altura do card (a largura acompanha a coluna da grade).
  static const double height = 132;

  /// Largura aproximada de cada card; define quantas colunas cabem na tela.
  static const double targetWidth = 280;

  /// Espaço entre os cards.
  static const double spacing = 16;

  static const double borderRadius = 18;
  static const EdgeInsets padding = EdgeInsets.fromLTRB(16, 14, 12, 12);

  // Textos
  static const double nameFontSize = 17;
  static const double numberFontSize = 12;
  static const double typeFontSize = 11;

  // Pokébola girando atrás do Pokémon
  static const double pokeballSize = 130;
  static const double pokeballOpacity = 0.22;
  static const Duration pokeballTurn = Duration(seconds: 12);

  // Pokémon (o sprite tem borda transparente, por isso fica maior que o card
  // e é "puxado" para fora nas bordas; o card corta o excesso).
  static const double spriteSize = 144;
  static const double spriteOffset = -18;

  // Hover (mouse em cima)
  static const double hoverScale = 1.05;
  static const double hoverSpriteScale = 1.15;
  static const Duration animation = Duration(milliseconds: 220);
}

class PokedexWebCard extends StatefulWidget {
  final PokemonListing pokemon;
  final bool isSelected;
  final VoidCallback onTap;

  const PokedexWebCard({
    super.key,
    required this.pokemon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<PokedexWebCard> createState() => _PokedexWebCardState();
}

class _PokedexWebCardState extends State<PokedexWebCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pokeball =
      AnimationController(vsync: this, duration: PokedexCardStyle.pokeballTurn)
        ..repeat();

  bool _hovering = false;
  String? _id;
  String? _spriteUrl;
  List<String> _types = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PokedexWebCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pokemon.url != widget.pokemon.url) _load();
  }

  @override
  void dispose() {
    _pokeball.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final service = PokemonService();
    Map<String, dynamic> data;
    try {
      data = await service.fetchPokemonJsonByUrl(widget.pokemon.url);
    } catch (_) {
      data =
          await service.fetchPokemonJson(widget.pokemon.name.split('-').first);
    }
    if (!mounted) return;
    setState(() {
      _id = (data['id'] as int).toString();
      _spriteUrl = data['sprites']['front_default'] ??
          data['sprites']['other']['official-artwork']['front_default'];
      _types = [
        for (final t in data['types'] as List) t['type']['name'] as String
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final color =
        _types.isEmpty ? Colors.grey.shade700 : getColorForType(_types.first);
    final isFavorite =
        _id != null && context.watch<FavoritesProvider>().isFavorite(_id!);
    final highlighted = _hovering || widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: _id == null
            ? null
            : () => context.read<FavoritesProvider>().toggleFavorite(_id!),
        child: AnimatedScale(
          scale: _hovering ? PokedexCardStyle.hoverScale : 1.0,
          duration: PokedexCardStyle.animation,
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: PokedexCardStyle.animation,
            curve: Curves.easeOutCubic,
            height: PokedexCardStyle.height,
            decoration: BoxDecoration(
              color: color,
              borderRadius:
                  BorderRadius.circular(PokedexCardStyle.borderRadius),
              border: Border.all(
                color: widget.isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(highlighted ? 110 : 60),
                  blurRadius: highlighted ? 18 : 8,
                  offset: Offset(0, highlighted ? 8 : 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(PokedexCardStyle.borderRadius - 3),
              child: Stack(
                children: [
                  // Pokébola girando atrás do Pokémon.
                  Positioned(
                    right: PokedexCardStyle.spriteOffset +
                        (PokedexCardStyle.spriteSize -
                                PokedexCardStyle.pokeballSize) /
                            2,
                    bottom: PokedexCardStyle.spriteOffset +
                        (PokedexCardStyle.spriteSize -
                                PokedexCardStyle.pokeballSize) /
                            2,
                    child: RotationTransition(
                      turns: _pokeball,
                      child: Opacity(
                        opacity: PokedexCardStyle.pokeballOpacity,
                        child: Image.asset(
                          'assets/images/pokeball.png',
                          width: PokedexCardStyle.pokeballSize,
                          height: PokedexCardStyle.pokeballSize,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Pokémon.
                  if (_spriteUrl != null)
                    Positioned(
                      right: PokedexCardStyle.spriteOffset,
                      bottom: PokedexCardStyle.spriteOffset,
                      child: AnimatedScale(
                        scale:
                            _hovering ? PokedexCardStyle.hoverSpriteScale : 1.0,
                        duration: PokedexCardStyle.animation,
                        curve: Curves.easeOutBack,
                        alignment: Alignment.bottomCenter,
                        child: Image(
                          image: AppImages.provider(_spriteUrl!),
                          width: PokedexCardStyle.spriteSize,
                          height: PokedexCardStyle.spriteSize,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.none,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  // Número e favorito.
                  Positioned(
                    top: PokedexCardStyle.padding.top,
                    right: PokedexCardStyle.padding.right,
                    child: Row(
                      children: [
                        if (isFavorite)
                          Icon(Icons.star,
                              color: Colors.yellow.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '#${_id ?? widget.pokemon.id}',
                          style: TextStyle(
                            color: Colors.black.withAlpha(90),
                            fontWeight: FontWeight.w800,
                            fontSize: PokedexCardStyle.numberFontSize,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Nome e tipos.
                  Padding(
                    padding: PokedexCardStyle.padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.pokemon.name.split('-').first.capitalise(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: PokedexCardStyle.nameFontSize,
                            shadows: [
                              Shadow(
                                  color: Colors.black26,
                                  blurRadius: 3,
                                  offset: Offset(0, 1))
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final type in _types) _TypePill(type: type),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String type;

  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(64),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        type,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: PokedexCardStyle.typeFontSize,
        ),
      ),
    );
  }
}
