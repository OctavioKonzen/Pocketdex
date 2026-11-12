// lib/services/public_profile.dart
//
// Perfil público. Igual ao site (web-site/src/lib/profile.js): o que aparece
// para quem abre o link /perfil/{uid}. Fica em profiles/{uid}, que qualquer um
// lê (até sem conta); só o dono grava (account_sync.dart).

import 'app_settings.dart';
import 'medals.dart';
import 'user_data.dart';

class PublicProfile {
  /// O link do perfil no site.
  static String link(String uid) => 'https://octaviokonzen.github.io/Pocketdex/#/perfil/$uid';

  static int _n(Object? x) => (x as num?)?.toInt() ?? 0;

  /// Os campos do perfil a partir dos dados da conta (sem o nome nem a data).
  static Map<String, dynamic> of(UserData data) {
    final league = data.league;
    final collection = (data['collection'] as Map?) ?? const {};
    final settings = AppSettings.instance;
    final theme = settings.themeId;
    return {
      'avatar': data.avatar,
      'trainer': data.trainer,
      'theme': theme,
      'shiny': theme != 0 && settings.themeShiny,
      'champion': settings.themeChampion,
      'ranked': data.rankedRecord,
      'factory': _n((league['factory'] as Map?)?['best']),
      'tower': _n((league['tower'] as Map?)?['best']),
      'badges': ((league['badges'] as Map?) ?? const {}).values.fold<int>(0, (n, b) => n + (b is List ? b.length : 0)),
      'hall': [
        for (final h in ((league['hall'] as List?) ?? const []).take(10))
          {'region': (h as Map)['region'], 'team': [for (final id in ((h['team'] as List?) ?? const []).take(6)) _n(id)]},
      ],
      'medals': [for (final (m, on) in Medals.of(league, collection)) if (on) m.id],
      'caught': {
        for (final g in collection.values)
          if (g is Map) ...[...(g['c'] as List? ?? const []), ...(g['s'] as List? ?? const [])],
      }.length,
    };
  }
}
