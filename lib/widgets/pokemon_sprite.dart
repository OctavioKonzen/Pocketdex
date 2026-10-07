// lib/widgets/pokemon_sprite.dart
//
// Sprite de Pokémon com tamanho visual igual para todos (como o site).
// Os sprites têm bordas transparentes diferentes (o Bulbasaur ocupa bem menos
// da imagem que o Charizard); o recorte de cada um fica em
// assets/database/sprite_boxes.json (tool/build_sprite_boxes.py) e aqui o
// Pokémon é ampliado para preencher a caixa em que é desenhado.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

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

  /// De costas (batalha). Sem as costas no banco: a frente espelhada.
  final bool back;

  /// Na batalha: o Pokémon desce o "pé" do GIF para pisar na plataforma.
  final bool battle;

  /// Já baixa também o outro (normal/shiny): trocar para o shiny não fica
  /// parado esperando chegar da nuvem (tela do Pokémon).
  final bool prefetchShiny;

  /// Algo para pôr no topo da cabeça (a coroa do Terastal na batalha), que
  /// acompanha a animação quadro a quadro (headAnchor).
  final Widget? crown;

  /// Cor do Tera Type: o corpo fica cristalizado (facetas e reflexo, como o
  /// site em web-site/src/lib/teraCrystal.js). Vem junto com [crown].
  final Color? crystal;

  const PokemonSprite(this.id,
      {super.key,
      this.shiny = false,
      this.fill = 0.9,
      this.alignBottom = false,
      this.silhouette,
      this.back = false,
      this.battle = false,
      this.prefetchShiny = false,
      this.crown,
      this.crystal});

  @override
  Widget build(BuildContext context) {
    // Se ele se mexe vem das Configurações; parado, fica no primeiro quadro do
    // mesmo GIF. Silhueta (jogo "Quem é esse Pokémon?")
    // é o sprite parado de sempre.
    final pid = id is int ? id as int : int.tryParse('$id');
    final still = back ? Transform.flip(flipX: true, child: _static()) : _static();
    if (silhouette != null || pid == null) return still;
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) {
        final source = AnimatedSprites.instance.source(pid, shiny: shiny, back: back);
        if (source == null) {
          // Sem as costas: a frente (animada, se tiver) espelhada.
          if (back) return Transform.flip(flipX: true, child: PokemonSprite(id, shiny: shiny, fill: fill, alignBottom: alignBottom, battle: battle, crown: crown, crystal: crystal));
          return still;
        }
        if (prefetchShiny) {
          final other = AnimatedSprites.instance.source(pid, shiny: !shiny, back: back);
          if (other != null) precacheImage(NetworkImage(other.url), context).ignore();
        }
        return _AnimatedSprite(source,
            fill: fill, alignBottom: alignBottom, battle: battle, animate: AppSettings.instance.animatedSprites, fallback: still, crown: crown, crystal: crystal);
      },
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
  final SpriteSource source;
  final bool alignBottom, battle;

  /// false: parado no primeiro quadro (Configurações → Movimento dos sprites).
  final bool animate;
  final double fill;
  final Widget fallback;
  final Widget? crown;
  final Color? crystal;
  const _AnimatedSprite(this.source,
      {required this.fill, required this.alignBottom, required this.battle, required this.animate, required this.fallback, this.crown, this.crystal});

  @override
  Widget build(BuildContext context) {
    final widget = this;
    final f = source.fit;
    final dx = f[1], dy = f[2], wr = f.length > 3 ? f[3] : 1.0, hr = f.length > 4 ? f[4] : 1.0;
    // O quadro típico ocupa a caixa (como o site); quem abre as asas ou pula
    // passa um pouco da borda no meio do movimento. Na batalha, a animação
    // inteira cabe na caixa (não invade a caixa de texto nem o outro lado).
    final fill = widget.fill;
    final maxY = widget.alignBottom ? (1 + fill) / (2 * fill * hr) : 1 / (fill * hr);
    final zoom = widget.battle ? max(1.0, min(f[0], min(1 / (fill * wr), maxY))) : max(1.0, f[0]);
    return LayoutBuilder(builder: (context, c) {
      final side = c.biggest.shortestSide;
      // Lado do GIF: ampliado para o quadro típico ocupar a caixa (como o site).
      final inner = side * widget.fill * zoom;
      // Centraliza o quadro típico, sem a animação sair da caixa (onde o card
      // recorta, cortaria asas e caudas no meio do movimento).
      double shift(double d, double r) {
        if (!widget.battle) return d * inner;
        final limit = max(0.0, (side - inner * r) / 2);
        return (d * inner).clamp(-limit, limit);
      }

      // Pixel art: cada pixel do GIF vira um número inteiro de pixels da tela
      // (todos do mesmo tamanho, nítido, sem borrar).
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final longest = max(source.width, source.height);
      // Escala inteira (pixels nítidos) quando perde pouco tamanho; senão a
      // exata, para os pequenos não encolherem pela metade (1,9× virava 1×) e
      // os grandes caberem na caixa.
      final fitScale = longest > 0 ? inner * dpr / longest : 0.0;
      final whole = fitScale.floorToDouble();
      final pixelScale = longest > 0 ? (whole >= 1 && whole >= 0.85 * fitScale ? whole : fitScale) / dpr : null;
      const quality = FilterQuality.none;
      final left = side / 2 - inner / 2 - shift(dx, wr);
      // Na batalha, quem pula ou flutua no meio da animação desce o "pé" para
      // pisar na plataforma.
      final foot = widget.battle && widget.alignBottom ? source.foot * inner : 0.0;
      final top = widget.alignBottom ? side - side * (1 - widget.fill) / 2 - inner + foot : side / 2 - inner / 2 - shift(dy, hr);
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
                child: widget.crown != null
                    ? _CrownedGif(
                        url: source.url,
                        width: inner,
                        scale: pixelScale,
                        alignBottom: widget.alignBottom,
                        animate: animate,
                        crown: widget.crown!,
                        crystal: widget.crystal,
                        crownWidth: side * 0.26,
                        placeholder: still,
                      )
                    : animate
                    ? Image.network(
                      source.url,
                      // Outro GIF (trocou para o shiny...): começa a animação do zero.
                      key: ValueKey(source.url),
                      width: inner,
                      height: inner,
                      // Tamanho exato (escala inteira); sem saber o tamanho, preenche a caixa.
                      scale: pixelScale == null ? 1 : 1 / pixelScale,
                      fit: pixelScale == null ? BoxFit.contain : BoxFit.none,
                      alignment: widget.alignBottom ? Alignment.bottomCenter : Alignment.center,
                      filterQuality: quality,
                      // Enquanto chega da nuvem (ou sem internet): o parado, no lugar da caixa toda.
                      frameBuilder: (_, child, frame, __) => frame == null ? still : child,
                      errorBuilder: (_, __, ___) => still,
                    )
                    : _FirstFrame(
                        url: source.url,
                        width: inner,
                        scale: pixelScale == null ? null : 1 / pixelScale,
                        fit: pixelScale == null ? BoxFit.contain : BoxFit.none,
                        alignment: alignBottom ? Alignment.bottomCenter : Alignment.center,
                        filterQuality: quality,
                        placeholder: still,
                      ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Só o primeiro quadro do GIF (sprite parado no estilo escolhido): pega o
/// quadro e para de ouvir, então o resto da animação nem é decodificado.
class _FirstFrame extends StatefulWidget {
  final String url;
  final double width;

  /// Pixels do GIF por ponto da tela (null: encaixa na caixa).
  final double? scale;
  final BoxFit fit;
  final Alignment alignment;
  final FilterQuality filterQuality;
  final Widget placeholder;
  const _FirstFrame(
      {required this.url, required this.width, this.scale, required this.fit, required this.alignment, required this.filterQuality, required this.placeholder});

  @override
  State<_FirstFrame> createState() => _FirstFrameState();
}

class _FirstFrameState extends State<_FirstFrame> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ImageInfo? _frame;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(_FirstFrame old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _resolve();
  }

  void _resolve() {
    _stop();
    _frame = null;
    _failed = false;
    final stream = NetworkImage(widget.url).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      setState(() => _frame = info);
      _stop();
    }, onError: (_, __) {
      if (mounted) setState(() => _failed = true);
      _stop();
    });
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _stop() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null || _failed) return widget.placeholder;
    return RawImage(
      image: frame.image,
      width: widget.width,
      height: widget.width,
      scale: widget.scale ?? 1,
      fit: widget.fit,
      alignment: widget.alignment,
      filterQuality: widget.filterQuality,
    );
  }
}

/// O topo da cabeça num quadro (em pixels) e o contorno do Pokémon, igual ao
/// site (web-site/src/lib/headAnchor.js): a primeira linha com pixels
/// suficientes (antenas, orelhas e chifres finos não contam) e o meio do que
/// aparece logo abaixo.
({int x, int y, int x0, int x1, int y0, int y1})? headAnchor(Uint8List rgba, int w, int h) {
  int alpha(int x, int y) => rgba[(y * w + x) * 4 + 3];
  var x0 = w, x1 = -1, y0 = -1, y1 = -1;
  final counts = List.filled(h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha(x, y) < 128) continue;
      counts[y]++;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y0 < 0) y0 = y;
      y1 = y;
    }
  }
  if (y0 < 0) return null;
  final need = max(2, ((x1 - x0 + 1) * 0.12).floor());
  var top = y0;
  while (top < y1 && counts[top] < need) {
    top++;
  }
  final band = max(2, ((y1 - y0 + 1) * 0.08).floor());
  var lo = w, hi = -1;
  for (var y = top; y <= min(y1, top + band); y++) {
    for (var x = 0; x < w; x++) {
      if (alpha(x, y) < 128) continue;
      if (x < lo) lo = x;
      if (x > hi) hi = x;
    }
  }
  return (x: (lo + hi + 1) ~/ 2, y: top, x0: x0, x1: x1, y0: y0, y1: y1);
}

/// Segue a cabeça quadro a quadro, igual ao site (HeadTracker): procura onde
/// o pedaço da cabeça do primeiro quadro foi parar (sempre comparando com o
/// primeiro, então a coroa não escorrega para a asa ou o rabo com o tempo).
class HeadTracker {
  final int w, h;
  late final ({int x, int y, int x0, int x1, int y0, int y1})? head;
  late final int _left, _top, _pw, _ph, _reach;
  late final Int32List _patch;
  int _dx = 0, _dy = 0;

  HeadTracker(Uint8List rgba, this.w, this.h) {
    head = headAnchor(rgba, w, h);
    final head0 = head;
    if (head0 == null) return;
    final pw = max(6, ((head0.x1 - head0.x0 + 1) * 0.22).floor());
    final ph = max(6, ((head0.y1 - head0.y0 + 1) * 0.18).floor());
    // O pedaço: a cabeça logo abaixo do topo (um pouco de ar em cima).
    _left = head0.x - (pw >> 1);
    _top = head0.y - 2;
    _pw = pw;
    _ph = ph + 2;
    _patch = Int32List(_pw * _ph * 4);
    for (var y = 0; y < _ph; y++) {
      for (var x = 0; x < _pw; x++) {
        _pixel(rgba, _left + x, _top + y, _patch, (y * _pw + x) * 4);
      }
    }
    _reach = max(4, (max(w, h) * 0.12).floor());
  }

  void _pixel(Uint8List rgba, int x, int y, Int32List out, int o) {
    if (x < 0 || y < 0 || x >= w || y >= h || rgba[(y * w + x) * 4 + 3] < 128) {
      out[o] = out[o + 1] = out[o + 2] = out[o + 3] = 0;
      return;
    }
    final i = (y * w + x) * 4;
    out[o] = rgba[i];
    out[o + 1] = rgba[i + 1];
    out[o + 2] = rgba[i + 2];
    out[o + 3] = 255;
  }

  /// A cabeça neste quadro (x, y em fração da imagem).
  Offset? track(Uint8List rgba) {
    final head0 = head;
    if (head0 == null) return null;
    final px = Int32List(4);
    var best = 1 << 62;
    var bx = _dx, by = _dy;
    // Perto de onde estava no quadro anterior; empate fica com o mais perto dele.
    for (var r = 0; r <= _reach; r++) {
      for (var oy = -r; oy <= r; oy++) {
        for (var ox = -r; ox <= r; ox++) {
          if (max(ox.abs(), oy.abs()) != r) continue;
          final sx = _dx + ox, sy = _dy + oy;
          if (max(sx.abs(), sy.abs()) > _reach * 2) continue;
          var cost = 0;
          for (var y = 0; y < _ph && cost < best; y++) {
            for (var x = 0; x < _pw; x++) {
              _pixel(rgba, _left + sx + x, _top + sy + y, px, 0);
              final o = (y * _pw + x) * 4;
              final a = _patch[o + 3];
              if (a != px[3]) {
                cost += 300;
              } else if (a != 0) {
                cost += (_patch[o] - px[0]).abs() + (_patch[o + 1] - px[1]).abs() + (_patch[o + 2] - px[2]).abs();
              }
            }
          }
          if (cost < best) {
            best = cost;
            bx = sx;
            by = sy;
          }
        }
      }
      if (best == 0) break;
    }
    _dx = bx;
    _dy = by;
    return Offset((head0.x + bx) / w, (head0.y + by) / h);
  }
}

/// O GIF tocado aqui mesmo, quadro a quadro, com [crown] no topo da cabeça de
/// cada quadro (headAnchor): a coroa sobe, desce e anda junto.
class _CrownedGif extends StatefulWidget {
  final String url;
  final double width;

  /// Pontos da tela por pixel do GIF (null: encaixa na caixa).
  final double? scale;
  final bool alignBottom, animate;
  final Widget crown;
  final Color? crystal;
  final double crownWidth;
  final Widget placeholder;
  const _CrownedGif(
      {required this.url,
      required this.width,
      this.scale,
      required this.alignBottom,
      required this.animate,
      required this.crown,
      this.crystal,
      required this.crownWidth,
      required this.placeholder});

  @override
  State<_CrownedGif> createState() => _CrownedGifState();
}

class _CrownedGifState extends State<_CrownedGif> with SingleTickerProviderStateMixin {
  // O reflexo do cristal passa a cada 2,4 s.
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  List<_Facet>? _facets;
  // Ouve o mesmo GIF que os outros Image.network dele (o brilho do Tera usa
  // cópias do sprite): todos mostram o mesmo quadro ao mesmo tempo.
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  Offset? _head;
  ui.Image? _pending;
  bool _busy = false;
  HeadTracker? _tracker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void initState() {
    super.initState();
    if (widget.crystal != null) _shine.repeat();
  }

  @override
  void didUpdateWidget(_CrownedGif old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.animate != widget.animate) _resolve();
    if (widget.crystal == null) {
      _shine.stop();
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
  }

  void _resolve() {
    _stop();
    _tracker = null;
    _facets = null;
    final stream = NetworkImage(widget.url).resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener((info, _) {
      if (!mounted) return;
      _pending?.dispose();
      _pending = info.image.clone();
      info.dispose();
      if (!widget.animate) _stop();
      _next();
    }, onError: (_, __) => _stop());
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  /// Acha a cabeça do quadro que chegou e só então mostra os dois juntos.
  Future<void> _next() async {
    if (_busy || _pending == null) return;
    _busy = true;
    final image = _pending!;
    _pending = null;
    Offset? head;
    try {
      final data = await image.toByteData();
      if (data != null) {
        final rgba = data.buffer.asUint8List();
        head = (_tracker ??= HeadTracker(rgba, image.width, image.height)).track(rgba);
      }
    } catch (_) {}
    _busy = false;
    if (!mounted) {
      image.dispose();
      return;
    }
    final old = _image;
    setState(() {
      _image = image;
      _head = head ?? _head;
    });
    old?.dispose();
    _next();
  }

  void _stop() {
    if (_stream != null && _listener != null) _stream!.removeListener(_listener!);
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _shine.dispose();
    _stop();
    _pending?.dispose();
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return widget.placeholder;
    final box = widget.width;
    // Onde o quadro aparece dentro da caixa (como o RawImage o desenha).
    final k = widget.scale ?? min(box / image.width, box / image.height);
    final w = image.width * k, h = image.height * k;
    final left = (box - w) / 2;
    final top = widget.alignBottom ? box - h : (box - h) / 2;
    final head = _head;
    final cw = widget.crownWidth;
    final ch = cw * 2 / 3;
    return SizedBox.square(
      dimension: box,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (widget.crystal case final color?)
            CustomPaint(
              size: Size.square(box),
              painter: _CrystalPainter(
                image: image,
                dst: Rect.fromLTWH(left, top, w, h),
                color: color,
                shine: _shine,
                facets: _facets ??= _crystalFacets(image.width, image.height),
              ),
            )
          else
            RawImage(
              image: image,
              width: box,
              height: box,
              scale: widget.scale == null ? 1 : 1 / widget.scale!,
              fit: widget.scale == null ? BoxFit.contain : BoxFit.none,
              alignment: widget.alignBottom ? Alignment.bottomCenter : Alignment.center,
              filterQuality: FilterQuality.none,
            ),
          if (head != null)
            Positioned(
              left: left + head.dx * w - cw / 2,
              top: top + head.dy * h - ch * 0.78,
              width: cw,
              height: ch,
              child: IgnorePointer(child: widget.crown),
            ),
        ],
      ),
    );
  }
}

/// Uma faceta do cristal: triângulo (em pixels do GIF) claro (0), da cor (1) ou escuro (2).
typedef _Facet = ({List<Offset> points, int shade});

/// Número "aleatório" fixo por posição, igual ao site (teraCrystal.js).
double _crystalHash(int a, int b, int c) {
  int imul(int x, int y) => ((x & 0xFFFFFFFF) * (y & 0xFFFFFFFF)) & 0xFFFFFFFF;
  var n = (imul(a, 374761393) + imul(b, 668265263) + imul(c, 2147483647)) & 0xFFFFFFFF;
  n = imul(n ^ (n >> 13), 1274126177);
  return ((n ^ (n >> 16)) & 0xFFFFFFFF) / 4294967296;
}

/// As facetas de um sprite w × h (igual ao site, crystalFacets): triângulos
/// de uma grade com os cantos mexidos.
List<_Facet> _crystalFacets(int w, int h) {
  final s = max(5, (max(w, h) / 9).round());
  final cols = (w / s).ceil() + 1, rows = (h / s).ceil() + 1;
  Offset at(int i, int j) {
    final edge = i == 0 || j == 0 || i == cols || j == rows;
    final jx = edge ? 0.0 : (_crystalHash(i, j, 1) - 0.5) * s * 0.7;
    final jy = edge ? 0.0 : (_crystalHash(i, j, 2) - 0.5) * s * 0.7;
    return Offset(i * s + jx, j * s + jy);
  }

  final facets = <_Facet>[];
  for (var j = 0; j < rows; j++) {
    for (var i = 0; i < cols; i++) {
      final a = at(i, j), b = at(i + 1, j), c = at(i + 1, j + 1), d = at(i, j + 1);
      final tris = _crystalHash(i, j, 3) < 0.5
          ? [
              [a, b, c],
              [a, c, d]
            ]
          : [
              [a, b, d],
              [b, c, d]
            ];
      for (var k = 0; k < 2; k++) {
        final v = _crystalHash(i, j, 4 + k);
        facets.add((points: tris[k], shade: v < 0.3 ? 0 : (v < 0.75 ? 1 : 2)));
      }
    }
  }
  return facets;
}

/// O quadro do GIF com o corpo cristalizado: tinta da cor do tipo, facetas e
/// o reflexo passando, tudo só por cima dos pixels do Pokémon (srcATop).
class _CrystalPainter extends CustomPainter {
  final ui.Image image;
  final Rect dst;
  final Color color;
  final Animation<double> shine;
  final List<_Facet> facets;
  _CrystalPainter({required this.image, required this.dst, required this.color, required this.shine, required this.facets}) : super(repaint: shine);

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble(), h = image.height.toDouble();
    canvas.saveLayer(dst, Paint());
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, w, h), dst, Paint()..filterQuality = FilterQuality.none);
    canvas
      ..save()
      ..translate(dst.left, dst.top)
      ..scale(dst.width / w, dst.height / h);
    final whole = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(whole, Paint()
      ..blendMode = BlendMode.srcATop
      ..color = color.withValues(alpha: 0.3));
    final fills = [const Color(0xFFFFFFFF).withValues(alpha: 0.26), color.withValues(alpha: 0.2), const Color(0xFF000000).withValues(alpha: 0.12)];
    final edge = Paint()
      ..blendMode = BlendMode.srcATop
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.2);
    for (final f in facets) {
      final path = Path()..addPolygon(f.points, true);
      canvas
        ..drawPath(path, Paint()
          ..blendMode = BlendMode.srcATop
          ..color = fills[f.shade])
        ..drawPath(path, edge);
    }
    // O reflexo: uma faixa branca na diagonal atravessando o corpo.
    final x = -w + 3 * w * shine.value;
    canvas.drawRect(
        whole,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x + w * 0.45, h * 0.45),
              [const Color(0xFFFFFFFF).withValues(alpha: 0), const Color(0xFFFFFFFF).withValues(alpha: 0.5), const Color(0xFFFFFFFF).withValues(alpha: 0)], [0, 0.5, 1]));
    canvas
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_CrystalPainter old) => old.image != image || old.dst != dst || old.color != color;
}
