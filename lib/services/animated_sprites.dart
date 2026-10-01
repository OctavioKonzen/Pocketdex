// lib/services/animated_sprites.dart
//
// Sprites animados (GIF, estilo Black & White) de todos os Pokémon. Ficam no
// banco do site (assets/database/sprites/animated, tool/fetch_animated_sprites.py),
// mas NÃO dentro do APK (seriam ~225 MB): o app baixa cada um do site da
// primeira vez que aparece e guarda no celular; daí em diante funciona sem
// internet. Quais existem vem em assets/database/animated_sprites.json.

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class AnimatedSprites {
  AnimatedSprites._();
  static final AnimatedSprites instance = AnimatedSprites._();

  static const _site = 'https://octaviokonzen.github.io/Pocketdex/sprites/animated';
  static const _parallel = 4;

  final Map<String, Set<int>> _have = {'front': {}, 'shiny': {}};
  Directory? _dir;
  bool _ready = false;

  /// Arquivos já baixados (para mostrar na hora, sem piscar o parado).
  final Map<String, File> _saved = {};
  final Map<String, Future<File?>> _pending = {};
  final Queue<Completer<void>> _waiting = Queue();
  int _running = 0;

  /// Carrega a lista do banco e vê o que já está no celular (ao abrir o app).
  Future<void> load() async {
    try {
      final raw = json.decode(await rootBundle.loadString('assets/database/animated_sprites.json')) as Map;
      for (final kind in ['front', 'shiny']) {
        _have[kind] = {for (final id in (raw[kind] as List? ?? const [])) (id as num).toInt()};
      }
      _dir = Directory('${(await getApplicationSupportDirectory()).path}/animated');
      for (final kind in ['front', 'shiny']) {
        final folder = Directory('${_dir!.path}/$kind');
        if (!folder.existsSync()) continue;
        for (final f in folder.listSync().whereType<File>()) {
          if (f.path.endsWith('.gif') && f.lengthSync() > 0) _saved['$kind/${f.uri.pathSegments.last}'] = f;
        }
      }
      _ready = true;
    } catch (e) {
      // Sem pasta do app (ex.: nos testes): fica o sprite parado.
      debugPrint('Sprites animados desligados: $e');
    }
  }

  /// Tem sprite animado desse Pokémon?
  bool has(int id, {bool shiny = false}) => _ready && _have[shiny ? 'shiny' : 'front']!.contains(id);

  /// O arquivo, se já estiver no celular.
  File? saved(int id, {bool shiny = false}) => _saved['${shiny ? 'shiny' : 'front'}/$id.gif'];

  /// O arquivo, baixando do site se ainda não estiver no celular (null = não deu).
  Future<File?> file(int id, {bool shiny = false}) {
    final kind = shiny ? 'shiny' : 'front';
    final key = '$kind/$id.gif';
    final done = _saved[key];
    if (done != null) return Future.value(done);
    if (!has(id, shiny: shiny)) return Future.value(null);
    return _pending.putIfAbsent(key, () => _download(key).whenComplete(() => _pending.remove(key)));
  }

  Future<File?> _download(String key) async {
    // No máximo [_parallel] downloads ao mesmo tempo (rolar a Pokédex pede muitos).
    if (_running >= _parallel) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await (await client.getUrl(Uri.parse('$_site/$key'))).close();
      if (response.statusCode != 200) return null;
      final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      final file = File('${_dir!.path}/$key');
      await file.parent.create(recursive: true);
      // Grava num temporário e renomeia: um download pela metade nunca fica no lugar.
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      _saved[key] = file;
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close();
      _running--;
      if (_waiting.isNotEmpty) _waiting.removeFirst().complete();
    }
  }
}
