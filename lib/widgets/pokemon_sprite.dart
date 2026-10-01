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

import '../services/animated_sprites.dart';
import '../services/app_settings.dart';
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
    // Animado (estilo Black & White) quando existe e está ligado nas
    // Configurações; silhueta (jogo "Quem é esse Pokémon?") fica parada.
    final pid = id is int ? id as int : int.tryParse('$id');
    if (silhouette != null || pid == null || !AnimatedSprites.instance.has(pid, shiny: shiny)) return _static();
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => AppSettings.instance.animatedSprites
          ? _AnimatedSprite(pid, shiny: shiny, fill: fill, alignBottom: alignBottom, fallback: _static())
          : _static(),
    );
  }

  Widget _static() {
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

/// O GIF animado do Pokémon (já recortado justo, vem da nuvem), do mesmo tamanho do parado.
class _AnimatedSprite extends StatelessWidget {
  final int id;
  final bool shiny, alignBottom;
  final double fill;
  final Widget fallback;
  const _AnimatedSprite(this.id, {required this.shiny, required this.fill, required this.alignBottom, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final widget = this;
    final f = AnimatedSprites.instance.fit(widget.id, shiny: widget.shiny);
    final dx = f[1], dy = f[2], wr = f.length > 3 ? f[3] : 1.0, hr = f.length > 4 ? f[4] : 1.0;
    // Limita o zoom para a animação inteira caber na caixa (como o site):
    // quem pula ou abre as asas não invade o que está em volta.
    final fill = widget.fill;
    final maxY = widget.alignBottom ? (1 + fill) / (2 * fill * hr) : 1 / (fill * hr);
    final zoom = max(1.0, min(f[0], min(1 / (fill * wr), maxY)));
    return LayoutBuilder(builder: (context, c) {
      final side = c.biggest.shortestSide;
      // Lado do GIF: ampliado para o quadro típico ocupar a caixa (como o site).
      final inner = side * widget.fill * zoom;
      // Centraliza o quadro típico, sem a animação sair da caixa (onde o card
      // recorta, cortaria asas e caudas no meio do movimento).
      double shift(double d, double r) {
        final limit = max(0.0, (side - inner * r) / 2);
        return (d * inner).clamp(-limit, limit);
      }

      final left = side / 2 - inner / 2 - shift(dx, wr);
      final top = widget.alignBottom ? side - side * (1 - widget.fill) / 2 - inner : side / 2 - inner / 2 - shift(dy, hr);
      final still = Transform.translate(offset: Offset(-left, -top), child: SizedBox.square(dimension: side, child: widget.fallback));
      return Center(
        child: SizedBox.square(
          dimension: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: top,
                child: Image.network(
                  AnimatedSprites.instance.url(id, shiny: shiny),
                  width: inner,
                  height: inner,
                  fit: BoxFit.contain,
                  alignment: widget.alignBottom ? Alignment.bottomCenter : Alignment.center,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                  // Enquanto chega da nuvem (ou sem internet): o parado, no lugar da caixa toda.
                  frameBuilder: (_, child, frame, __) => frame == null ? still : child,
                  errorBuilder: (_, __, ___) => still,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
