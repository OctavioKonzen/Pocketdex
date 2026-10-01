// lib/widgets/pokemon_sprite.dart
//
// Sprite de Pokémon com tamanho visual igual para todos (como o site).
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard); o recorte de cada um fica em
// assets/database/sprite_boxes.json (tool/build_sprite_boxes.py) e aqui o
// Pokémon é ampliado para preencher a caixa em que é desenhado.

import 'dart:convert';
import 'dart:io';
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

/// O GIF animado do Pokémon (já recortado justo), do mesmo tamanho do parado.
/// Enquanto baixa (ou se não der), mostra o parado.
class _AnimatedSprite extends StatefulWidget {
  final int id;
  final bool shiny, alignBottom;
  final double fill;
  final Widget fallback;
  const _AnimatedSprite(this.id, {required this.shiny, required this.fill, required this.alignBottom, required this.fallback});

  @override
  State<_AnimatedSprite> createState() => _AnimatedSpriteState();
}

class _AnimatedSpriteState extends State<_AnimatedSprite> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_AnimatedSprite old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id || old.shiny != widget.shiny) _load();
  }

  void _load() {
    final id = widget.id, shiny = widget.shiny;
    _file = AnimatedSprites.instance.saved(id, shiny: shiny);
    if (_file != null) return;
    AnimatedSprites.instance.file(id, shiny: shiny).then((f) {
      if (mounted && f != null && widget.id == id && widget.shiny == shiny) setState(() => _file = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final file = _file;
    if (file == null) return widget.fallback;
    final [zoom, dx, dy] = AnimatedSprites.instance.fit(widget.id, shiny: widget.shiny);
    return LayoutBuilder(builder: (context, c) {
      final side = c.biggest.shortestSide;
      // Lado do GIF: ampliado para o quadro típico ocupar a caixa (como o site).
      final inner = side * widget.fill * zoom;
      final left = side / 2 - inner / 2 - dx * inner;
      final top = widget.alignBottom ? side - side * (1 - widget.fill) / 2 - inner : side / 2 - inner / 2 - dy * inner;
      return Center(
        child: SizedBox.square(
          dimension: side,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: left,
                top: top,
                child: Image.file(
                  file,
                  width: inner,
                  height: inner,
                  fit: BoxFit.contain,
                  alignment: widget.alignBottom ? Alignment.bottomCenter : Alignment.center,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => widget.fallback,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}
