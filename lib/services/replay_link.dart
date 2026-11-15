// lib/services/replay_link.dart
//
// Replay por link: a batalha inteira (semente, times e jogadas, battle_log.dart)
// comprimida (deflate) em base64url num link do site. Quem abre assiste sem
// precisar de conta. Igual ao site (web-site/src/lib/replayLink.js).

import 'dart:convert';
import 'dart:io' show ZLibCodec;

class ReplayLink {
  ReplayLink._();

  static const _fields = ['seed', 'ai', 'foe', 'foeTrainer', 'mine', 'theirs', 'actions', 'result', 'turns', 'at'];
  static const siteUrl = 'https://octaviokonzen.github.io/Pocketdex/';
  static final _zlib = ZLibCodec(raw: true);

  /// O código do replay (só o que precisa para refazer a batalha).
  static String encode(Map<String, dynamic> record) {
    final data = {for (final k in _fields) if (record[k] != null) k: record[k]};
    return base64Url.encode(_zlib.encode(utf8.encode(jsonEncode(data)))).replaceAll('=', '');
  }

  /// De volta ao registro da batalha (null se o código não vale).
  static Map<String, dynamic>? decode(String code) {
    try {
      final padded = code + '=' * ((4 - code.length % 4) % 4);
      final record = jsonDecode(utf8.decode(_zlib.decode(base64Url.decode(padded)))) as Map<String, dynamic>;
      if (record['seed'] == null || (record['mine'] as List?)?.isNotEmpty != true || (record['theirs'] as List?)?.isNotEmpty != true) return null;
      return {'id': 'link', ...record};
    } catch (_) {
      return null;
    }
  }

  /// O link para assistir no site.
  static String url(String code) => '$siteUrl#/batalha/replay?d=$code';
}
