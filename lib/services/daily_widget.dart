// lib/services/daily_widget.dart
//
// Widget da tela inicial do Android com o Pokémon do dia
// (android/app/src/main/kotlin/.../DailyPokemonWidget.kt). Ao abrir o app,
// guardamos o nome e o sprite dos próximos 7 dias; o widget mostra o de hoje
// sozinho, mesmo sem abrir o app de novo. Com o sprite animado, guardamos
// também os quadros dele (o widget troca de quadro com um ViewFlipper:
// widget do Android não toca GIF).

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:home_widget/home_widget.dart';

import '../i18n/i18n.dart';
import '../utils/app_images.dart';
import '../utils/string_extensions.dart';
import 'animated_sprites.dart';
import 'daily_pokemon.dart';
import 'league.dart';
import 'local_database.dart';

class DailyWidget {
  DailyWidget._();

  static const _android = 'com.octaviokonzen.pocketdex.DailyPokemonWidget';

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> update() async {
    if (!supported) return;
    try {
      await HomeWidget.saveWidgetData<String>('label', tr('Pokémon do dia'));
      final now = DateTime.now().toUtc();
      for (var i = 0; i < 7; i++) {
        final day = League.dayKey(now.add(Duration(days: i)));
        final id = DailyPokemon.idFor(day);
        final row = await LocalDatabase.instance.pokemonRow(id);
        final name = I18n.pokemonName(((row?['name'] as String?) ?? '#$id').split('-').first.capitalise());
        await HomeWidget.saveWidgetData<String>('d_${day}_name', '$name  #${id.toString().padLeft(3, '0')}');
        final sprite = await rootBundle.load(AppImages.pokemonSprite(id));
        await HomeWidget.saveFile('d_${day}_img', sprite.buffer.asUint8List(), extension: 'png');
        await _saveFrames(day, id);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _android);
    } catch (e) {
      debugPrint('Widget do Pokémon do dia: $e');
    }
  }

  /// No máximo tantos quadros (os GIFs longos pulam quadros, mesma duração;
  /// o Android limita a memória das imagens de um widget).
  static const _maxFrames = 16;

  /// Ampliação dos quadros (o widget amplia borrado; aqui fica em pixel).
  static const _scale = 2;

  /// Quadros do GIF animado em PNG: d_<dia>_f<i>, quantos (d_<dia>_frames)
  /// e quanto tempo cada um fica (d_<dia>_ms). Sem animado: 0 quadros.
  static Future<void> _saveFrames(String day, int id) async {
    var count = 0;
    var ms = 100;
    try {
      if (AnimatedSprites.instance.has(id)) {
        // O GIF vem da nuvem (sem internet, o widget fica com o parado).
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
        final Uint8List gif;
        try {
          final response = await (await client.getUrl(Uri.parse(AnimatedSprites.instance.url(id)))).close();
          if (response.statusCode != 200) throw const HttpException('sem o GIF');
          gif = await consolidateHttpClientResponseBytes(response);
        } finally {
          client.close();
        }
        final codec = await ui.instantiateImageCodec(gif);
        final total = codec.frameCount;
        final step = (total / _maxFrames).ceil().clamp(1, total);
        var duration = 0;
        for (var i = 0; i < total; i++) {
          final frame = await codec.getNextFrame();
          duration += frame.duration.inMilliseconds;
          if (i % step != 0) continue;
          final png = await _pixelPng(frame.image);
          if (png != null) await HomeWidget.saveFile('d_${day}_f$count', png, extension: 'png');
          count++;
        }
        if (count > 0) ms = (duration / count).round().clamp(40, 500);
      }
    } catch (e) {
      count = 0;
      debugPrint('Quadros do widget: $e');
    }
    await HomeWidget.saveWidgetData<String>('d_${day}_frames', '$count');
    await HomeWidget.saveWidgetData<String>('d_${day}_ms', '$ms');
  }

  static Future<Uint8List?> _pixelPng(ui.Image image) async {
    final recorder = ui.PictureRecorder();
    final w = image.width * _scale, h = image.height * _scale;
    ui.Canvas(recorder).drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
    final big = await recorder.endRecording().toImage(w, h);
    final data = await big.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}
