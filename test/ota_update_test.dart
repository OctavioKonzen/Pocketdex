import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/ota_update.dart';

/// O site de mentira: manifest.json e os arquivos (o que [files] tiver).
void serve(Map<String, String> files, {int api = OtaUpdate.api, String version = 'v2', Map<String, String>? hashes}) {
  final manifest = {
    'api': api,
    'version': version,
    'files': hashes ?? {for (final e in files.entries) e.key: sha256.convert(utf8.encode(e.value)).toString()},
  };
  OtaUpdate.fetch = (url) async {
    final name = url.substring(OtaUpdate.base.length);
    if (name == 'manifest.json') return utf8.encode(jsonEncode(manifest));
    final text = files[name];
    if (text == null) throw const HttpException('404');
    return utf8.encode(text);
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('ota');
    OtaUpdate.root = () async => dir;
    await OtaUpdate.discard();
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('sem versão baixada, usa os arquivos do APK', () async {
    await OtaUpdate.init();
    expect(OtaUpdate.version, isNull);
    final bundled = await OtaUpdate.loadText('factory.json');
    expect(jsonDecode(bundled), contains('species'));
  });

  test('baixa a versão nova, confere o SHA-256 e usa na próxima abertura', () async {
    serve({'battle_engine.js': 'var PocketDexSim = {};', 'factory.json': '{"novo": true}'});
    expect(await OtaUpdate.check(), 'v2');
    // Ainda não: a versão baixada vale na próxima abertura do app.
    expect(OtaUpdate.version, isNull);
    await OtaUpdate.init();
    expect(OtaUpdate.version, 'v2');
    expect(await OtaUpdate.loadText('factory.json'), '{"novo": true}');
    expect(await OtaUpdate.loadText('battle_engine.js'), 'var PocketDexSim = {};');
    // O que não veio na versão nova continua o do APK.
    expect(jsonDecode(await OtaUpdate.loadText('battle_items.json')), contains('mega'));
    // A mesma versão de novo: nada para baixar.
    expect(await OtaUpdate.check(), isNull);
  });

  test('arquivo trocado no caminho (SHA-256 diferente): não usa nada', () async {
    serve({'factory.json': '{"novo": true}'}, hashes: {'factory.json': 'abc'});
    expect(await OtaUpdate.check(), isNull);
    await OtaUpdate.init();
    expect(OtaUpdate.version, isNull);
  });

  test('versão de outra api (precisa de app novo): ignora', () async {
    serve({'factory.json': '{"novo": true}'}, api: OtaUpdate.api + 1);
    expect(await OtaUpdate.check(), isNull);
    await OtaUpdate.init();
    expect(OtaUpdate.version, isNull);
  });

  test('arquivo baixado que não funciona: volta para o do APK', () async {
    serve({'factory.json': 'isto não é json'});
    expect(await OtaUpdate.check(), 'v2');
    await OtaUpdate.init();
    final data = await OtaUpdate.load('factory.json', (t) => jsonDecode(t) as Map);
    expect(data, contains('species'));
    expect(OtaUpdate.version, isNull);
    await OtaUpdate.init();
    expect(OtaUpdate.version, isNull);
  });

  test('o site publica os mesmos arquivos e a mesma api (tool/build_ota.py)', () {
    final tool = File('tool/build_ota.py').readAsStringSync();
    expect(RegExp(r'OTA_API = (\d+)').firstMatch(tool)!.group(1), '${OtaUpdate.api}');
    final files = RegExp(r"FILES = \[([^\]]*)\]").firstMatch(tool)!.group(1)!;
    expect([for (final m in RegExp(r"'([^']+)'").allMatches(files)) m.group(1)], OtaUpdate.files);
  });
}
