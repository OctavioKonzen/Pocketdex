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
  final Map<String, Map<int, List<double>>> _fit = {'front': {}, 'shiny': {}};

  /// Impressão digital de cada GIF: entra no nome do arquivo guardado, então
  /// quando o banco troca um sprite o app baixa o novo (e apaga o velho).
  final Map<String, Map<int, String>> _hash = {'front': {}, 'shiny': {}};
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
        final fit = (raw['fit'] as Map?)?[kind] as Map? ?? const {};
        final hash = (raw['hash'] as Map?)?[kind] as Map? ?? const {};
        _hash[kind] = {for (final e in hash.entries) int.parse('${e.key}'): '${e.value}'};
        _fit[kind] = {
          for (final e in fit.entries) int.parse('${e.key}'): [for (final v in e.value as List) (v as num).toDouble()],
        };
      }
      _dir = Directory('${(await getApplicationSupportDirectory()).path}/animated');
      for (final kind in ['front', 'shiny']) {
        final folder = Directory('${_dir!.path}/$kind');
        if (!folder.existsSync()) continue;
        for (final f in folder.listSync().whereType<File>()) {
          final name = f.uri.pathSegments.last;
          final id = int.tryParse(name.split(RegExp(r'[-.]')).first);
          if (id != null && name == _name(kind, id) && f.lengthSync() > 0) {
            _saved['$kind/$id'] = f;
          } else {
            f.deleteSync(); // versão velha (ou download pela metade)
          }
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

  /// [zoom, dx, dy, largura, altura]: quem se mexe muito (asas abertas...)
  /// fica pequeno no GIF recortado; amplia para o quadro típico ocupar a
  /// caixa, com o centro dele deslocado (dx, dy em fração do lado maior).
  /// Ver tool/fetch_animated_sprites.py.
  List<double> fit(int id, {bool shiny = false}) => _fit[shiny ? 'shiny' : 'front']![id] ?? const [1, 0, 0, 1, 1];

  /// O arquivo, se já estiver no celular.
  File? saved(int id, {bool shiny = false}) => _saved['${shiny ? 'shiny' : 'front'}/$id'];

  String _name(String kind, int id) {
    final hash = _hash[kind]![id];
    return hash == null ? '$id.gif' : '$id-$hash.gif';
  }

  /// O arquivo, baixando do site se ainda não estiver no celular (null = não deu).
  Future<File?> file(int id, {bool shiny = false}) {
    final kind = shiny ? 'shiny' : 'front';
    final key = '$kind/$id';
    final done = _saved[key];
    if (done != null) return Future.value(done);
    if (!has(id, shiny: shiny)) return Future.value(null);
    return _pending.putIfAbsent(key, () => _download(kind, id).whenComplete(() => _pending.remove(key)));
  }

  Future<File?> _download(String kind, int id) async {
    // No máximo [_parallel] downloads ao mesmo tempo (rolar a Pokédex pede muitos).
    if (_running >= _parallel) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    }
    _running++;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final hash = _hash[kind]![id];
      final url = '$_site/$kind/$id.gif${hash == null ? '' : '?v=$hash'}';
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != 200) return null;
      final bytes = await response.fold<List<int>>(<int>[], (all, chunk) => all..addAll(chunk));
      final file = File('${_dir!.path}/$kind/${_name(kind, id)}');
      await file.parent.create(recursive: true);
      // Grava num temporário e renomeia: um download pela metade nunca fica no lugar.
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      _saved['$kind/$id'] = file;
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
