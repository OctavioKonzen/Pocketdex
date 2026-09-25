// lib/widgets/pokedex_web/pokeball_reveal.dart
//
// Animação do Pokémon saindo da Pokébola: a Pokébola cai, balança, abre com
// um clarão e o Pokémon sai crescendo (primeiro branco, depois colorido).
// A animação roda sempre que o widget é criado — use uma `key` diferente
// para repetir (ex.: ao trocar de Pokémon).

import 'dart:math' as math;
import 'package:flutter/material.dart';

class PokeballReveal extends StatefulWidget {
  final Widget child;
  final double ballSize;
  final Duration duration;

  const PokeballReveal({
    super.key,
    required this.child,
    this.ballSize = 90,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PokeballReveal> createState() => _PokeballRevealState();
}

class _PokeballRevealState extends State<PokeballReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();

  // Etapas da animação (frações da duração total).
  late final Animation<double> _drop = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.25, curve: Curves.bounceOut));
  late final Animation<double> _wiggle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.48, curve: Curves.linear));
  late final Animation<double> _open = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.60, curve: Curves.easeOut));
  late final Animation<double> _flash = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.78, curve: Curves.easeOut));
  late final Animation<double> _grow = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.52, 0.92, curve: Curves.easeOutBack));
  late final Animation<double> _color = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 1.0, curve: Curves.easeIn));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final ballVisible = _open.value < 1;
        final wiggle =
            math.sin(_wiggle.value * math.pi * 4) * 0.25 * (1 - _wiggle.value);
        final flash = math.sin(_flash.value * math.pi);

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Pokémon saindo (cresce a partir da Pokébola, branco → colorido).
            if (_grow.value > 0)
              Positioned.fill(
                child: Transform.scale(
                  scale: _grow.value.clamp(0.0, 1.2),
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      Colors.white.withValues(alpha: 1 - _color.value),
                      BlendMode.srcATop,
                    ),
                    child: child,
                  ),
                ),
              )
            else
              const Positioned.fill(child: SizedBox()),
            // Clarão.
            if (flash > 0)
              IgnorePointer(
                child: Container(
                  width: widget.ballSize * (1 + 4 * _flash.value),
                  height: widget.ballSize * (1 + 4 * _flash.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      Colors.white.withValues(alpha: 0.95 * flash),
                      Colors.white.withValues(alpha: 0),
                    ]),
                  ),
                ),
              ),
            // Pokébola caindo, balançando e abrindo.
            if (ballVisible)
              Opacity(
                opacity: (1 - _open.value).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -140 * (1 - _drop.value)),
                  child: Transform.rotate(
                    angle: wiggle,
                    child: CustomPaint(
                      size: Size.square(widget.ballSize),
                      painter: _PokeballPainter(open: _open.value),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Pokébola vermelha e branca; [open] de 0 a 1 levanta a metade de cima.
class _PokeballPainter extends CustomPainter {
  final double open;

  _PokeballPainter({required this.open});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final center = Offset(r, r);
    final outline = Paint()
      ..color = const Color(0xFF222222)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.12;
    final rect = Rect.fromCircle(center: center, radius: r);

    // Metade de baixo (branca).
    canvas.drawArc(rect, 0, math.pi, true, Paint()..color = Colors.white);
    canvas.drawArc(rect, 0, math.pi, false, outline);

    // Metade de cima (vermelha), girando na "dobradiça" da esquerda.
    canvas.save();
    canvas.translate(0, r);
    canvas.rotate(-open * 1.1);
    canvas.translate(0, -r);
    canvas.drawArc(
        rect, math.pi, math.pi, true, Paint()..color = const Color(0xFFE3350D));
    canvas.drawArc(rect, math.pi, math.pi, false, outline);
    canvas.drawLine(Offset(0, r), Offset(size.width, r), outline);
    canvas.restore();

    // Faixa e botão.
    canvas.drawLine(Offset(0, r), Offset(size.width, r), outline);
    canvas.drawCircle(
        center, r * 0.3, Paint()..color = const Color(0xFF222222));
    canvas.drawCircle(center, r * 0.18,
        Paint()..color = open > 0 ? Colors.yellow.shade200 : Colors.white);
  }

  @override
  bool shouldRepaint(_PokeballPainter oldDelegate) => oldDelegate.open != open;
}
