// lib/services/music_cache.dart
//
// As músicas em loop (batalha, líderes, campeões, lugares, mapas, Mega e Dynamax) não vêm dentro do
// app: ficam no site (web-site/public/sounds/music/, feitas por tool/build_battle_sounds.py) e o app
// baixa cada uma na primeira vez que toca e guarda no celular. Assim, mudar uma música só precisa
// publicar o site, não um app novo.
//
// O site tem a lista sounds/music/music.json ({música: hash do arquivo}): o app confere uma vez por
// sessão e baixa de novo só a música que mudou. Sem internet, toca a que já guardou (a primeira vez
// sem internet fica sem música).

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class MusicCache {
  MusicCache._();

  static const site = 'https://octaviokonzen.github.io/Pocketdex/sounds/music';

  /// A pasta das músicas guardadas (dá para trocar nos testes).
  static Future<Directory> Function() root = () async => Directory('${(await getApplicationSupportDirectory()).path}/music');

  /// Baixa um arquivo do site (dá para trocar nos testes).
  static Future<List<int>?> Function(String url) fetch = _get;

  static Future<Map<String, String>?>? _manifest;
  static final Map<String, Future<String?>> _pending = {};

  /// O arquivo da música no celular (baixa ou atualiza se precisar), ou null (sem internet e sem cópia).
  static Future<String?> pathFor(String track) => _pending[track] ??= _pathFor(track).whenComplete(() {
        _pending.remove(track); // sem devolver o Future (o whenComplete esperaria por ele mesmo)
      });

  static Future<String?> _pathFor(String track) async {
    try {
      final dir = await root();
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/$track.ogg');
      final saved = _readHashes(dir);
      final latest = await (_manifest ??= _loadManifest());
      final want = latest?[track];
      if (file.existsSync() && (want == null || saved[track] == want)) return file.path;
      final bytes = await fetch('$site/$track.ogg');
      if (bytes == null || bytes.isEmpty) return file.existsSync() ? file.path : null;
      final temp = File('${file.path}.part');
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
      if (want != null) {
        saved[track] = want;
        File('${dir.path}/hashes.json').writeAsStringSync(json.encode(saved));
      }
      return file.path;
    } catch (e) {
      debugPrint('Música $track: $e');
      return null;
    }
  }

  static Future<Map<String, String>?> _loadManifest() async {
    final bytes = await fetch('$site/music.json');
    if (bytes == null) {
      _manifest = null; // sem internet: tenta de novo na próxima música
      return null;
    }
    try {
      return (json.decode(utf8.decode(bytes)) as Map).map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return null;
    }
  }

  static Map<String, String> _readHashes(Directory dir) {
    try {
      final f = File('${dir.path}/hashes.json');
      if (!f.existsSync()) return {};
      return (json.decode(f.readAsStringSync()) as Map).map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return {};
    }
  }

  static Future<List<int>?> _get(String url) async {
    if (kIsWeb) return null;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close().timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) return null;
      final out = <int>[];
      await for (final chunk in response) {
        out.addAll(chunk);
      }
      return out;
    } catch (_) {
      return null;
    } finally {
      client.close();
    }
  }

  /// Só nos testes: esquece a lista da sessão.
  @visibleForTesting
  static void reset() {
    _manifest = null;
    _pending.clear();
  }
}
