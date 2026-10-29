// lib/widgets/pokemon_theme_art.dart
//
// O desenho do Pokémon do tema (Configurações → Tema de Pokémon), no fundo
// das telas no lugar da Pokébola: como um desenho a lápis, só com os traços
// (o contorno e as linhas escuras do sprite BW) e o corpo pintado na cor do
// tema.

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../utils/app_images.dart';
import 'pokemon_sprite.dart';

final _cache = <String, Future<ui.Image?>>{};

/// O sprite com o contorno e as linhas escuras em [line] e o resto em [fill],
/// recortado justo no Pokémon.
Future<ui.Image?> pokemonThemeArt(int id, Color fill, Color line, {bool shiny = false}) =>
    _cache.putIfAbsent('$id ${fill.toARGB32()} ${line.toARGB32()} $shiny', () => _draw(id, fill, line, shiny).catchError((_) => null));

Future<ui.Image?> _draw(int id, Color fill, Color line, bool shiny) async {
  final data = await rootBundle.load(AppImages.pokemonSprite(id, shiny: shiny));
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final sprite = (await codec.getNextFrame()).image;
  final rgba = (await sprite.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final w = sprite.width, h = sprite.height;
  final box = SpriteBoxes.of(id);
  final x0 = box?[0] ?? 0, y0 = box?[1] ?? 0, x1 = box?[2] ?? w, y1 = box?[3] ?? h;
  final ow = x1 - x0, oh = y1 - y0;
  if (ow <= 0 || oh <= 0) return null;
  bool solid(int x, int y) => x >= 0 && y >= 0 && x < w && y < h && rgba.getUint8((y * w + x) * 4 + 3) >= 128;
  // Cada pixel vira 0 (vazio), 1 (corpo) ou 2 (traço: as linhas escuras do sprite).
  var grid = Uint8List(ow * oh);
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      if (!solid(x, y)) continue;
      final i = (y * w + x) * 4;
      final light = (0.299 * rgba.getUint8(i) + 0.587 * rgba.getUint8(i + 1) + 0.114 * rgba.getUint8(i + 2)) / 255;
      grid[(y - y0) * ow + (x - x0)] = light < 0.13 ? 2 : 1;
    }
  }
  // Amplia 4x com o Scale2x duas vezes: as escadinhas do pixel art viram
  // curvas, e o traço fica fino como um desenho.
  var gw = ow, gh = oh;
  for (var pass = 0; pass < 2; pass++) {
    (grid, gw, gh) = _scale2x(grid, gw, gh);
  }
  int at(int x, int y) => x < 0 || y < 0 || x >= gw || y >= gh ? 0 : grid[y * gw + x];
  final out = Uint8List(gw * gh * 4);
  for (var y = 0; y < gh; y++) {
    for (var x = 0; x < gw; x++) {
      final v = at(x, y);
      if (v == 0) continue;
      // O contorno de fora também é traço.
      final edge = at(x - 1, y) == 0 || at(x + 1, y) == 0 || at(x, y - 1) == 0 || at(x, y + 1) == 0;
      final c = v == 2 || edge ? line : fill;
      final o = (y * gw + x) * 4;
      out[o] = (c.r * 255).round();
      out[o + 1] = (c.g * 255).round();
      out[o + 2] = (c.b * 255).round();
      out[o + 3] = 255;
    }
  }
  final done = Completer<ui.Image>();
  ui.decodeImageFromPixels(out, gw, gh, ui.PixelFormat.rgba8888, done.complete);
  return done.future;
}

/// Scale2x (EPX): cada célula vira 2x2, arredondando as diagonais.
(Uint8List, int, int) _scale2x(Uint8List src, int w, int h) {
  int at(int x, int y) => src[y.clamp(0, h - 1) * w + x.clamp(0, w - 1)];
  final out = Uint8List(w * h * 4);
  final ow = w * 2;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = at(x, y), a = at(x, y - 1), b = at(x + 1, y), c = at(x - 1, y), d = at(x, y + 1);
      var e0 = p, e1 = p, e2 = p, e3 = p;
      if (c == a && c != d && a != b) e0 = a;
      if (a == b && a != c && b != d) e1 = b;
      if (d == c && d != b && c != a) e2 = c;
      if (b == d && b != a && d != c) e3 = d;
      out[(2 * y) * ow + 2 * x] = e0;
      out[(2 * y) * ow + 2 * x + 1] = e1;
      out[(2 * y + 1) * ow + 2 * x] = e2;
      out[(2 * y + 1) * ow + 2 * x + 1] = e3;
    }
  }
  return (out, w * 2, h * 2);
}

class PokemonThemeArt extends StatelessWidget {
  final int id;
  final Color fill;
  final Color line;
  final bool shiny;
  const PokemonThemeArt(this.id, {super.key, required this.fill, required this.line, this.shiny = false});

  @override
  Widget build(BuildContext context) => FutureBuilder<ui.Image?>(
        future: pokemonThemeArt(id, fill, line, shiny: shiny),
        builder: (context, snap) => snap.data == null
            ? const SizedBox.shrink()
            : RawImage(image: snap.data, fit: BoxFit.contain, alignment: Alignment.bottomCenter, filterQuality: FilterQuality.medium),
      );
}
