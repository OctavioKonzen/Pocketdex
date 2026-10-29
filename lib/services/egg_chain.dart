// lib/services/egg_chain.dart
//
// Cadeia de golpes de ovo (igual ao site, web-site/src/lib/eggChain.js): para
// ensinar um golpe de ovo a um filhote, o pai precisa saber o golpe. Se
// nenhum pai compatível aprende o golpe sozinho (nível, TM ou tutor), o pai
// pode ter recebido o golpe de ovo do pai dele, e assim por diante.
//
// Regras: pai e filhote dividem um grupo de ovo; o pai precisa poder ser
// macho (nem só fêmea, nem sem gênero) e não pode ser dos grupos "no-eggs" ou
// "ditto".

import 'local_database.dart';

/// Um elo da cadeia: o Pokémon e como ele sabe o golpe ('level-up' com o
/// nível, 'machine', 'tutor' ou 'egg' = recebeu do pai de cima).
class EggLink {
  final int id;
  final String method;
  final int level;
  const EggLink(this.id, this.method, [this.level = 0]);
}

class EggChains {
  EggChains._();

  static const _direct = {'level-up', 'machine', 'tutor'};

  /// Golpes de ovo do Pokémon [id] (slugs, em ordem alfabética).
  static Future<List<String>> eggMoves(int id) async {
    final row = await LocalDatabase.instance.pokemonRow(id);
    return {
      for (final m in (row?['moves'] as List?) ?? const [])
        if ((m as List)[1] == 'egg') m[0] as String,
    }.toList()
      ..sort();
  }

  /// Cadeias mais curtas (até [maxDepth] pais) para ensinar [move] a [targetId].
  /// Cada cadeia vai do primeiro pai (que aprende sozinho) até o pai direto.
  static Future<List<List<EggLink>>> find(int targetId, String move, {int maxDepth = 3, int limit = 12}) async {
    final db = LocalDatabase.instance;
    final species = await db.speciesById();
    final rows = await db.defaultPokemon();
    final byId = {for (final r in rows) r['id'] as int: r};

    List<String> groups(int id) {
      final g = ((species[id]?['egg_groups'] as List?) ?? const []).cast<String>();
      if (!g.contains('no-eggs')) return g;
      // Filhote (Pichu...): usa os grupos de quem ele vira.
      for (final e in species.entries) {
        if (e.value['evolves_from'] == id) return groups(e.key);
      }
      return g;
    }

    bool canFather(int id) {
      final rate = (species[id]?['gender_rate'] as num?)?.toInt() ?? -1;
      final g = groups(id);
      return rate >= 0 && rate < 8 && !g.contains('no-eggs') && !g.contains('ditto');
    }

    EggLink? howKnows(int id) {
      EggLink? best;
      for (final m in (byId[id]?['moves'] as List?) ?? const []) {
        if ((m as List)[0] != move) continue;
        final method = m[1] as String;
        if (_direct.contains(method)) {
          final link = EggLink(id, method, (m[2] as num?)?.toInt() ?? 0);
          if (best == null || best.method != 'level-up') best = link;
        } else if (method == 'egg' && best == null) {
          best = EggLink(id, 'egg');
        }
      }
      return best;
    }

    // Busca em largura: cada nível é mais um pai na cadeia.
    final chains = <List<EggLink>>[];
    final seen = <int>{targetId};
    var frontier = <List<EggLink>>[
      [EggLink(targetId, 'egg')],
    ];
    for (var depth = 0; depth < maxDepth && chains.isEmpty && frontier.isNotEmpty; depth++) {
      final next = <List<EggLink>>[];
      for (final path in frontier) {
        final child = path.first.id;
        final childGroups = groups(child).toSet();
        for (final id in byId.keys) {
          if (seen.contains(id) || !canFather(id) || !groups(id).any(childGroups.contains)) continue;
          final how = howKnows(id);
          if (how == null) continue;
          if (how.method == 'egg') {
            next.add([how, ...path]);
          } else {
            chains.add([how, ...path.sublist(0, path.length - 1)]);
          }
        }
      }
      for (final p in next) {
        seen.add(p.first.id);
      }
      frontier = next;
    }
    // Quem aprende por nível primeiro (e mais cedo).
    chains.sort((a, b) {
      final la = a.first.method == 'level-up' ? a.first.level : 999, lb = b.first.method == 'level-up' ? b.first.level : 999;
      return la.compareTo(lb);
    });
    return chains.take(limit).toList();
  }
}
