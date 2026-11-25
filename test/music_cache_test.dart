import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_dex/services/music_cache.dart';

void main() {
  late Directory dir;
  late Map<String, String> manifest;
  late Map<String, List<int>> site;
  late List<String> asked;
  late bool online;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('music');
    manifest = {'map_kanto': 'aaa'};
    site = {'map_kanto': [1, 2, 3]};
    asked = [];
    online = true;
    MusicCache.reset();
    MusicCache.root = () async => dir;
    MusicCache.fetch = (url) async {
      asked.add(url.split('/').last);
      if (!online) return null;
      if (url.endsWith('music.json')) return utf8.encode(json.encode(manifest));
      return site[url.split('/').last.replaceAll('.ogg', '')];
    };
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('baixa na primeira vez e guarda; depois toca a guardada sem baixar de novo', () async {
    final path = await MusicCache.pathFor('map_kanto');
    expect(File(path!).readAsBytesSync(), [1, 2, 3]);
    asked.clear();
    MusicCache.reset(); // outra sessão
    expect(await MusicCache.pathFor('map_kanto'), path);
    expect(asked, ['music.json']); // só conferiu a lista
  });

  test('mudou no site (outro hash): baixa a nova, sem precisar de app novo', () async {
    await MusicCache.pathFor('map_kanto');
    manifest['map_kanto'] = 'bbb';
    site['map_kanto'] = [9, 9];
    MusicCache.reset();
    final path = await MusicCache.pathFor('map_kanto');
    expect(File(path!).readAsBytesSync(), [9, 9]);
  });

  test('sem internet: toca a guardada; sem nada guardado, fica sem música', () async {
    await MusicCache.pathFor('map_kanto');
    online = false;
    MusicCache.reset();
    expect(await MusicCache.pathFor('map_kanto'), isNotNull);
    expect(await MusicCache.pathFor('map_johto'), isNull);
  });

  test('a lista do site (music.json) bate com os arquivos de sounds/music', () {
    final music = Directory('assets/database/sounds/music');
    final list = (json.decode(File('${music.path}/music.json').readAsStringSync()) as Map).cast<String, String>();
    final files = music.listSync().whereType<File>().where((f) => f.path.endsWith('.ogg')).toList();
    expect(list.length, files.length);
    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.ogg', '');
      expect(list[name], sha1.convert(f.readAsBytesSync()).toString().substring(0, 12), reason: name);
    }
  });
}
