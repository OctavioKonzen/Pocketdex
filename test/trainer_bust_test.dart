// Os treinadores escolhíveis (com as animações completas) no cartão do perfil,
// da cintura para cima: com SHOTS=<pasta>, salva uma imagem com todos lado a lado.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/trainers.dart';
import 'package:pocket_dex/widgets/trainer_sprite.dart';

void main() {
  testWidgets('Treinadores no cartão do perfil', (tester) async {
    await tester.runAsync(Trainers.load);
    final list = [for (final t in Trainers.list) if (t.fullyAnimated) t];
    expect(list.length, greaterThanOrEqualTo(20));
    await tester.binding.setSurfaceSize(const Size(1000, 1300));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        child: ColoredBox(
          color: const Color(0xFF111318),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in list)
              Container(
                width: 190,
                height: 230,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: const Color(0xFF3A1F24), borderRadius: BorderRadius.circular(18)),
                child: Stack(children: [
                  Positioned.fill(child: TrainerBust(t)),
                  Positioned(left: 8, bottom: 6, child: Text(t.id, style: const TextStyle(color: Colors.white, fontSize: 12))),
                ]),
              ),
          ]),
        ),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final dir = Platform.environment['SHOTS'];
    if (dir == null) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byType(RepaintBoundary).first);
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/treinadores.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
