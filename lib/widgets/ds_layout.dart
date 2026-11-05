// lib/widgets/ds_layout.dart
//
// As duas telas do DS: em pé, o campo em cima e a tela de baixo (texto e
// menus) embaixo; com o celular deitado, lado a lado (o campo à esquerda, do
// mesmo tamanho de quando está em pé, e a tela de baixo à direita, também do mesmo tamanho).
// Na batalha (normal e dupla) e na Battle Factory.

import 'dart:math';

import 'package:flutter/material.dart';

class DsLayout extends StatelessWidget {
  const DsLayout({super.key, required this.top, required this.bottom, this.side});

  /// O campo (4:3 pela largura) com o que vai junto embaixo dele (a faixa).
  final Widget top;

  /// A tela de baixo (texto, menus e botões).
  final Widget bottom;

  /// Deitado: algo embaixo da tela de baixo, à direita (ex.: o registro da batalha).
  final Widget? side;

  /// Celular deitado (no tablet a tela em pé já cabe).
  static bool lying(BuildContext context) => MediaQuery.orientationOf(context) == Orientation.landscape && MediaQuery.sizeOf(context).height < 500;

  @override
  Widget build(BuildContext context) {
    if (!lying(context)) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [top, bottom]);
    return LayoutBuilder(builder: (context, box) {
      // O campo sempre com o tamanho de sempre (a largura do celular em pé); a tela de baixo ao lado, também do mesmo
      // tamanho quando cabe (num celular mais curto, só ela fica um pouco mais estreita). O que não couber na altura rola.
      final full = MediaQuery.sizeOf(context).shortestSide - 24;
      final w = min(full, box.maxWidth - 8 - 260);
      final right = min(full, box.maxWidth - 8 - w);
      return Center(
        key: const ValueKey('ds-lying'),
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: w, child: top),
          const SizedBox(width: 8),
          SizedBox(
            width: right,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bottom, if (side != null) ...[const SizedBox(height: 8), side!]]),
          ),
        ]),
      );
    });
  }
}
