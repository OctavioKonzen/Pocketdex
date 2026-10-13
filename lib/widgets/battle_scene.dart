// lib/widgets/battle_scene.dart
//
// O cenário da batalha: o campo clássico (faixas e duas bases) nas cores do
// lugar, com o que tem nele desenhado atrás: prédios na cidade, árvores na
// floresta, estalactites na caverna, ondas no mar, montanhas, vulcão, neve,
// torre, nuvens. O clima muda as cores do céu e do chão. Igual ao site
// (web-site/src/components/BattleScene.jsx).

import 'dart:math';

import 'package:flutter/material.dart';

import '../services/local_database.dart';
import 'pokemon_sprite.dart';

/// Os lugares que têm imagem (sprites/battle/<lugar>.webp, feitas por tool/battle_backgrounds.py, sem as bases: PlatformBase
/// põe uma embaixo de cada Pokémon) e a versão de cada clima (sprites/battle-weather/<lugar>-sun/rain/sand/snow.webp, no
/// site): Sunny Day, Rain Dance... mudam o cenário. Igual ao site.
const sceneImages = ['grass', 'forest', 'water', 'beach', 'underwater', 'swamp', 'sewer', 'cave', 'icecave', 'mountain', 'desert', 'volcano', 'snow', 'city', 'sky', 'tower', 'gym', 'league', 'center'];
String _usable(String scene) => sceneImages.contains(scene) || BattleScenePainter.colors.containsKey(scene) ? scene : 'grass';

/// De onde vêm as versões do clima (o site; não vão no APK).
const weatherSite = 'https://octaviokonzen.github.io/Pocketdex';

/// O clima na imagem (o granizo usa a de neve).
const _weatherImage = {'sun': 'sun', 'rain': 'rain', 'sand': 'sand', 'hail': 'snow', 'snow': 'snow'};
const _outdoor = ['grass', 'forest', 'water', 'beach', 'swamp', 'cave', 'icecave', 'mountain', 'desert', 'volcano', 'snow', 'city', 'sky'];
/// O cenário da batalha: o do lugar (a rota da Battle Factory, o ginásio, a Liga) ou, numa batalha comum, um sorteado. Igual ao site.
String battleScene(String scene, int? seed) => _usable(scene.isNotEmpty ? scene : _outdoor[(seed ?? 0).abs() % _outdoor.length]);

/// Líder de ginásio no ginásio; Elite Four e Campeão na Liga.
String? sceneOfBoss(String? kind) => kind == 'gym' ? 'gym' : kind == 'elite' || kind == 'champion' || kind == 'league' ? 'league' : null;

/// As bases dos dois lados (cx, cy, rx, ry) no campo (160 × 100). bw: como no
/// Black & White, iguais às das imagens; senão, o campo de antes.
const _platforms = {
  false: ([120.0, 45.0, 32.0, 8.0], [38.0, 91.0, 42.0, 12.0]),
  true: ([122.0, 40.0, 38.0, 6.5], [74.0, 80.0, 84.0, 20.0]),
};

/// O tamanho na batalha pela altura do Pokémon (decímetros), como nos jogos: um Joltik bem pequeno, um Charizard quase do
/// tamanho do espaço e os gigantes ocupando tudo. Igual ao site (battleScale).
double battleScale(num? height) => sqrt((height ?? 10) / 20).clamp(0.3, 1.0).toDouble();

/// Onde ficam os pés do adversário em cada lugar (fração da altura do campo): um pouco para dentro do chão de cada cenário
/// (tool/battle_backgrounds.py, foe_feet), para a base dele ficar no chão e não voando. Igual ao site.
const groundFeet = <String, double>{'grass': 0.487, 'forest': 0.506, 'water': 0.487, 'beach': 0.508, 'underwater': 0.527, 'swamp': 0.487, 'sewer': 0.54, 'cave': 0.519, 'icecave': 0.519, 'mountain': 0.492, 'desert': 0.495, 'volcano': 0.5, 'snow': 0.487, 'city': 0.548, 'sky': 0.45, 'tower': 0.527, 'gym': 0.527, 'league': 0.527, 'center': 0.527};

/// A distância do pé do adversário até a borda de baixo do campo (fração), para o "bottom" da caixa dele.
double foeBottom(String scene) => 1 - (groundFeet[scene] ?? 0.45);

/// Largura da base (fração da caixa do Pokémon) pelo tamanho dele. Igual ao site (baseWidth).
double baseWidth(double scale) => 0.55 + 0.85 * scale;

/// As alturas já lidas do banco (id → decímetros).
final battleHeights = <int, num>{};

/// Lê a altura de quem vai aparecer (a forma: Mega, Gigantamax...) e avisa quando chegar.
void loadBattleHeight(int id, VoidCallback onLoaded) {
  if (battleHeights.containsKey(id)) return;
  LocalDatabase.instance.pokemonRow(id).then((row) {
    final h = row?['height'] as num?;
    if (h == null) return;
    battleHeights[id] = h;
    onLoaded();
  });
}

/// A proporção (altura/largura) das imagens das bases (sprites/battle/<lugar>-base-<foe|mine>.webp).
const _baseAspect = {'foe': 32 / 128, 'mine': 86 / 272};

/// A base embaixo do Pokémon (com a cor do chão do lugar): o meio dela nos pés dele e a largura pelo tamanho dele. Vai
/// dentro da caixa (quadrada) do Pokémon, num Stack sem cortar, antes dele. Igual ao site (PlatformBase).
class PlatformBase extends StatefulWidget {
  const PlatformBase({super.key, required this.scene, required this.side, required this.id});
  final String scene, side;
  final int id;

  @override
  State<PlatformBase> createState() => _PlatformBaseState();
}

class _PlatformBaseState extends State<PlatformBase> {
  @override
  void initState() {
    super.initState();
    loadBattleHeight(widget.id, () => mounted ? setState(() {}) : null);
  }

  @override
  void didUpdateWidget(covariant PlatformBase old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) loadBattleHeight(widget.id, () => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (!sceneImages.contains(widget.scene)) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final size = box.maxWidth;
      final w = size * baseWidth(battleScale(battleHeights[widget.id]));
      final h = w * _baseAspect[widget.side]!;
      return Stack(clipBehavior: Clip.none, children: [
        Positioned(
          key: ValueKey('base-${widget.side}'),
          left: (size - w) / 2,
          top: size * 0.975 - h / 2,
          width: w,
          height: h,
          child: Image.asset('assets/database/sprites/battle/${widget.scene}-base-${widget.side}.webp',
              fit: BoxFit.fill, filterQuality: FilterQuality.none, errorBuilder: (_, __, ___) => const SizedBox()),
        ),
      ]);
    });
  }
}

/// Um Pokémon parado no campo (as telas da Battle Factory): do tamanho dele (pela altura), em cima da base dele, no
/// mesmo lugar da batalha. Vai num Positioned quadrado.
class StageMon extends StatefulWidget {
  const StageMon({super.key, required this.id, this.shiny = false, this.back = false, required this.scene});
  final int id;
  final bool shiny, back;
  final String scene;

  @override
  State<StageMon> createState() => _StageMonState();
}

class _StageMonState extends State<StageMon> {
  @override
  void initState() {
    super.initState();
    loadBattleHeight(widget.id, () => mounted ? setState(() {}) : null);
  }

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
        PlatformBase(scene: widget.scene, side: widget.back ? 'mine' : 'foe', id: widget.id),
        Transform.scale(
          scale: battleScale(battleHeights[widget.id]),
          alignment: Alignment.bottomCenter,
          child: PokemonSprite(widget.id, shiny: widget.shiny, back: widget.back, fill: 0.95, alignBottom: true, battle: true),
        ),
      ]);
}

/// O fundo da batalha no estilo Black & White: a imagem do lugar (se tiver) ou o desenho com as bases nos mesmos lugares.
class BattleBackdrop extends StatelessWidget {
  const BattleBackdrop({super.key, required this.scene, this.weather = ''});
  final String scene, weather;

  @override
  Widget build(BuildContext context) {
    if (!sceneImages.contains(scene)) return CustomPaint(painter: BattleScenePainter(scene: scene, weather: weather, bw: true), size: Size.infinite);
    // A versão do clima (quem chama troca com AnimatedSwitcher quando o golpe muda o clima).
    final sky = _weatherImage[weather];
    // Pixel art (256×192, como no DS): ampliada sem suavizar.
    final base = Image.asset('assets/database/sprites/battle/$scene.webp',
        fit: BoxFit.fill, width: double.infinity, height: double.infinity, filterQuality: FilterQuality.none,
        errorBuilder: (_, __, ___) => CustomPaint(painter: BattleScenePainter(scene: scene, weather: weather, bw: true), size: Size.infinite));
    if (sky == null) return base;
    // As versões do clima não vão no APK (fica menor): vêm do site; até chegar (ou sem internet), a normal.
    return Stack(fit: StackFit.expand, children: [
      base,
      Image.network('$weatherSite/sprites/battle-weather/$scene-$sky.webp',
          fit: BoxFit.fill,
          filterQuality: FilterQuality.none,
          frameBuilder: (_, child, frame, sync) => AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 600), child: child),
          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
    ]);
  }
}

class BattleScenePainter extends CustomPainter {
  const BattleScenePainter({this.scene = 'grass', this.weather = '', this.bw = false});
  final String scene, weather;
  final bool bw;

  /// As cores de cada lugar: [céu, chão, base escura, base clara]. 'grass' é o campo de sempre.
  static const colors = <String, List<int>>{
    'grass': [0xFFB9E6BD, 0xFFEDF9C8, 0xFF7EBA62, 0xFFA9D57B],
    'forest': [0xFF9FD39A, 0xFFD3EBB4, 0xFF4F8A3C, 0xFF6FAE4F],
    'water': [0xFF9FDCFF, 0xFF5FB4E8, 0xFF2F74B5, 0xFF5AA0DC],
    'cave': [0xFF5B5147, 0xFFA89C8A, 0xFF6B5F52, 0xFF8A7D6D],
    'mountain': [0xFFC9D3DC, 0xFFE7E2D4, 0xFF8F8A80, 0xFFABA497],
    'volcano': [0xFFF3B38A, 0xFFF7D9B5, 0xFFB4532A, 0xFFD0743E],
    'city': [0xFFC7D2FE, 0xFFE2E8F0, 0xFF94A3B8, 0xFFB6C2D1],
    'snow': [0xFFDBEAFE, 0xFFF8FAFC, 0xFFA5C3DD, 0xFFCFE0EF],
    'tower': [0xFFA78BFA, 0xFFDDD6FE, 0xFF7C6BA8, 0xFF9D8CC9],
    'sky': [0xFFBAE6FD, 0xFFF0F9FF, 0xFFCBD5E1, 0xFFE2E8F0],
    'center': [0xFFFBCFE8, 0xFFFDF2F8, 0xFFF472B6, 0xFFF9A8D4],
    'over': [0xFF94A3B8, 0xFFCBD5E1, 0xFF64748B, 0xFF94A3B8],
  };
  static const _weather = <String, List<int>>{
    'rain': [0xFFA1BAC4, 0xFFD6E3D6],
    'sun': [0xFFFFE4A1, 0xFFE8F6B6],
    'sand': [0xFFD1BD96, 0xFFEEE2AD],
    'hail': [0xFFBACBD8, 0xFFEEF5E3],
    'snow': [0xFFBACBD8, 0xFFEEF5E3],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final c = (colors[scene] ?? colors['grass']!).map(Color.new).toList();
    final sky = (_weather[weather] ?? [c[0].toARGB32(), c[1].toARGB32()]).map(Color.new).toList();
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: sky).createShader(rect));
    final sx = size.width / 160, sy = size.height / 100;
    // Coordenadas do campo (160 × 100), como no SVG do site.
    Paint fill(int color, [double opacity = 1]) => Paint()..color = Color(color).withValues(alpha: opacity);
    void box(double x, double y, double w, double h, Paint p) => canvas.drawRect(Rect.fromLTWH(x * sx, y * sy, w * sx, h * sy), p);
    void oval(double cx, double cy, double rx, double ry, Paint p) =>
        canvas.drawOval(Rect.fromCenter(center: Offset(cx * sx, cy * sy), width: rx * 2 * sx, height: ry * 2 * sy), p);
    void poly(List<double> pts, Paint p) {
      final path = Path()..moveTo(pts[0] * sx, pts[1] * sy);
      for (var i = 2; i < pts.length; i += 2) {
        path.lineTo(pts[i] * sx, pts[i + 1] * sy);
      }
      canvas.drawPath(path..close(), p);
    }

    switch (scene) {
      case 'city':
        const blocks = [[0, 14, 22], [16, 10, 30], [28, 16, 18], [46, 12, 26], [60, 18, 34], [80, 10, 22], [92, 16, 28], [110, 12, 20], [124, 18, 32], [144, 16, 24]];
        for (final b in blocks) {
          final x = b[0].toDouble(), w = b[1].toDouble(), h = b[2].toDouble();
          box(x, 40 - h, w, h, fill(0xFF94A3B8, 0.75));
          for (var r = 0; r < h ~/ 6; r++) {
            for (var k = 0; k < w ~/ 5; k++) {
              box(x + 1.5 + k * 5, 40 - h + 2 + r * 6, 2, 2.5, fill(0xFFFEF9C3, 0.8));
            }
          }
        }
        box(0, 40, 160, 3, fill(0xFF64748B, 0.6));
      case 'forest':
        const trees = [4, 16, 27, 40, 52, 66, 79, 92, 104, 117, 129, 142, 154];
        for (var i = 0; i < trees.length; i++) {
          final x = trees[i].toDouble();
          poly([x - 7, 42.0 - (i % 3) * 3, x, 18.0 - (i % 3) * 4, x + 7, 42.0 - (i % 3) * 3], fill(i.isOdd ? 0xFF2F6B2A : 0xFF3F7D32));
          box(x - 1, 41.0 - (i % 3) * 3, 2, 4, fill(0xFF5B3A1E));
        }
      case 'cave':
        box(0, 0, 160, 12, fill(0xFF3F372F));
        for (var i = 0; i < 16; i++) {
          poly([i * 10.0, 12, i * 10.0 + 5, 18.0 + (i % 3) * 5, i * 10.0 + 10, 12], fill(0xFF3F372F));
        }
        for (final r in const [[20, 60, 6], [70, 64, 4], [140, 58, 7]]) {
          oval(r[0].toDouble(), r[1].toDouble(), r[2] * 1.6, r[2].toDouble(), fill(0xFF6B5F52, 0.7));
        }
      case 'water':
        box(0, 38, 160, 62, fill(0xFF3B8FD4, 0.55));
        final wave = Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6 * sx;
        for (var r = 0; r < 9; r++) {
          for (var k = 0; k < 8; k++) {
            final x = k * 20.0 + (r % 2) * 10, y = 42 + r * 6.5;
            canvas.drawPath(
                Path()
                  ..moveTo(x * sx, y * sy)
                  ..quadraticBezierTo((x + 3) * sx, (y - 2) * sy, (x + 6) * sx, y * sy)
                  ..quadraticBezierTo((x + 9) * sx, (y + 2) * sy, (x + 12) * sx, y * sy),
                wave);
          }
        }
      case 'mountain' || 'volcano':
        final volcano = scene == 'volcano';
        poly([-10, 42, 30, 8, 70, 42], fill(volcano ? 0xFF7C2D12 : 0xFF8F8A80, 0.8));
        poly([50, 42, 100, 2, 150, 42], fill(volcano ? 0xFF9A3412 : 0xFFA8A29E, 0.85));
        poly([120, 42, 150, 16, 180, 42], fill(volcano ? 0xFF7C2D12 : 0xFF8F8A80, 0.8));
        if (volcano) {
          poly([92, 8, 100, 2, 108, 8], fill(0xFFF97316));
          for (final r in const [[100, -4, 6], [106, -10, 5], [96, -14, 4]]) {
            canvas.drawCircle(Offset(r[0] * sx, (r[1] + 4) * sy), r[2] * sx, fill(0xFF57534E, 0.5));
          }
        } else {
          poly([22, 15, 30, 8, 38, 15], fill(0xFFFFFFFF));
          poly([90, 10, 100, 2, 110, 10], fill(0xFFFFFFFF));
        }
      case 'snow':
        oval(30, 42, 45, 12, fill(0xFFFFFFFF, 0.9));
        oval(120, 40, 55, 14, fill(0xFFFFFFFF, 0.9));
        for (var i = 0; i < 30; i++) {
          canvas.drawCircle(Offset(((i * 37) % 160) * sx, ((i * 23) % 40) * sy), 0.8 * sx, fill(0xFFFFFFFF));
        }
      case 'tower':
        for (final x in const [10, 40, 120, 150]) {
          box(x - 4.0, 6, 8, 38, fill(0xFF5B4B8A, 0.8));
          box(x - 6.0, 4, 12, 3, fill(0xFF4C3D7A));
        }
        for (final g in const [[60, 40], [80, 42], [100, 40]]) {
          canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH((g[0] - 3) * sx, (g[1] - 7) * sy, 6 * sx, 8 * sy), Radius.circular(3 * sx)), fill(0xFF6D5BA3, 0.7));
        }
      case 'sky':
        for (final cl in const [[20, 14, 12], [70, 8, 16], [130, 18, 13], [100, 30, 9]]) {
          final x = cl[0].toDouble(), y = cl[1].toDouble(), r = cl[2].toDouble();
          oval(x, y, r, r * 0.45, fill(0xFFFFFFFF, 0.9));
          oval(x + r * 0.6, y - 2, r * 0.6, r * 0.4, fill(0xFFFFFFFF, 0.9));
        }
      case 'center':
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(64 * sx, 8 * sy, 32 * sx, 30 * sy), Radius.circular(3 * sx)), fill(0xFFFFFFFF, 0.8));
        box(77, 13, 6, 18, fill(0xFFEF4444));
        box(71, 19, 18, 6, fill(0xFFEF4444));
    }
    for (var i = 0; i < 50; i++) {
      box(0, i * 2.0, 160, 0.4, fill(0xFFFFFFFF, 0.2));
    }
    final (foe, mine) = _platforms[bw]!;
    for (final p in [foe, mine]) {
      oval(p[0], p[1], p[2], p[3], Paint()..color = c[2]);
      oval(p[0], p[1] - p[3] * 0.15, p[2] * 0.91, p[3] * 0.75, Paint()..color = c[3]);
    }
  }

  @override
  bool shouldRepaint(BattleScenePainter old) => old.scene != scene || old.weather != weather || old.bw != bw;
}
