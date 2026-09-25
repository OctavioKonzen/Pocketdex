// lib/utils/responsive.dart
//
// Ajustes de layout para o site (Flutter Web) e telas grandes: o visual é o
// mesmo do app, mas o conteúdo fica centralizado com largura máxima e as
// grades ganham mais colunas conforme o espaço disponível.

import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class Responsive {
  /// Largura máxima do conteúdo das páginas no site.
  static const double maxContentWidth = 1200;

  /// A partir desta largura o layout passa a ser o de "site" (desktop).
  static const double wideBreakpoint = 900;

  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static double contentWidth(BuildContext context) =>
      math.min(MediaQuery.sizeOf(context).width, maxContentWidth);

  /// Número de colunas de uma grade: nunca menos que [min] (o valor usado no
  /// celular) e cresce para que cada item tenha ~[tileWidth] px de largura.
  static int columns(BuildContext context, {required int min, double tileWidth = 180}) =>
      math.max(min, (contentWidth(context) / tileWidth).floor());
}

/// Centraliza toda a navegação do app em uma coluna de largura máxima, mantendo
/// o fundo do tema ocupando a janela inteira.
class WebFrame extends StatelessWidget {
  final Widget child;

  const WebFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Responsive.maxContentWidth),
          child: child,
        ),
      ),
    );
  }
}

/// Limita a largura de listas e formulários, que ficam ruins de ler esticados.
class ReadableWidth extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const ReadableWidth({super.key, required this.child, this.maxWidth = 760});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Permite arrastar listas e carrosséis com o mouse, como no toque do celular.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
