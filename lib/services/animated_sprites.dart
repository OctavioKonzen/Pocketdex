// lib/services/animated_sprites.dart
//
// Sprites animados (GIF, estilo Black & White) de todos os Pokémon. Ficam no
// banco do site (assets/database/sprites/animated, gerados por
// tool/fetch_animated_sprites.py e tool/bw_style_sprites.py) e o app sempre
// puxa da nuvem, com internet: não guarda no celular e o APK fica leve. Sem
// internet aparece o sprite parado de sempre.
//
// Quais existem, o ajuste de tamanho e a impressão digital de cada um vêm em
// animated_sprites.json: o do APK ao abrir e, logo depois, o do site (assim
// sprites novos aparecem sem precisar de APK novo).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AnimatedSprites {
  AnimatedSprites._();
  static final AnimatedSprites instance = AnimatedSprites._();

  static const _site = 'https://octaviokonzen.github.io/Pocketdex';

  final Map<String, Set<int>> _have = {'front': {}, 'shiny': {}};
  final Map<String, Map<int, List<double>>> _fit = {'front': {}, 'shiny': {}};

  /// Impressão digital de cada GIF: vai na URL, então quando o banco troca um
  /// sprite o celular não usa o velho que ficou no cache da internet.
  final Map<String, Map<int, String>> _hash = {'front': {}, 'shiny': {}};

  /// Carrega a lista do APK e, em segundo plano, a atualizada do site.
  Future<void> load() async {
    try {
      _apply(json.decode(await rootBundle.loadString('assets/database/animated_sprites.json')) as Map);
    } catch (e) {
      debugPrint('Sprites animados desligados: $e');
    }
    unawaited(_cleanOldDownloads());
    unawaited(_refresh());
  }

  void _apply(Map raw) {
    for (final kind in ['front', 'shiny']) {
      _have[kind] = {for (final id in (raw[kind] as List? ?? const [])) (id as num).toInt()};
      final fit = (raw['fit'] as Map?)?[kind] as Map? ?? const {};
      _fit[kind] = {
        for (final e in fit.entries) int.parse('${e.key}'): [for (final v in e.value as List) (v as num).toDouble()],
      };
      final hash = (raw['hash'] as Map?)?[kind] as Map? ?? const {};
      _hash[kind] = {for (final e in hash.entries) int.parse('${e.key}'): '${e.value}'};
    }
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await (await client.getUrl(Uri.parse('$_site/data/animated_sprites.json'))).close();
      if (response.statusCode != 200) return;
      final raw = json.decode(await response.transform(utf8.decoder).join());
      if (raw is Map && raw['front'] is List) _apply(raw);
    } catch (_) {
      // Sem internet: segue com a lista do APK.
    } finally {
      client.close();
    }
  }

  /// Até a 2.0.2 o app baixava os GIFs e guardava no celular: agora puxa
  /// sempre da nuvem, então a pasta antiga só ocupa espaço.
  Future<void> _cleanOldDownloads() async {
    if (kIsWeb) return;
    try {
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/animated');
      if (dir.existsSync()) await dir.delete(recursive: true);
    } catch (_) {}
  }

  /// Tem sprite animado desse Pokémon?
  bool has(int id, {bool shiny = false}) => _have[shiny ? 'shiny' : 'front']!.contains(id);

  /// Endereço do GIF no banco do site.
  String url(int id, {bool shiny = false}) {
    final kind = shiny ? 'shiny' : 'front';
    final hash = _hash[kind]![id];
    return '$_site/sprites/animated/$kind/$id.gif${hash == null ? '' : '?v=$hash'}';
  }

  /// [zoom, dx, dy, largura, altura]: quem se mexe muito (asas abertas...)
  /// fica pequeno no GIF recortado; amplia para o quadro típico ocupar a
  /// caixa, com o centro dele deslocado (dx, dy em fração do lado maior).
  /// Ver tool/fetch_animated_sprites.py.
  List<double> fit(int id, {bool shiny = false}) => _fit[shiny ? 'shiny' : 'front']![id] ?? const [1, 0, 0, 1, 1];
}
