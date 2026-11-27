// lib/services/dex_marks.dart
//
// Visto × capturado na Pokédex (igual ao site, web-site/src/lib/dexMarks.js):
//   • capturado: a Coleção (todos os jogos, normal e shiny) e o Pokelike
//     (os comprados, os shinies e os capturados nas corridas);
//   • visto: os adversários das batalhas do Pokelike (e todo capturado).

class DexMarks {
  DexMarks._();

  static int _int(Object? v) => (v as num).toInt();

  static Set<int> caught(Map? collection, Map? league) {
    final ids = <int>{};
    for (final entry in (collection ?? const {}).values) {
      if (entry is! Map) continue;
      for (final key in ['c', 's']) {
        for (final id in (entry[key] as List?) ?? const []) {
          ids.add(_int(id));
        }
      }
    }
    final factory = league?['factory'] as Map?;
    for (final key in ['owned', 'shinies', 'caught']) {
      for (final id in (factory?[key] as List?) ?? const []) {
        ids.add(_int(id));
      }
    }
    return ids;
  }

  static Set<int> seen(Map? collection, Map? league) => {
        ...caught(collection, league),
        for (final id in ((league?['factory'] as Map?)?['seen'] as List?) ?? const []) _int(id),
      };
}
