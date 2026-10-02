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

  /// De costas (batalha). Sem as costas no banco: a frente espelhada.
  final bool back;

  /// Na batalha: o Pokémon desce o "pé" do GIF para pisar na plataforma.
  final bool battle;

  /// Já baixa também o outro (normal/shiny): trocar para o shiny não fica
  /// parado esperando chegar da nuvem (tela do Pokémon).
  final bool prefetchShiny;

  const PokemonSprite(this.id,
      {super.key,
      this.shiny = false,
      this.fill = 0.9,
      this.alignBottom = false,
      this.silhouette,
      this.back = false,
      this.battle = false,
      this.prefetchShiny = false});

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
          if (back) return Transform.flip(flipX: true, child: PokemonSprite(id, shiny: shiny, fill: fill, alignBottom: alignBottom, battle: battle));
          return still;
        }
        if (prefetchShiny) {
          final other = AnimatedSprites.instance.source(pid, shiny: !shiny, back: back);
          if (other != null) precacheImage(NetworkImage(other.url), context).ignore();
        }
        return _AnimatedSprite(source,
            fill: fill, alignBottom: alignBottom, battle: battle, animate: AppSettings.instance.animatedSprites, fallback: still);
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
  const _AnimatedSprite(this.source,
      {required this.fill, required this.alignBottom, required this.battle, required this.animate, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final widget = this;
    final f = source.fit;
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
                child: animate
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
