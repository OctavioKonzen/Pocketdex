// lib/widgets/pokemon_page_item.dart

import 'package:flutter/material.dart';

import 'package:pocket_dex/models/pokemon_details.dart';

class PokemonPageItem extends StatelessWidget {
  final PokemonDetails? details;
  final double currentPageValue;
  final double pageIndex;

  const PokemonPageItem({
    super.key,
    required this.details,
    required this.currentPageValue,
    required this.pageIndex,
  });

  @override
  Widget build(BuildContext context) {
    final double diff = pageIndex - currentPageValue;

    final double scale = (1.0 - (diff.abs() * 0.4)).clamp(0.6, 1.0);

    final double colorFactor = (1.0 - (diff.abs() * 0.8)).clamp(0.2, 1.0);

    if (details == null) {
      return Transform.scale(
        scale: scale,
        child: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    
    final imageUrl = details!.forms.first.pixelImageUrl;

    return Transform.scale(
      scale: scale,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: ColorFiltered(
              colorFilter: ColorFilter.matrix(<double>[
                colorFactor, 0, 0, 0, 0,
                0, colorFactor, 0, 0, 0,
                0, 0, colorFactor, 0, 0,
                0, 0, 0, 1, 0,
              ]),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.none,
                errorBuilder: (c, e, s) => const Icon(Icons.error_outline, color: Colors.white, size: 50),
              ),
            ),
          ),
          Opacity(
             opacity: (1 - diff.abs()).clamp(0.0, 1.0),
             child: Column(
               children: [
                  Text(
                    details!.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black38, blurRadius: 4)]),
                  ),
                  Text(
                    '#${details!.id.toString().padLeft(3, '0')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
               ],
             ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}