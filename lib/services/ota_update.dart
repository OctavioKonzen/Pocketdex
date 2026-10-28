// lib/services/ota_update.dart
//
// Atualização pela rede (sem APK novo) do motor da batalha e dos dados que ele
// usa. A cada deploy, o site publica em ota/ (tool/build_ota.py) os arquivos e
// um manifest.json com a versão, a "api" e o SHA-256 de cada arquivo. O app:
//   1. ao abrir, usa a última versão baixada (se tiver) ou a que veio no APK;
//   2. em segundo plano, baixa a versão nova, confere o SHA-256 de cada arquivo
//      e guarda numa pasta só dela; ela vale a partir da próxima vez que o app abrir;
//   3. se um arquivo baixado falhar ao carregar, volta para o do APK.
// A "api" muda quando o app precisa de código novo para os arquivos novos: app
// com outra api ignora a atualização (continua com o que tem).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class OtaUpdate {
  /// A versão do "contrato" entre o app e os arquivos (igual a OTA_API em tool/build_ota.py).
  static const api = 1;

  /// Onde o site publica (o mesmo endereço do site).
  static const base = 'https://octaviokonzen.github.io/Pocketdex/ota/';

  /// Os arquivos que podem vir pela rede (os outros sempre vêm do APK).
  static const files = ['battle_engine.js', 'factory.json', 'battle_items.json', 'move_rules.json'];

  /// A pasta da versão em uso (null: a do APK).
  static Directory? _active;
  static String? version;

  /// Para os testes: de onde baixar e onde guardar.
  @visibleForTesting
  static Future<List<int>> Function(String url) fetch = _get;
  @visibleForTesting
  static Future<Directory> Function() root = () async => Directory('${(await getApplicationSupportDirectory()).path}/ota');

  static Future<List<int>> _get(String url) async {
    final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    return res.bodyBytes;
  }

  /// Ao abrir o app: escolhe a versão baixada (se for desta api e estiver inteira).
  static Future<void> init() async {
    try {
      final dir = await root();
      final current = File('${dir.path}/current.json');
      if (!current.existsSync()) return;
      final info = jsonDecode(current.readAsStringSync()) as Map;
      final folder = Directory('${dir.path}/${info['version']}');
      if (info['api'] != api || !folder.existsSync()) return;
      _active = folder;
      version = '${info['version']}';
    } catch (_) {
      _active = null;
    }
  }

  /// O texto do arquivo: o baixado (se a versão em uso tiver) ou o do APK.
  static Future<String> loadText(String name) async {
    final file = _active == null || !files.contains(name) ? null : File('${_active!.path}/$name');
    if (file != null && file.existsSync()) return file.readAsString();
    return rootBundle.loadString('assets/database/$name');
  }

  /// Lê e interpreta o arquivo; se o baixado não funcionar, volta para o do APK (e esquece a versão baixada).
  static Future<T> load<T>(String name, T Function(String text) parse) async {
    if (_active != null && files.contains(name)) {
      try {
        return parse(await loadText(name));
      } catch (_) {
        await discard();
      }
    }
    return parse(await rootBundle.loadString('assets/database/$name'));
  }

  /// Volta para os arquivos do APK (a versão baixada deu problema).
  static Future<void> discard() async {
    _active = null;
    version = null;
    try {
      final current = File('${(await root()).path}/current.json');
      if (current.existsSync()) current.deleteSync();
    } catch (_) {}
  }

  /// Em segundo plano: baixa a versão nova (se tiver), confere cada arquivo e deixa pronta para a próxima abertura.
  /// Devolve a versão baixada, ou null se não havia nada novo (ou deu erro).
  static Future<String?> check() async {
    try {
      final manifest = jsonDecode(utf8.decode(await fetch('${base}manifest.json'))) as Map;
      final next = '${manifest['version']}';
      final hashes = Map<String, dynamic>.from(manifest['files'] as Map);
      if (manifest['api'] != api || !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(next)) return null;
      final dir = await root();
      final current = File('${dir.path}/current.json');
      if (current.existsSync() && (jsonDecode(current.readAsStringSync()) as Map)['version'] == next) return null;
      final temp = Directory('${dir.path}/.download');
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      temp.createSync(recursive: true);
      for (final name in files) {
        final hash = hashes[name];
        if (hash == null) continue;
        final bytes = await fetch('$base$name');
        // Arquivo cortado ou trocado no caminho: não usa nada desta versão.
        if (sha256.convert(bytes).toString() != hash) {
          temp.deleteSync(recursive: true);
          return null;
        }
        File('${temp.path}/$name').writeAsBytesSync(bytes);
      }
      final folder = Directory('${dir.path}/$next');
      if (folder.existsSync()) folder.deleteSync(recursive: true);
      temp.renameSync(folder.path);
      current.writeAsStringSync(jsonEncode({'version': next, 'api': api}));
      // Apaga as versões antigas (menos a em uso agora).
      for (final old in dir.listSync().whereType<Directory>()) {
        if (old.path != folder.path && old.path != _active?.path) old.deleteSync(recursive: true);
      }
      return next;
    } catch (_) {
      return null;
    }
  }
}
