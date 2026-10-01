// lib/services/animated_sprites.dart
//
// Sprites animados (GIF, estilo Black & White) de todos os Pokémon. Vêm
// dentro do APK (assets/database/sprites/animated, gerados por
// tool/fetch_animated_sprites.py e tool/bw_style_sprites.py): aparecem na
// hora, sem baixar nada. Quais existem e o ajuste de tamanho de cada um vêm
// em assets/database/animated_sprites.json.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AnimatedSprites {
  AnimatedSprites._();
  static final AnimatedSprites instance = AnimatedSprites._();

  final Map<String, Set<int>> _have = {'front': {}, 'shiny': {}};
  final Map<String, Map<int, List<double>>> _fit = {'front': {}, 'shiny': {}};

  /// Carrega a lista do banco (ao abrir o app).
  Future<void> load() async {
    try {
      final raw = json.decode(await rootBundle.loadString('assets/database/animated_sprites.json')) as Map;
      for (final kind in ['front', 'shiny']) {
        _have[kind] = {for (final id in (raw[kind] as List? ?? const [])) (id as num).toInt()};
        final fit = (raw['fit'] as Map?)?[kind] as Map? ?? const {};
        _fit[kind] = {
          for (final e in fit.entries) int.parse('${e.key}'): [for (final v in e.value as List) (v as num).toDouble()],
        };
      }
    } catch (e) {
      debugPrint('Sprites animados desligados: $e');
    }
    _cleanOldDownloads();
  }

  /// Até a 2.0.2 o app baixava os GIFs do site e guardava no celular: agora
  /// vêm no APK, então a pasta antiga só ocupa espaço.
  Future<void> _cleanOldDownloads() async {
    if (kIsWeb) return;
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/animated');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Tem sprite animado desse Pokémon?
  bool has(int id, {bool shiny = false}) => _have[shiny ? 'shiny' : 'front']!.contains(id);

  /// O GIF dentro do APK.
  String asset(int id, {bool shiny = false}) => 'assets/database/sprites/animated/${shiny ? 'shiny' : 'front'}/$id.gif';

  /// [zoom, dx, dy, largura, altura]: quem se mexe muito (asas abertas...)
  /// fica pequeno no GIF recortado; amplia para o quadro típico ocupar a
  /// caixa, com o centro dele deslocado (dx, dy em fração do lado maior).
  /// Ver tool/fetch_animated_sprites.py.
  List<double> fit(int id, {bool shiny = false}) => _fit[shiny ? 'shiny' : 'front']![id] ?? const [1, 0, 0, 1, 1];
}
