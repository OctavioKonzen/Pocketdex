// lib/widgets/game_stage.dart
//
// Fundo clássico do "Quem é esse Pokémon?": raios azuis girando devagar
// (igual ao site). Fica num RepaintBoundary para o giro não redesenhar o
// resto da tela.

import 'dart:math';
import 'package:flutter/material.dart';

class GameStage extends StatefulWidget {
  final Widget child;
  const GameStage({super.key, required this.child});

  @override
  State<GameStage> createState() => _GameStageState();
}

class _GameStageState extends State<GameStage> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(seconds: 40))..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Color(0xFF1D5FC2)),
          RepaintBoundary(child: CustomPaint(painter: _RaysPainter(_spin))),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)], stops: [0, 0.6]),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final Animation<double> spin;
  _RaysPainter(this.spin) : super(repaint: spin);

  static final _paint = Paint()..color = const Color(0xFF3B8FF0);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.longestSide;
    const rays = 18;
    const step = 2 * pi / rays;
    final start = spin.value * 2 * pi;
    for (var i = 0; i < rays; i++) {
      final a = start + i * step;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(center.dx + radius * cos(a), center.dy + radius * sin(a))
        ..lineTo(center.dx + radius * cos(a + step / 2), center.dy + radius * sin(a + step / 2))
        ..close();
      canvas.drawPath(path, _paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}

/// Título amarelo com sombra azul, como no desenho.
class StageTitle extends StatelessWidget {
  final String text;
  final double size;
  const StageTitle(this.text, {super.key, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: const Color(0xFFFDE047),
        shadows: const [Shadow(color: Color(0xFF1B3F8A), offset: Offset(0, 3))],
      ),
    );
  }
}
