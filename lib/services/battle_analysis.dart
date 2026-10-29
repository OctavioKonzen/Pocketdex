// lib/services/battle_analysis.dart
//
// A análise do fim da batalha. Igual ao site (web-site/src/lib/battleAnalysis.js):
// quem varreu o seu time e em que turno a batalha virou, a partir dos nocautes.

import '../i18n/i18n.dart';

/// Um nocaute: o turno, o lado de quem caiu e quem derrubou (lado, índice).
typedef BattleKo = ({int turn, int side, (int, int)? by});

class BattleAnalysis {
  /// As frases da análise: (ícone, texto). names[lado][índice] → nome.
  static List<(String, String)> of(List<BattleKo> kos, List<int> sizes, List<List<String>> names, int? winner) {
    final out = <(String, String)>[];
    // Quem mais derrubou do seu time (a partir de 2).
    final byFoe = <int, int>{};
    for (final k in kos) {
      if (k.side == 0 && k.by?.$1 == 1) byFoe[k.by!.$2] = (byFoe[k.by!.$2] ?? 0) + 1;
    }
    final top = (byFoe.entries.toList()..sort((a, b) => b.value - a.value)).firstOrNull;
    if (top != null && top.value >= 2) {
      out.add(('🌪️', tr('{0} derrubou {1} do seu time.').replaceAll('{0}', names[1][top.key]).replaceAll('{1}', '${top.value}')));
    }
    // A virada: o turno em que um lado passou a ter menos Pokémon de pé e não recuperou mais.
    final left = [...sizes];
    int? behindSince, aheadSince;
    var wasBehind = false;
    for (final k in kos) {
      left[k.side] -= 1;
      if (left[0] < left[1]) {
        behindSince ??= k.turn;
        aheadSince = null;
        wasBehind = true;
      } else {
        behindSince = null;
        if (left[0] > left[1]) aheadSince ??= k.turn;
      }
    }
    if (winner == 1 && behindSince != null) {
      out.add(('📉', tr('A batalha virou no turno {0}: daí em diante o adversário ficou com mais Pokémon de pé.').replaceAll('{0}', '$behindSince')));
    } else if (winner == 0 && wasBehind && aheadSince != null) {
      out.add(('📈', tr('Virada! Você estava atrás e passou à frente no turno {0}.').replaceAll('{0}', '$aheadSince')));
    } else if (winner == 0 && !wasBehind && kos.isNotEmpty) {
      out.add(('🛡️', tr('Você não ficou atrás em nenhum momento.')));
    }
    if (winner == 1) {
      final mineDown = kos.any((k) => k.side == 0);
      final foeDown = kos.where((k) => k.side == 1).length;
      if (mineDown && foeDown < sizes[1]) out.add(('🎯', tr('Faltaram {0} Pokémon do adversário.').replaceAll('{0}', '${sizes[1] - foeDown}')));
    }
    return out;
  }
}
