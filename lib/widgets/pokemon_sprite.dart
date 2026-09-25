// lib/widgets/pokemon_sprite.dart
//
// Sprite de Pokémon com tamanho visual igual para todos (como o site).
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard); o recorte de cada um fica em
// assets/database/sprite_boxes.json (tool/build_sprite_boxes.py) e aqui o
// Pokémon é ampliado para preencher a caixa em que é desenhado.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../utils/app_images.dart';

class SpriteBoxes {
  SpriteBoxes._();
  static Map<String, List<int>> _boxes = {};

  /// Carregado ao abrir o app (arquivo pequeno).
  static Future<void> load() async {
    try {
      final raw = json.decode(await rootBundle.loadString('assets/database/sprite_boxes.json')) as Map;
      _boxes = {for (final e in raw.entries) '${e.key}': (e.value as List).cast<int>()};
    } catch (e) {
      debugPrint('sprite_boxes.json não carregou: $e');
    }
  }

  static List<int>? of(Object id) => _boxes['$id'];
}

class PokemonSprite extends StatelessWidget {
  final Object id;
  final bool shiny;

  /// Quanto da caixa o Pokémon ocupa (0 a 1).
  final double fill;

  /// Pokémon "apoiado" embaixo em vez de centralizado.
  final bool alignBottom;
  final Color? silhouette;

  const PokemonSprite(this.id, {super.key, this.shiny = false, this.fill = 0.9, this.alignBottom = false, this.silhouette});

  @override
  Widget build(BuildContext context) {
    final box = SpriteBoxes.of(id);
    Widget image(double width, [double? height]) {
      final img = Image.asset(
        AppImages.pokemonSprite(id, shiny: shiny),
        width: width,
        height: height ?? width,
        // O padrão (scaleDown) nunca amplia: aqui o sprite precisa crescer.
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );
      return silhouette == null ? img : ColorFiltered(colorFilter: ColorFilter.mode(silhouette!, BlendMode.srcIn), child: img);
    }

    if (box == null) {
      return LayoutBuilder(builder: (context, c) => Center(child: image(c.biggest.shortestSide)));
    }
    final [x0, y0, x1, y1, w, h] = box;
    final bw = x1 - x0, bh = y1 - y0;
    final m = max(bw, bh) / fill; // lado da caixa, em pixels do sprite

    return LayoutBuilder(
      builder: (context, c) {
        final side = c.biggest.shortestSide;
        final scale = side / m;
        final left = (-x0 + (m - bw) / 2) * scale;
        final top = alignBottom ? (-y0 + m - bh - m * (1 - fill) / 2) * scale : (-y0 + (m - bh) / 2) * scale;
        return Center(
          child: SizedBox.square(
            dimension: side,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                children: [Positioned(left: left, top: top, child: image(w * scale, h * scale))],
              ),
            ),
          ),
        );
      },
    );
  }
}
