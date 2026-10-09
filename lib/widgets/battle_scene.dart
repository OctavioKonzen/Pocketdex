// lib/widgets/battle_scene.dart
//
// O cenário da batalha: o campo clássico (faixas e duas bases) nas cores do
// lugar, com o que tem nele desenhado atrás: prédios na cidade, árvores na
// floresta, estalactites na caverna, ondas no mar, montanhas, vulcão, neve,
// torre, nuvens. O clima muda as cores do céu e do chão. Igual ao site
// (web-site/src/components/BattleScene.jsx).

import 'package:flutter/material.dart';

class BattleScenePainter extends CustomPainter {
  const BattleScenePainter({this.scene = 'grass', this.weather = ''});
  final String scene, weather;

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
    oval(120, 45, 32, 8, Paint()..color = c[2]);
    oval(120, 44, 29, 6, Paint()..color = c[3]);
    oval(38, 91, 42, 12, Paint()..color = c[2]);
    oval(38, 89, 39, 9, Paint()..color = c[3]);
  }

  @override
  bool shouldRepaint(BattleScenePainter old) => old.scene != scene || old.weather != weather;
}
