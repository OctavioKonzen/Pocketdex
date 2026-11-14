// Desenha as camadas de um golpe (o plano do battleFx.js) no instante [ms], com a câmera do golpe.
// Tudo em coordenadas do mundo (960 × 540); a câmera leva para a tela. Igual ao site (web-site/src/lib/fxPainter.js).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/battle_fx.dart';

double _clamp(num v, [double a = 0, double b = 1]) => v.toDouble().clamp(a, b);
double _lerp(double a, double b, double k) => a + (b - a) * k;
double _n(dynamic v, [double d = 0]) => v is num ? v.toDouble() : d;

/// Um número da camada no ponto [k] (0 a 1): fixo ou [de, até] (suave).
double _at(dynamic v, double k, [double d = 0]) {
  if (v is List && v.length == 2 && v[0] is num) return _lerp(_n(v[0]), _n(v[1]), BattleFx.ease(k));
  return _n(v, d);
}

/// O mesmo, em linha reta.
double _lin(dynamic v, double k, [double d = 0]) {
  if (v is List && v.length == 2 && v[0] is num) return _lerp(_n(v[0]), _n(v[1]), k);
  return _n(v, d);
}

/// O primeiro valor de um ponto que anda ([de, até]) ou o fixo.
double _first(dynamic v) => v is List ? _n(v[0]) : _n(v);
double _second(dynamic v) => v is List ? _n(v[1]) : _n(v);

final _colorCache = <String, Color>{};

/// '#rgb', '#rrggbb' ou 'rgba(r,g,b,a)'.
Color _color(String s) => _colorCache.putIfAbsent(s, () {
      if (s.startsWith('rgba')) {
        final p = s.substring(s.indexOf('(') + 1, s.indexOf(')')).split(',').map((x) => double.parse(x.trim())).toList();
        return Color.fromRGBO(p[0].round(), p[1].round(), p[2].round(), p[3]);
      }
      var h = s.substring(1);
      if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
      return Color(0xFF000000 | int.parse(h, radix: 16));
    });

Color _rgba(String s, double a) {
  final c = _color(s);
  return c.withValues(alpha: c.a * _clamp(a));
}

const _screenShapes = {'tint', 'fill', 'wave', 'surge'};

/// Aplica a câmera do golpe (o mundo vai para a tela de tamanho [size]).
void applyFxCamera(Canvas canvas, MoveFxPlan plan, double ms, Size size) {
  final c = BattleFx.camera(plan, ms);
  final (sx, sy) = BattleFx.shake(plan, ms);
  final fit = math.min(size.width / plan.world[0], size.height / plan.world[1]);
  canvas.translate(size.width / 2 + sx * fit, size.height / 2 + sy * fit);
  canvas.rotate(c[3] * math.pi / 180);
  canvas.scale(c[2] * fit, c[2] * fit);
  canvas.translate(-c[0], -c[1]);
}

/// A matriz da mesma câmera (para mover o campo inteiro: fundo e sprites).
Matrix4 fxCameraMatrix(MoveFxPlan plan, double ms, Size size) {
  final c = BattleFx.camera(plan, ms);
  final (sx, sy) = BattleFx.shake(plan, ms);
  final f = size.width / plan.world[0];
  return Matrix4.identity()
    ..translateByDouble(size.width / 2 + sx * f, size.height / 2 + sy * f, 0, 1)
    ..rotateZ(c[3] * math.pi / 180)
    ..scaleByDouble(c[2], c[2], 1, 1)
    ..translateByDouble(-c[0] * f, -c[1] * f, 0, 1);
}

class FxPainter extends CustomPainter {
  FxPainter(this.plan, this.ms);
  final MoveFxPlan plan;
  final double ms;

  late double _vw, _vh;

  @override
  void paint(Canvas canvas, Size size) {
    _vw = plan.world[0];
    _vh = plan.world[1];
    canvas.clipRect(Offset.zero & size);
    for (final l in plan.layers) {
      final t0 = _n(l['t0']), t1 = _n(l['t1']);
      if (ms < t0 || ms > t1) continue;
      final k = (ms - t0) / math.max(1, t1 - t0);
      canvas.save();
      final s = l['s'] as String;
      if (_screenShapes.contains(s)) {
        canvas.scale(size.width / _vw, size.height / _vh);
        switch (s) {
          case 'tint':
            _tint(canvas, l, k);
          case 'fill':
            _fill(canvas, l, k);
          case 'wave':
            _wave(canvas, l, k);
          case 'surge':
            _surge(canvas, l, k);
        }
      } else {
        applyFxCamera(canvas, plan, ms, size);
        switch (s) {
          case 'glow':
            _glow(canvas, l, k);
          case 'rays':
            _rays(canvas, l, k);
          case 'ring':
            _ring(canvas, l, k);
          case 'particles':
            _particles(canvas, l, k);
          case 'bolt':
            _bolt(canvas, l, k);
          case 'beam':
            _beam(canvas, l, k);
          case 'web':
            _web(canvas, l, k);
          case 'arc':
            _arc(canvas, l, k);
          case 'fangs':
            _fangs(canvas, l, k);
          case 'cone':
            _cone(canvas, l, k);
          case 'shot':
            _shot(canvas, l, k);
          case 'crack':
            _crack(canvas, l, k);
          case 'icon':
            _icon(canvas, l, k);
          case 'swords':
            _swords(canvas, l, k);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FxPainter old) => old.ms != ms || old.plan != plan;

  List<String> _cs(dynamic v) => v is List ? [for (final x in v) x as String] : [v as String];

  Paint _stroke(Color c, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..color = c
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _glow(Canvas canvas, Map l, double k) {
    final x = _at(l['x'], k), y = _at(l['y'], k), r = _at(l['r'], k), a = _at(l['a'], k);
    if (r <= 0 || a <= 0) return;
    final c = _cs(l['c']);
    if (l['trail'] != null) {
      final x0 = _at(l['x'], math.max(0, k - 0.25)), y0 = _at(l['y'], math.max(0, k - 0.25));
      final p = _stroke(Colors.white, r * 1.2)
        ..shader = ui.Gradient.linear(Offset(x0, y0), Offset(x, y) + const Offset(0.01, 0.01), [_rgba(c.last, 0), _rgba(c[1], 0.7 * a)]);
      canvas.drawLine(Offset(x0, y0), Offset(x, y), p);
    }
    final core = _n(l['core'], 0.15);
    final colors = <Color>[_rgba(c[0], a), _rgba(c[0], a), _rgba(c[1], a)];
    final stops = <double>[0, core, math.min(0.95, core + 0.3)];
    if (c.length > 2) {
      colors.add(_rgba(c[2], a * 0.9));
      stops.add(math.max(stops.last + 0.01, 0.85));
    }
    colors.add(_rgba(c.length > 3 ? c[3] : c.length > 2 ? c[2] : c[1], 0));
    stops.add(1);
    final paint = Paint()
      ..shader = ui.Gradient.radial(Offset(x, y), r, colors, stops, TileMode.clamp, null, Offset(x - r * 0.15, y - r * 0.15), r * 0.05);
    final spin = l['spin'];
    if (spin is num && spin != 0) {
      // Bola irregular girando (igual ao fxPainter.js).
      final rot = ms / 1000 * spin * math.pi * 2;
      final path = Path();
      for (var j = 0; j <= 28; j++) {
        final t = j / 28 * math.pi * 2;
        final rr = r * (0.9 + 0.13 * math.sin(3 * t + rot) + 0.07 * math.sin(5 * t - rot * 1.6 + 1));
        final p = Offset(x + math.cos(t) * rr, y + math.sin(t) * rr);
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
      final h = Offset(x + math.cos(rot) * r * 0.32, y + math.sin(rot) * r * 0.32);
      canvas.drawCircle(h, r * 0.5, Paint()..shader = ui.Gradient.radial(h, r * 0.5, [_rgba(c[0], 0.85 * a), _rgba(c[0], 0)]));
      final d = Offset(x - math.cos(rot) * r * 0.4, y - math.sin(rot) * r * 0.4);
      canvas.drawCircle(d, r * 0.55, Paint()..shader = ui.Gradient.radial(d, r * 0.55, [_rgba(c.last, 0.6 * a), _rgba(c.last, 0)]));
    } else {
      canvas.drawCircle(Offset(x, y), r, paint);
    }
    if (l['swirl'] != null) {
      final p = _stroke(_rgba(c[0], 0.7 * a), math.max(1, r * 0.06));
      for (var i = 0; i < 3; i++) {
        final s = ms / 160 + i * math.pi * 2 / 3;
        final rr = r * (0.45 + i * 0.15);
        canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: rr), s, 1.6, false, p);
      }
    }
  }

  void _rays(Canvas canvas, Map l, double k) {
    final x = _at(l['x'], k), y = _at(l['y'], k), a = _at(l['a'], k);
    final rot = _lin(l['rot'], k);
    final n = _n(l['n']).toInt();
    final c = l['c'] as String, c2 = (l['c2'] ?? l['c']) as String;
    for (var i = 0; i < n; i++) {
      final ang = i / n * math.pi * 2 + rot + BattleFx.rand(i) * 0.3;
      final r0 = _at(l['r0'], k);
      final r1 = _at(l['r1'], k) * (0.6 + 0.6 * BattleFx.rand(i + 20));
      final p0 = Offset(x + math.cos(ang) * r0, y + math.sin(ang) * r0);
      final p1 = Offset(x + math.cos(ang) * r1, y + math.sin(ang) * r1);
      if ((p1 - p0).distance < 0.5) continue;
      final p = _stroke(Colors.white, _at(l['w'], k) * (0.5 + BattleFx.rand(i + 40)))
        ..strokeCap = StrokeCap.butt
        ..shader = ui.Gradient.linear(p0, p1, [_rgba(c, a), _rgba(c2, 0)]);
      canvas.drawLine(p0, p1, p);
    }
  }

  void _ring(Canvas canvas, Map l, double k) {
    final n = _n(l['n'], 1).toInt();
    final staggered = l['stagger'] != null || l['spiral'] != null;
    for (var i = 0; i < n; i++) {
      final kk = staggered ? _clamp(k * (1 + (n - 1) * 0.35) - i * 0.35) : k;
      if (kk <= 0 || kk >= 1) continue;
      final x = _at(l['x'], kk), y = _at(l['y'], kk), r = _at(l['r'], kk), a = _at(l['a'], kk);
      final ratio = _n(l['ratio'], 1);
      final p = _stroke(_rgba(l['c'] as String, a), _at(l['w'], kk))..strokeCap = StrokeCap.butt;
      final rect = Rect.fromCenter(center: Offset(x, y), width: r * 2, height: r * 2 * ratio);
      if (l['spiral'] != null) {
        canvas.drawArc(rect, ms / 120 + i, math.pi * 1.5, false, p);
      } else {
        canvas.drawOval(rect, p);
      }
    }
  }

  /// Uma partícula no estilo do tipo.
  void _particle(Canvas canvas, String style, double x, double y, double s, String color, double a, double rot) {
    final col = _rgba(color, a);
    final fillP = Paint()..color = col;
    switch (style) {
      case 'ember':
      case 'spark':
      case 'dust':
      case 'glint':
        canvas.drawRect(Rect.fromLTWH(x - s / 2, y - s / 2, s, s), fillP);
        if (style == 'glint' || style == 'spark') {
          canvas.drawRect(Rect.fromLTWH(x - s * 1.4, y - s / 6, s * 2.8, s / 3), fillP);
          canvas.drawRect(Rect.fromLTWH(x - s / 6, y - s * 1.4, s / 3, s * 2.8), fillP);
        }
      case 'smoke':
        canvas.drawCircle(Offset(x, y), s * 2.5, Paint()..shader = ui.Gradient.radial(Offset(x, y), s * 2.5, [_rgba(color, a * 0.6), _rgba(color, 0)]));
      case 'bubble':
        canvas.drawCircle(Offset(x, y), s * 0.7, _stroke(col, math.max(1.5, s * 0.2)));
        canvas.drawRect(Rect.fromLTWH(x - s * 0.3, y - s * 0.35, s * 0.2, s * 0.2), fillP);
      case 'droplet':
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.8, height: s * 1.4), fillP);
        canvas.restore();
      case 'flame':
        canvas.drawCircle(Offset(x, y), s, Paint()..shader = ui.Gradient.radial(Offset(x, y), math.max(0.1, s), [_rgba(color, a), _rgba(color, 0)]));
      case 'leaf':
      case 'feather':
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.7, height: s * (style == 'feather' ? 1.8 : 1.4)), fillP);
        canvas.drawLine(Offset(0, -s * 0.6), Offset(0, s * 0.6), _stroke(Colors.white.withValues(alpha: _clamp(a) * 0.5), 1));
        canvas.restore();
      case 'shard':
      case 'crystal':
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        canvas.drawPath(
            Path()
              ..moveTo(0, -s)
              ..lineTo(s * 0.6, s * 0.2)
              ..lineTo(0, s * 0.8)
              ..lineTo(-s * 0.5, 0)
              ..close(),
            fillP);
        canvas.drawPath(
            Path()
              ..moveTo(0, -s)
              ..lineTo(s * 0.25, -s * 0.1)
              ..lineTo(-s * 0.15, 0)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: _clamp(a) * 0.6));
        canvas.restore();
      case 'wisp':
        canvas.drawCircle(Offset(x, y), s * 1.6,
            Paint()..shader = ui.Gradient.radial(Offset(x, y), math.max(0.1, s * 1.6), [_rgba(color, a), _rgba(color, a * 0.5), _rgba(color, 0)], [0, 0.5, 1]));
      case 'streak':
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        canvas.drawRect(Rect.fromLTWH(-s * 1.8, -s * 0.12, s * 3.6, s * 0.24), fillP);
        canvas.restore();
      case 'star':
        final path = Path();
        for (var i = 0; i < 8; i++) {
          final r = i.isOdd ? s * 0.28 : s;
          final an = rot + i * math.pi / 4;
          final pt = Offset(x + math.cos(an) * r, y + math.sin(an) * r);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), fillP);
      case 'arrowUp':
      case 'arrowDown':
        final d = style == 'arrowUp' ? -1.0 : 1.0;
        canvas.drawPath(
            Path()
              ..moveTo(x, y + d * s)
              ..lineTo(x + s * 0.8, y)
              ..lineTo(x + s * 0.3, y)
              ..lineTo(x + s * 0.3, y - d * s)
              ..lineTo(x - s * 0.3, y - d * s)
              ..lineTo(x - s * 0.3, y)
              ..lineTo(x - s * 0.8, y)
              ..close(),
            fillP);
      case 'pokeball':
        // A Poké Ball girando (vermelha em cima, branca embaixo, a faixa e o botão).
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        final rect = Rect.fromCircle(center: Offset.zero, radius: s);
        canvas.drawArc(rect, math.pi, math.pi, true, Paint()..color = const Color(0xFFEF4444));
        canvas.drawArc(rect, 0, math.pi, true, Paint()..color = const Color(0xFFF8FAFC));
        final edge = _stroke(const Color(0xFF111827), math.max(2, s * 0.16));
        canvas.drawCircle(Offset.zero, s, edge);
        canvas.drawLine(Offset(-s, 0), Offset(s, 0), edge);
        canvas.drawCircle(Offset.zero, s * 0.32, Paint()..color = const Color(0xFFF8FAFC));
        canvas.drawCircle(Offset.zero, s * 0.32, edge);
        canvas.restore();
      case 'heart':
        canvas.drawPath(
            Path()
              ..moveTo(x, y + s * 0.7)
              ..cubicTo(x - s * 1.2, y - s * 0.1, x - s * 0.5, y - s * 0.95, x, y - s * 0.35)
              ..cubicTo(x + s * 0.5, y - s * 0.95, x + s * 1.2, y - s * 0.1, x, y + s * 0.7),
            fillP);
      case 'note':
        canvas.drawRect(Rect.fromLTWH(x + s * 0.25, y - s, s * 0.14, s * 1.1), fillP);
        canvas.drawRect(Rect.fromLTWH(x + s * 0.25, y - s, s * 0.55, s * 0.18), fillP);
        canvas.save();
        canvas.translate(x, y + s * 0.1);
        canvas.rotate(-0.4);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: s * 0.68, height: s * 0.48), fillP);
        canvas.restore();
      case 'zzz':
        final tp = TextPainter(
          text: TextSpan(text: 'Z', style: TextStyle(color: col, fontSize: math.max(1, s), fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x, y - tp.height * 0.8));
      case 'gear':
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(rot);
        final path = Path()..fillType = PathFillType.evenOdd;
        for (var i = 0; i < 16; i++) {
          final r = i.isOdd ? s * 0.7 : s;
          final a0 = i / 16 * math.pi * 2;
          i == 0 ? path.moveTo(math.cos(a0) * r, math.sin(a0) * r) : path.lineTo(math.cos(a0) * r, math.sin(a0) * r);
        }
        path
          ..close()
          ..addOval(Rect.fromCircle(center: Offset.zero, radius: s * 0.3));
        canvas.drawPath(path, fillP);
        canvas.restore();
      case 'moon':
        final path = Path()
          ..addArc(Rect.fromCircle(center: Offset(x, y), radius: s), 0.6, math.pi * 2 - 1.2)
          ..arcTo(Rect.fromCircle(center: Offset(x + s * 0.55, y - s * 0.1), radius: s * 0.75), math.pi * 2 - 0.9, 1.8 - math.pi * 2, false)
          ..close();
        canvas.drawPath(path, fillP);
      case 'sun':
        canvas.drawCircle(Offset(x, y), s * 0.55, fillP);
        final p = _stroke(col, math.max(2, s * 0.14));
        for (var i = 0; i < 8; i++) {
          final an = rot + i * math.pi / 4;
          canvas.drawLine(Offset(x + math.cos(an) * s * 0.75, y + math.sin(an) * s * 0.75), Offset(x + math.cos(an) * s * 1.15, y + math.sin(an) * s * 1.15), p);
        }
      case 'goo':
        canvas.drawCircle(Offset(x, y), s * 0.6, fillP);
        canvas.drawRect(Rect.fromLTWH(x - s * 0.3, y - s * 0.35, s * 0.18, s * 0.18), Paint()..color = Colors.white.withValues(alpha: _clamp(a) * 0.7));
      case 'rain':
        canvas.drawLine(Offset(x, y), Offset(x - s * 0.3, y + s), _stroke(col, 2));
      case 'fist':
      case 'foot':
      case 'head':
      case 'body':
      case 'wing':
        _drawIcon(canvas, style, x, y, s, col, rot);
      default:
        // dot: bolinha de luz.
        canvas.drawCircle(
            Offset(x, y),
            s,
            Paint()
              ..shader = ui.Gradient.radial(Offset(x, y), math.max(0.1, s), [_rgba('#ffffff', a), _rgba(color, a), _rgba(color, 0)], [0, 0.4, 1]));
    }
  }

  void _particles(Canvas canvas, Map l, double k) {
    final t0 = _n(l['t0']), t1 = _n(l['t1']);
    final span = t1 - t0;
    final age0 = ms - t0;
    final life = _n(l['life'], 1);
    final n = _n(l['n']).toInt();
    final seed = _n(l['seed'], 1);
    final mode = l['mode'] as String? ?? 'stream';
    final c = _cs(l['c']);
    final size = l['size'] as List;
    final style = l['style'] as String? ?? 'dot';
    final ox = _first(l['x']), oy = _first(l['y']);
    final sxv = _n(l['sx']), syv = _n(l['sy']);
    for (var i = 0; i < n; i++) {
      final r1 = BattleFx.rand(seed * 7.3 + i);
      final r2 = BattleFx.rand(seed * 3.1 + i * 1.7);
      final r3 = BattleFx.rand(seed * 5.9 + i * 2.3);
      final born = mode == 'burst' ? r1 * 60 : mode == 'orbit' ? 0.0 : r1 * math.max(1, span - life);
      final t = (age0 - born) / life;
      if (t < 0 || t > 1) continue;
      final sec = (age0 - born) / 1000;
      double x, y;
      switch (mode) {
        case 'burst':
          final ang = r2 * math.pi * 2;
          final sp = _n(l['v']) * (0.4 + r3);
          x = ox + math.cos(ang) * sp * sec + (r1 - 0.5) * sxv;
          y = oy + math.sin(ang) * sp * sec + _n(l['vy']) * sec + 0.5 * _n(l['g']) * sec * sec + (r3 - 0.5) * syv;
        case 'converge':
          final ang = r2 * math.pi * 2;
          final d = _n(l['r']) * (1 - BattleFx.ease(t)) * (0.6 + r3 * 0.6);
          x = ox + math.cos(ang + t * 1.5) * d;
          y = oy + math.sin(ang + t * 1.5) * d;
        case 'orbit':
          final ang = i / n * math.pi * 2 + age0 / 1000 * 4;
          x = ox + math.cos(ang) * _n(l['r']);
          y = oy + math.sin(ang) * _n(l['r']) * 0.4;
        case 'swirl':
          final ang = r2 * math.pi * 2 + t * 6;
          final d = _n(l['r']) * (0.3 + 0.7 * (1 - t)) * (0.6 + r3 * 0.6);
          x = ox + math.cos(ang) * d;
          y = oy + math.sin(ang) * d * 0.5 - t * 80;
        case 'trail':
        case 'travel':
        case 'jet':
          final x1 = _second(l['x']), y1 = _second(l['y']);
          final p = mode == 'trail' ? _clamp((born + life * 0.3) / span) : mode == 'jet' ? t : BattleFx.ease(t);
          final open = mode == 'jet' ? _n(l['spread'], 20) * p : 1;
          final wob = mode == 'travel' ? math.sin(t * 6 + i) * 18 : 0;
          x = _lerp(ox, x1, p) + (r2 - 0.5) * (sxv + open * 2) + wob;
          y = _lerp(oy, y1, p) + (r3 - 0.5) * (syv + open * 2) - (mode == 'trail' ? sec * 40 : 0);
        default:
          x = ox + (r2 - 0.5) * 2 * sxv + _n(l['v']) * (r3 - 0.5) * sec * 2;
          y = oy + (r3 - 0.5) * 2 * syv + _n(l['vy']) * (0.6 + r1 * 0.6) * sec + 0.5 * _n(l['g']) * sec * sec;
      }
      final sz = _lerp(_n(size[0]), _n(size[1]), t) * (0.7 + r2 * 0.6);
      final ci = math.min(c.length - 1, (t * c.length + r3 * 0.6).floor());
      final fade = mode == 'converge' ? math.min(1.0, t * 3) : mode == 'orbit' ? math.min(1.0, math.min(t * 5, (1 - t) * 5)) : 1 - t * t;
      _particle(canvas, style, x, y, sz, c[ci], fade, r1 * 6 + t * 4 * (r2 - 0.5));
    }
  }

  void _bolt(Canvas canvas, Map l, double k) {
    final flick = l['flicker'] != null ? (ms / 50).floor() : 0;
    final x = _n(l['x']), y = _n(l['y']);
    final from = l['from'] as Map?;
    final paths = <(Offset, Offset)>[];
    if (from != null) {
      paths.add((Offset(_n(from['x']), _n(from['y'])), Offset(x, y)));
    } else {
      for (var i = 0; i < _n(l['n']).toInt(); i++) {
        final ang = BattleFx.rand(i * 3 + flick) * math.pi * 2;
        paths.add((Offset(x, y), Offset(x + math.cos(ang) * _n(l['r']), y + math.sin(ang) * _n(l['r']) * 0.8)));
      }
    }
    final w = _n(l['w'], 2);
    for (var j = 0; j < paths.length; j++) {
      if (l['flicker'] != null && BattleFx.rand(j + flick * 7) < 0.25) continue;
      final (p, q) = paths[j];
      final steps = from != null ? _n(l['n']).toInt() : 5;
      final path = Path()..moveTo(p.dx, p.dy);
      for (var i = 1; i < steps; i++) {
        final u = i / steps;
        final nx = -(q.dy - p.dy), ny = q.dx - p.dx;
        final len = math.max(1, math.sqrt(nx * nx + ny * ny));
        final off = (BattleFx.rand(i * 11 + j * 5 + flick * 3) - 0.5) * (from != null ? 70 : 26);
        path.lineTo(_lerp(p.dx, q.dx, u) + nx / len * off, _lerp(p.dy, q.dy, u) + ny / len * off);
      }
      path.lineTo(q.dx, q.dy);
      for (final (ww, c, a) in [(w * 4, l['c2'] as String, 0.35), (w * 1.6, l['c2'] as String, 0.8), (w * 0.7, l['c'] as String, 1.0)]) {
        canvas.drawPath(path, _stroke(_rgba(c, a * (1 - k * 0.3)), ww));
      }
    }
  }

  void _beam(Canvas canvas, Map l, double k) {
    final grow = _clamp((ms - _n(l['t0'])) / _n(l['grow'], 1));
    final x0 = _n(l['x0']), y0 = _n(l['y0']);
    final x1 = _lerp(x0, _n(l['x1']), grow), y1 = _lerp(y0, _n(l['y1']), grow);
    final w = _at(l['w'], math.min(1, k * 4)) * (1 - math.max(0, k - 0.8) * 5);
    if (w <= 0) return;
    final wob = math.sin(ms / 30) * _n(l['wobble']);
    final c = _cs(l['c']);
    for (final (m, col, a) in [(2.2, c[2], 0.35), (1.3, c[1], 0.8), (0.55, c[0], 1.0)]) {
      canvas.drawLine(Offset(x0, y0), Offset(x1, y1), _stroke(_rgba(col, a), math.max(1, w * m + wob)));
    }
  }

  void _web(Canvas canvas, Map l, double k) {
    final r = _at(l['r'], math.min(1, k * 2.5));
    final a = k < 0.75 ? 1.0 : 1 - (k - 0.75) * 4;
    final t = _n(l['t0']) + k * (_n(l['t1']) - _n(l['t0']));
    final ch = l['charge'] as List?;
    final charged = ch != null && t >= _n(ch[0]) && t <= _n(ch[1]) && (ms / 60).floor() % 3 != 0;
    final col = (charged ? l['c2'] : l['c']) as String;
    final n = _n(l['n']).toInt(), rings = _n(l['rings']).toInt();
    final x = _n(l['x']), y = _n(l['y']);
    double ang(int i) => i / n * math.pi * 2 + 0.2;
    final path = Path();
    for (var i = 0; i < n; i++) {
      path
        ..moveTo(x, y)
        ..lineTo(x + math.cos(ang(i)) * r, y + math.sin(ang(i)) * r * 0.8);
    }
    for (var j = 1; j <= rings; j++) {
      final rr = r * j / rings;
      for (var i = 0; i <= n; i++) {
        final sag = i.isOdd ? 0.92 : 1.0;
        final px = x + math.cos(ang(i)) * rr * sag, py = y + math.sin(ang(i)) * rr * 0.8 * sag;
        i == 0 ? path.moveTo(px, py) : path.lineTo(px, py);
      }
    }
    canvas.drawPath(path, _stroke(_rgba(col, a), _n(l['w']) * (charged ? 1.4 : 1))..strokeCap = StrokeCap.butt);
    if (charged) canvas.drawPath(path, _stroke(_rgba('#ffffff', a * 0.6), 1));
  }

  void _arc(Canvas canvas, Map l, double k) {
    final a1 = _at(l['a1'], math.min(1, k * 2.2));
    final a0r = _n(l['a0']);
    final a0 = a0r + (a1 - a0r) * math.max(0, (k - 0.45) * 1.8);
    final fade = k < 0.6 ? 1.0 : 1 - (k - 0.6) * 2.5;
    if (fade <= 0) return;
    canvas.save();
    canvas.translate(_n(l['x']), _n(l['y']));
    if (l['flip'] != null && l['flip'] != 0) canvas.scale(-1, 1);
    final r = _n(l['r']);
    final rect = Rect.fromCircle(center: Offset.zero, radius: r);
    for (final (w, c, a) in [(_n(l['w']) * 2.4, l['c2'] as String, 0.45), (_n(l['w']), l['c'] as String, 1.0)]) {
      if (a1 - a0 > 0.001) canvas.drawArc(rect, a0, a1 - a0, false, _stroke(_rgba(c, a * fade), w));
    }
    canvas.restore();
  }

  void _fangs(Canvas canvas, Map l, double k) {
    final c = _at(l['close'], math.min(1, k * 2));
    final fade = k < 0.6 ? 1.0 : 1 - (k - 0.6) * 2.5;
    if (fade <= 0) return;
    final r = _n(l['r']), x0 = _n(l['x']), y0 = _n(l['y']);
    for (final d in [-1.0, 1.0]) {
      final y = y0 + d * r * (1 - c) * 0.9;
      final path = Path();
      for (var i = 0; i < 4; i++) {
        final x = x0 - r * 0.75 + i * r * 0.5;
        path
          ..moveTo(x - r * 0.2, y - d * r * 0.35)
          ..lineTo(x, y + d * r * 0.3)
          ..lineTo(x + r * 0.2, y - d * r * 0.35);
      }
      path.close();
      canvas.drawPath(path, Paint()..color = _rgba(l['c'] as String, fade));
      canvas.drawPath(path, _stroke(_rgba(l['c2'] as String, fade), 3));
    }
  }

  void _cone(Canvas canvas, Map l, double k) {
    final x = _at(l['x'], k), y = _at(l['y'], k), w = _n(l['w']);
    final c = l['c'] as String;
    final p = Paint()..shader = ui.Gradient.linear(Offset(x, y - 160), Offset(x, y), [_rgba(c, 0), _rgba(c, _n(l['a'], 1))]);
    canvas.drawPath(
        Path()
          ..moveTo(x - w / 2, y - 160)
          ..lineTo(x + w / 2, y - 160)
          ..lineTo(x, y)
          ..close(),
        p);
    canvas.drawCircle(Offset(x, y), w * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.9));
  }

  static const _plainShots = {'dot', 'ember', 'flame', 'spark', 'bubble', 'droplet', 'goo', 'wisp', 'glint', 'dust', 'streak'};

  void _shot(Canvas canvas, Map l, double k) {
    final arcH = _n(l['arc']);
    double lift(double u) => arcH == 0 ? 0 : math.sin(u * math.pi) * arcH;
    final x = _at(l['x'], k), y = _at(l['y'], k) - lift(k);
    final kb = math.max(0.0, k - 0.3);
    final x0 = _at(l['x'], kb), y0 = _at(l['y'], kb) - lift(kb);
    final c = _cs(l['c']);
    final r = _n(l['r']);
    if (l['trail'] != null && (Offset(x, y) - Offset(x0, y0)).distance > 0.5) {
      canvas.drawLine(
          Offset(x0, y0), Offset(x, y), _stroke(Colors.white, r * 1.1)..shader = ui.Gradient.linear(Offset(x0, y0), Offset(x, y), [_rgba(c[2], 0), _rgba(c[1], 0.8)]));
    }
    final style = l['style'] as String? ?? 'dot';
    if (!_plainShots.contains(style)) {
      _particle(canvas, style, x, y, r * 1.3, style == 'shard' || style == 'crystal' ? c[2] : c[1], 1, k * 8 * _n(l['spin'], 1));
    } else {
      canvas.drawCircle(
          Offset(x, y), r, Paint()..shader = ui.Gradient.radial(Offset(x, y), math.max(0.1, r), [_color(c[0]), _color(c[1]), _rgba(c[2], 0.2)], [0, 0.5, 1]));
    }
  }

  void _crack(Canvas canvas, Map l, double k) {
    final r = _at(l['r'], math.min(1, k * 2)), a = _at(l['a'], k);
    final n = _n(l['n']).toInt(), x0 = _n(l['x']), y0 = _n(l['y']);
    for (var i = 0; i < n; i++) {
      final ang = math.pi + i / (n - 1) * math.pi + (BattleFx.rand(i) - 0.5) * 0.3;
      final path = Path()..moveTo(x0, y0);
      for (var j = 1; j <= 6; j++) {
        final d = r * j / 6;
        path.lineTo(x0 + math.cos(ang + (BattleFx.rand(i * 9 + j) - 0.5) * 0.5) * d * 1.6, y0 + (BattleFx.rand(i * 5 + j) - 0.5) * 18 + math.sin(ang) * d * 0.25);
      }
      canvas.drawPath(path, _stroke(_rgba(l['c2'] as String, a * 0.5), 9));
      canvas.drawPath(path, _stroke(_rgba(l['c'] as String, a), 4));
    }
  }

  void _tint(Canvas canvas, Map l, double k) {
    canvas.drawRect(Rect.fromLTWH(0, 0, _vw, _vh), Paint()..color = _rgba(l['color'] as String, _at(l['a'], k)));
  }

  void _fill(Canvas canvas, Map l, double k) {
    final fade = k < 0.6 ? 1.0 : 1 - (k - 0.6) * 2.5;
    const b = 16.0;
    final from = l['from'] as String? ?? 'right';
    final front = from == 'center' ? null : from == 'right' ? _vw * (1.1 - k * 1.7) : _vw * (-0.1 + k * 1.7);
    final c = _cs(l['c']);
    final a = _n(l['a'], 1);
    for (var by = 0.0; by < _vh; by += b) {
      for (var bx = 0.0; bx < _vw; bx += b) {
        final double d = front == null
            ? 260 * k * 3 - math.sqrt((bx - 480) * (bx - 480) + (by - 270) * (by - 270)) + BattleFx.rand(by * 7 + bx) * 120
            : (from == 'right' ? bx - front : front - bx) + BattleFx.rand(by * 7 + bx) * 140;
        if (d < 0) continue;
        final ci = (BattleFx.rand(bx * 3 + by * 11 + (ms / 80).floor()) * c.length).floor().clamp(0, c.length - 1);
        canvas.drawRect(Rect.fromLTWH(bx, by, b, b), Paint()..color = _rgba(c[ci], math.min(1, d / 120) * a * fade));
      }
    }
  }

  void _wave(Canvas canvas, Map l, double k) {
    final dir = _n(l['dir'], 1);
    final x = dir > 0 ? _lerp(-500, 1200, k) : _lerp(1460, -240, k);
    final hl = l['h'] as List;
    final h = _lerp(_n(hl[0]), _n(hl[1]), math.sin(k * math.pi)) * _vh;
    final c = _cs(l['c']);
    for (var band = 0; band < 4; band++) {
      final off = band * 60 * -dir;
      final path = Path()..moveTo(x + off - 600 * dir, _vh);
      for (var i = 0; i <= 30; i++) {
        final px = x + off - 600 * dir + i / 30 * 600 * dir;
        final crest = math.pow(i / 30, 2.4);
        final py = _vh - h * (0.25 + 0.75 * crest) * (1 - band * 0.12) + math.sin(i * 0.9 + ms / 90 + band) * 8;
        path.lineTo(px, py);
      }
      path
        ..lineTo(x + off, _vh)
        ..close();
      canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, _vh - h), Offset(0, _vh), [_rgba(c[math.min(3, band)], 0.85), _rgba(c[3], 0.95)]));
    }
    final foam = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var i = 0; i < 18; i++) {
      canvas.drawRect(Rect.fromLTWH(x - dir * BattleFx.rand(i) * 120, _vh - h + BattleFx.rand(i + 5) * 40, 8, 8), foam);
    }
  }

  /// A onda do Surf como no Black & White, em pixels (igual a surge do fxPainter.js).
  void _surge(Canvas canvas, Map l, double k) {
    const b = 12.0;
    final c = _cs(l['c']);
    final a = _n(l['a'], 0.92);
    final dir = _n(l['dir'], 1);
    double sm(double t) => t * t * (3 - 2 * t);
    final rise = _clamp(k / 0.25), sweep = _clamp((k - 0.2) / 0.5), drain = _clamp((k - 0.72) / 0.28);
    final h = _vh * (0.3 + 0.62 * sm(rise)) * (1 - sm(drain));
    if (h <= 1) return;
    final f = _lerp(-60, 160, sm(rise)) + sm(sweep) * (_vw + 420);
    double xOf(double u) => dir > 0 ? u : _vw - u - b;
    double top(double u) {
      final t = _clamp((u - (f - 520)) / 520);
      final y = _vh - h * (0.72 + 0.28 * t * t) + math.sin(u * 0.035 + ms / 90) * 10;
      return (y / b).roundToDouble() * b;
    }

    void band(double x, double y0, double y1, String col, double al) {
      if (y1 <= y0) return;
      canvas.drawRect(Rect.fromLTWH(x, y0, b, y1 - y0), Paint()..color = _rgba(col, al));
    }

    for (var u = 0.0; u < _vw; u += b) {
      final x = xOf(u);
      if (u <= f) {
        final y = top(u);
        final mid = y + 3 * b + (_vh - y) * 0.3;
        band(x, y, y + b, c[0], a);
        band(x, y + b, y + 3 * b, c[1], a);
        band(x, y + 3 * b, mid, c[2], a);
        band(x, mid, _vh, c[3], a);
      } else if (u <= f + 96 && drain == 0) {
        final q = (u - f) / 96;
        final y = ((_vh - h * 1.04 + q * q * h * 0.42) / b).roundToDouble() * b;
        final th = math.max(b, ((b * 3 * (1 - q * 0.6)) / b).roundToDouble() * b);
        band(x, y, y + b, c[0], a);
        band(x, y + b, y + th, c[1], a * (1 - q * 0.4));
      }
    }
    for (var i = 0; i < 16; i++) {
      var u = (BattleFx.rand(i) * _vw + ms * 0.25 * (i % 3 != 0 ? 1 : -1)) % _vw;
      if (u < 0) u += _vw;
      if (u > f) continue;
      final y0 = top(u) + 4 * b;
      final y = y0 + BattleFx.rand(i + 30) * math.max(0, _vh - y0);
      canvas.drawRect(Rect.fromLTWH(xOf((u / b).roundToDouble() * b), (y / (b / 2)).roundToDouble() * (b / 2), b * 3, b / 2), Paint()..color = _rgba(c[1], 0.55 * a));
    }
    if (drain == 0) {
      for (var i = 0; i < 22; i++) {
        final u = f + BattleFx.rand(i + 50) * 110 - 30 + math.sin(ms / 70 + i) * 8;
        final y = _vh - h * 1.04 - BattleFx.rand(i + 70) * 70 + ((ms / 6 + i * 13) % 50);
        canvas.drawRect(Rect.fromLTWH(xOf((u / (b / 2)).roundToDouble() * (b / 2)), (y / (b / 2)).roundToDouble() * (b / 2), b / 2, b / 2), Paint()..color = _rgba(c[0], 0.9 * a));
      }
    }
  }

  /// As espadas do Swords Dance girando em volta do Pokémon (igual a swords do fxPainter.js).
  void _swords(Canvas canvas, Map l, double k) {
    final c = _cs(l['c']);
    final join = _clamp((k - 0.8) / 0.2);
    final rot = ms / 1000 * _n(l['spin']) * math.pi * 2;
    final n = _n(l['n']).toInt();
    final x0 = _n(l['x']), y0 = _n(l['y']), rx = _n(l['rx']), ry = _n(l['ry']), size = _n(l['size']), top = _n(l['top']);
    final list = <(double, double, double, double, double, double)>[];
    for (var i = 0; i < n; i++) {
      final show = _clamp((k - i * 0.07) / 0.08);
      if (show <= 0) continue;
      final t = rot + i / n * math.pi * 2;
      final depth = math.sin(t);
      list.add((
        _lerp(x0 + math.cos(t) * rx, x0, join),
        _lerp(y0 + depth * ry, top, join),
        depth,
        size * (0.82 + 0.18 * depth) * (0.4 + 0.6 * show),
        (depth < 0 ? 0.55 : 1) * show * (1 - _clamp((k - 0.95) / 0.05)),
        join * (i.isOdd ? 0.6 : -0.6),
      ));
    }
    list.sort((p, q) => p.$3.compareTo(q.$3));
    for (final p in list) {
      final (x, y, _, s, a, tilt) = p;
      final u = math.max(2, (s / 14).round()).toDouble();
      canvas.save();
      canvas.translate(x.roundToDouble(), y.roundToDouble());
      canvas.rotate(tilt);
      void r(double px, double py, double w, double h, String col) => canvas.drawRect(Rect.fromLTWH(px * u, py * u, w * u, h * u), Paint()..color = _rgba(col, a));
      r(-2, -8, 4, 11, c[2]);
      r(-1, -10, 2, 2, c[2]);
      r(-1, -8, 2, 11, c[1]);
      r(-1, -9, 1, 1, c[1]);
      r(0, -8, 1, 10, c[0]);
      r(-4, 3, 8, 2, c[2]);
      r(-3, 3, 6, 1, c[4]);
      r(-1, 5, 2, 4, c[3]);
      r(-2, 9, 4, 1, c[4]);
      canvas.restore();
      canvas.drawCircle(Offset(x, y - s * 0.25), s * 0.22, Paint()..color = _rgba(c[0], a * 0.15));
    }
  }

  void _icon(Canvas canvas, Map l, double k) {
    final x = _at(l['x'], k), y = _at(l['y'], k), s = _at(l['size'], k), a = _at(l['a'], k);
    final c = _cs(l['c']);
    if (s <= 0) return;
    canvas.drawCircle(Offset(x, y), s * 1.3, Paint()..shader = ui.Gradient.radial(Offset(x, y), s * 1.3, [_rgba(c[0], 0.7 * a), _rgba(c[1], 0)]));
    _particle(canvas, l['style'] as String? ?? 'star', x, y, s * 0.6, c[1], a, _n(l['rot']));
  }

  void _drawIcon(Canvas canvas, String style, double x, double y, double s, Color color, double rot) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rot);
    final fillP = Paint()..color = color;
    final edge = _stroke(Colors.black.withValues(alpha: 0.55 * color.a), math.max(2, s * 0.08));
    void shape(Path p) {
      canvas.drawPath(p, fillP);
      canvas.drawPath(p, edge);
    }

    if (style == 'fist') {
      shape(Path()..addRRect(RRect.fromLTRBR(-s * 0.7, -s * 0.55, s * 0.55, s * 0.5, Radius.circular(s * 0.3))));
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(Offset(-s * 0.35 + i * s * 0.32, -s * 0.55), Offset(-s * 0.35 + i * s * 0.32, -s * 0.1), edge);
      }
      shape(Path()..addRRect(RRect.fromLTRBR(-s * 0.95, -s * 0.15, -s * 0.5, s * 0.4, Radius.circular(s * 0.18))));
    } else if (style == 'foot') {
      canvas.save();
      canvas.rotate(0.3);
      shape(Path()..addOval(Rect.fromCenter(center: Offset.zero, width: s * 0.9, height: s * 1.7)));
      canvas.restore();
      for (var i = 0; i < 3; i++) {
        shape(Path()..addOval(Rect.fromCircle(center: Offset(-s * 0.35 + i * s * 0.3, -s * 0.85), radius: s * 0.16)));
      }
    } else if (style == 'wing') {
      for (var i = 0; i < 4; i++) {
        canvas.save();
        canvas.translate(-s * 0.2 + i * s * 0.18, -s * 0.1 + i * s * 0.12);
        canvas.rotate(-0.7);
        shape(Path()..addOval(Rect.fromCenter(center: Offset.zero, width: s * 0.44, height: s * (1.8 - i * 0.3))));
        canvas.restore();
      }
    } else {
      final path = Path();
      for (var i = 0; i < 16; i++) {
        final r = i.isOdd ? s * 0.45 : s;
        final an = i * math.pi / 8;
        i == 0 ? path.moveTo(math.cos(an) * r, math.sin(an) * r) : path.lineTo(math.cos(an) * r, math.sin(an) * r);
      }
      shape(path..close());
    }
    canvas.restore();
  }
}
