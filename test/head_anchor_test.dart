// A coroa do Terastal fica no mesmo lugar no app e no site: os mesmos GIFs
// da batalha, cabeça quadro a quadro igual a web-site/src/lib/headAnchor.test.js
// (test/fixtures/head_anchor.json).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/widgets/pokemon_sprite.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('segue a cabeça quando ela anda', () {
    const w = 20, h = 12;
    Uint8List frame(int dx, int dy) {
      final data = Uint8List(w * h * 4);
      for (var y = 3; y < 10; y++) {
        for (var x = 6; x < 12; x++) {
          data.setAll(((y + dy) * w + x + dx) * 4, [200, (x * 30) % 255, y * 20, 255]);
        }
      }
      return data;
    }

    final tracker = HeadTracker(frame(0, 0), w, h);
    expect(tracker.track(frame(0, 0)), const Offset(9 / w, 3 / h));
    expect(tracker.track(frame(3, 1)), const Offset(12 / w, 4 / h));
    expect(tracker.track(frame(1, -1)), const Offset(10 / w, 2 / h));
  });

  test('igual ao site nos GIFs da batalha', () async {
    final expected = jsonDecode(File('test/fixtures/head_anchor.json').readAsStringSync()) as Map<String, dynamic>;
    for (final MapEntry(key: name, value: heads) in expected.entries) {
      final bytes = File('assets/database/sprites/animated/$name.gif').readAsBytesSync();
      final codec = await ui.instantiateImageCodec(bytes);
      HeadTracker? tracker;
      final got = <Object?>[];
      for (var i = 0; i < codec.frameCount; i++) {
        final image = (await codec.getNextFrame()).image;
        final rgba = (await image.toByteData())!.buffer.asUint8List();
        final head = (tracker ??= HeadTracker(rgba, image.width, image.height)).track(rgba);
        got.add(head == null ? null : [double.parse(head.dx.toStringAsFixed(4)), double.parse(head.dy.toStringAsFixed(4))]);
        image.dispose();
      }
      expect(got, heads, reason: name);
    }
  });
}
