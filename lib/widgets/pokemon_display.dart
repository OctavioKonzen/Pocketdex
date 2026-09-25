// lib/widgets/pokemon_display.dart

import 'package:flutter/material.dart';
import 'package:pocket_dex/models/alternate_form.dart';
import 'package:pocket_dex/models/pokemon_details.dart';
import 'package:pocket_dex/utils/pokemon_colors.dart';
import 'package:pocket_dex/utils/string_extensions.dart';

class PokemonDisplay extends StatelessWidget {
  final PokemonDetails pokemon;
  final AlternateForm form;
  final bool isShiny;
  final VoidCallback onShinyToggle;
  final VoidCallback onFormSelect;
  final Animation<double> pokeballAnimation;
  final Widget imageGestureArea;

  /// Arrastar para o lado em qualquer lugar da parte de cima troca de Pokémon
  /// (-1 = anterior, 1 = próximo).
  final ValueChanged<int>? onSwipe;

  const PokemonDisplay({
    super.key,
    required this.pokemon,
    required this.form,
    required this.isShiny,
    required this.onShinyToggle,
    required this.onFormSelect,
    required this.pokeballAnimation,
    required this.imageGestureArea,
    this.onSwipe,
  });

  @override
  Widget build(BuildContext context) {
    final double topSafePadding = MediaQuery.of(context).padding.top;
    const double pokeballSize = 300 * 1.2;

    return Expanded(
      child: _SwipeArea(
        onSwipe: onSwipe,
        child: Container(
          decoration: typeBackground(form.types),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: topSafePadding + 20,
                child: RotationTransition(
                  turns: pokeballAnimation,
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset('assets/images/pokeball.png',
                        width: pokeballSize, height: pokeballSize, color: Colors.white, cacheWidth: 720),
                  ),
                ),
              ),
              Positioned(
                top: topSafePadding,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Text(
                          '#${pokemon.id.toString().padLeft(3, '0')}',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        pokemon.name.capitalise(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          ...form.types.map((type) => Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Chip(
                                  label: Text(type.capitalise()),
                                  backgroundColor: getColorForType(type).withAlpha(200),
                                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              )),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                pokemon.genus,
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (pokemon.forms.length > 1)
                                    GestureDetector(
                                      onTap: onFormSelect,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration:
                                            BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(51)),
                                        child: const Icon(Icons.layers, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: onShinyToggle,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration:
                                          BoxDecoration(shape: BoxShape.circle, color: Colors.white.withAlpha(51)),
                                      child: Icon(Icons.auto_awesome,
                                          color: isShiny ? Colors.yellowAccent : Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: -50,
                height: 300,
                width: 300,
                child: Hero(
                  tag: 'pokemon-${pokemon.id}',
                  child: imageGestureArea,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Troca de Pokémon ao arrastar para o lado: vale um gesto rápido ou um
/// arrasto mais lento de mais de 80 px (o dedo pode parar antes de soltar).
class _SwipeArea extends StatefulWidget {
  final ValueChanged<int>? onSwipe;
  final Widget child;
  const _SwipeArea({required this.onSwipe, required this.child});

  @override
  State<_SwipeArea> createState() => _SwipeAreaState();
}

class _SwipeAreaState extends State<_SwipeArea> {
  double _dx = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.onSwipe == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.delta.dx,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -300 || _dx < -80) {
          widget.onSwipe!(1);
        } else if (v > 300 || _dx > 80) {
          widget.onSwipe!(-1);
        }
      },
      child: widget.child,
    );
  }
}
