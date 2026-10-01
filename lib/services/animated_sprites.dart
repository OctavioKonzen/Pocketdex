// lib/services/animated_sprites.dart
//
// Sprites animados (GIF) de todos os Pokémon, no banco do site (o app puxa da
// nuvem, com internet; sem ela aparece o sprite parado), em dois estilos:
//   • Black & White (sprites/animated): os oficiais do BW, a animação BW do
//     Showdown ou, sem animação, a arte BW parada
//     (tool/fetch_animated_sprites.py e tool/bw_style_sprites.py);
//   • 3D do Pokémon Showdown, na qualidade original (sprites/3d,
//     tool/showdown_3d_sprites.py).
// Na Pokédex vai só o BW (sem animação BW, a arte parada). Na batalha, o BW
// animado ou, sem ele, o 3D (como no Showdown). Com a opção "3D" nas
// Configurações, tudo em 3D.
//
// Quais existem, os parados, o ajuste de tamanho, o pé e a impressão digital
// de cada um vêm em animated_sprites.json: o do APK ao abrir e, logo depois,
// o do site (assim sprites novos aparecem sem precisar de APK novo).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'app_settings.dart';

/// Um sprite escolhido: o endereço, o ajuste [zoom, dx, dy, largura, altura],
/// o pé (quanto descer na batalha, em fração do lado) e se é 3D.
typedef SpriteSource = ({String url, List<double> fit, double foot, bool is3d});

class _Set {
  final String folder;
  final Map<String, Set<int>> have = {for (final k in AnimatedSprites.kinds) k: {}};
  final Map<String, Set<int>> still = {for (final k in AnimatedSprites.kinds) k: {}};
  final Map<String, Map<int, List<double>>> fit = {for (final k in AnimatedSprites.kinds) k: {}};
  final Map<String, Map<int, double>> foot = {for (final k in AnimatedSprites.kinds) k: {}};

  /// Impressão digital de cada GIF: vai na URL, então quando o banco troca um
  /// sprite o celular não usa o velho que ficou no cache da internet.
  final Map<String, Map<int, String>> hash = {for (final k in AnimatedSprites.kinds) k: {}};
  _Set(this.folder);

  void apply(Map raw) {
    Map<int, T> byId<T>(Object? m, T Function(Object) f) =>
        {for (final e in ((m as Map?) ?? const {}).entries) int.parse('${e.key}'): f(e.value as Object)};
    for (final kind in AnimatedSprites.kinds) {
      have[kind] = {for (final id in (raw[kind] as List? ?? const [])) (id as num).toInt()};
      still[kind] = {for (final id in ((raw['still'] as Map?)?[kind] as List? ?? const [])) (id as num).toInt()};
      fit[kind] = byId((raw['fit'] as Map?)?[kind], (v) => [for (final x in v as List) (x as num).toDouble()]);
      foot[kind] = byId((raw['foot'] as Map?)?[kind], (v) => (v as num).toDouble());
      hash[kind] = byId((raw['hash'] as Map?)?[kind], (v) => '$v');
    }
  }

  SpriteSource source(String kind, int id) {
    final v = hash[kind]![id];
    return (
      url: '${AnimatedSprites.site}/sprites/$folder/$kind/$id.gif${v == null ? '' : '?v=$v'}',
      fit: fit[kind]![id] ?? const [1, 0, 0, 1, 1],
      foot: foot[kind]![id] ?? 0,
      is3d: folder == '3d',
    );
  }
}

class AnimatedSprites {
  AnimatedSprites._();
  static final AnimatedSprites instance = AnimatedSprites._();

  static const site = 'https://octaviokonzen.github.io/Pocketdex';

  /// Frente, shiny e as costas (para a batalha).
  static const kinds = ['front', 'shiny', 'back', 'back-shiny'];
  static String _kind(bool shiny, bool back) => back ? (shiny ? 'back-shiny' : 'back') : (shiny ? 'shiny' : 'front');

  final _bw = _Set('animated'), _threeD = _Set('3d');

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
    _bw.apply(raw);
    if (raw['3d'] is Map) _threeD.apply(raw['3d'] as Map);
  }

  Future<void> _refresh() async {
    if (kIsWeb) return;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await (await client.getUrl(Uri.parse('$site/data/animated_sprites.json'))).close();
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

  /// O sprite desse Pokémon ([battle]: na batalha), ou null (fica o parado).
  /// Pokédex: só o BW. Batalha: o BW animado ou, sem ele, o 3D. Opção "3D":
  /// o 3D (sem ele, o BW).
  SpriteSource? source(int id, {bool shiny = false, bool back = false, bool battle = false}) {
    final kind = _kind(shiny, back);
    final bw = _bw.have[kind]!.contains(id), has3d = _threeD.have[kind]!.contains(id);
    final bwMoves = bw && !_bw.still[kind]!.contains(id);
    if (AppSettings.instance.spriteStyle == '3d') {
      return has3d ? _threeD.source(kind, id) : (bw ? _bw.source(kind, id) : null);
    }
    if (battle && !bwMoves && has3d) return _threeD.source(kind, id);
    return bw ? _bw.source(kind, id) : null;
  }
}
