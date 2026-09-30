// lib/widgets/pokeball_background.dart
//
// Fundo de todas as telas: a cor do tema com uma Pokébola grande e bem
// clarinha girando devagar num canto (igual ao site). Todas as telas usam o
// mesmo relógio, então a Pokébola não "pula" ao trocar de tela. Dá para
// parar nas Configurações (e para quem pediu menos animações no aparelho).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../utils/site_ui.dart';

/// Uma volta a cada 60 segundos.
const _period = Duration(seconds: 60);

double _clockTurns() => (DateTime.now().millisecondsSinceEpoch % _period.inMilliseconds) / _period.inMilliseconds;

class PokeballBackground extends StatefulWidget {
  final Widget child;
  const PokeballBackground({super.key, required this.child});

  @override
  State<PokeballBackground> createState() => _PokeballBackgroundState();
}

class _PokeballBackgroundState extends State<PokeballBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: _period);

  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  bool get _moving => AppSettings.instance.backgroundAnimation && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  void _sync() {
    if (!mounted) return;
    if (_moving) {
      if (!_spin.isAnimating) {
        _spin.value = _clockTurns();
        _spin.repeat();
      }
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_sync);
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SiteColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: c.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LayoutBuilder(builder: (context, box) {
            final size = math.max(math.min(box.maxWidth, box.maxHeight) * 1.1, 320.0);
            return Stack(children: [
              Positioned(
                right: -size * 0.35,
                bottom: -size * 0.3,
                width: size,
                height: size,
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: RotationTransition(
                      turns: _spin,
                      child: Opacity(
                        opacity: dark ? 0.05 : 0.07,
                        child: Image.asset('assets/images/pokeball.png', color: c.text, cacheWidth: 720, filterQuality: FilterQuality.medium),
                      ),
                    ),
                  ),
                ),
              ),
            ]);
          }),
          widget.child,
        ],
      ),
    );
  }
}

/// Transição de tela que já traz o fundo: cada tela tem o próprio fundo (as
/// telas ficam transparentes) e a animação de troca continua a do Android.
class PokeballPageTransitions extends PageTransitionsBuilder {
  const PokeballPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) =>
      const ZoomPageTransitionsBuilder().buildTransitions(route, context, animation, secondaryAnimation, PokeballBackground(child: child));
}
