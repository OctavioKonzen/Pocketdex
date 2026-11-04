// lib/services/team_battle.dart
//
// Batalha de times (igual ao site, web-site/src/lib/teamBattle.js): cada
// Pokémon de um time contra cada um do outro, 1 contra 1. Com a calculadora
// de dano (a mesma do Showdown), vê o melhor golpe de cada lado e quantos
// golpes precisa para derrotar o outro; ganha quem derruba em menos golpes
// (empate: o mais rápido ataca primeiro e ganha).

import 'damage_calc.dart';
import 'local_database.dart';
import 'team_sets.dart';

/// Um Pokémon do time: id e o set (golpes, item, EVs...) se tiver.
typedef Member = (int id, Map<String, dynamic>? set);

class Hit {
  final String move;
  final double pct; // % médio da vida do outro
  final int hits; // golpes para derrotar (99 = não derrota)
  const Hit(this.move, this.pct, this.hits);
  static const none = Hit('', 0, 99);
}

class Duel {
  final Hit mine, theirs;
  final bool faster, sameSpeed;
  const Duel(this.mine, this.theirs, this.faster, this.sameSpeed);

  /// 1 = eu ganho, -1 = perco, 0 = empate.
  int get result {
    if (mine.hits == 99 && theirs.hits == 99) return 0;
    if (mine.hits != theirs.hits) return mine.hits < theirs.hits ? 1 : -1;
    if (sameSpeed) return 0;
    return faster ? 1 : -1;
  }
}

class _Fighter {
  final CalcPokemon pokemon;
  final List<String> moves; // nomes do Showdown
  _Fighter(this.pokemon, this.moves);
}

class TeamBattle {
  TeamBattle._();
  static const maxLevel = 50;
  static int battleLevel(Object? level) => level is num && level.isFinite ? level.toInt().clamp(1, maxLevel) : maxLevel;


  /// O Pokémon da calculadora com o set (Nature, EVs, IVs, item, habilidade).
  static Future<CalcPokemon?> calcPokemon(DamageData data, Member m) async {
    final row = await LocalDatabase.instance.pokemonRow(m.$1);
    if (row == null) return null;
    return _calcPokemon(data, row, m.$2);
  }

  static CalcPokemon _calcPokemon(DamageData data, Map<String, dynamic> row, Map<String, dynamic>? set) {
    final stats = [for (final s in row['stats'] as List) (s as List).first as int];
    Map<String, int>? spread(Object? v, int fallback) => v is Map ? {for (final k in statKeys) k: (v[k] as num?)?.toInt() ?? fallback} : null;
    final abilities = [for (final a in (row['abilities'] as List?) ?? const []) (a as List).first as String];
    final ability = data.abilityName('${set?['ability'] ?? ''}').isNotEmpty
        ? data.abilityName('${set?['ability']}')
        : (abilities.isEmpty ? '' : data.abilityName(abilities.first));
    return CalcPokemon(
      data,
      data.speciesName(row['name'] as String),
      baseStats: {for (var i = 0; i < 6; i++) statIds[i]: stats[i]},
      types: [for (final t in row['types'] as List) '${(t as String)[0].toUpperCase()}${t.substring(1)}'],
      weightkg: ((row['weight'] as num?) ?? 1000) / 10,
      // Battle Factory: o nível vai até 100 (levelCap 100) ou não tem limite ('none').
      level: set?['levelCap'] == 'none' || set?['levelCap'] == 100
          ? ((set?['level'] as num?)?.toInt() ?? 1).clamp(1, set?['levelCap'] == 'none' ? 9999 : 100)
          : battleLevel(set?['level']),
      ability: ability,
      item: data.itemName('${set?['item'] ?? ''}'),
      nature: '${set?['nature'] ?? 'Hardy'}',
      evs: spread(set?['evs'], 0),
      ivs: spread(set?['ivs'], 31),
    );
  }

  static Future<_Fighter?> _fighter(DamageData data, Member m) async {
    final row = await LocalDatabase.instance.pokemonRow(m.$1);
    if (row == null) return null;
    final set = m.$2;
    final pokemon = _calcPokemon(data, row, set);
    bool damaging(String slug) {
      final info = data.move(slug);
      return info != null && info.category != 'Status';
    }

    // Golpes do set; sem set, todos os de dano que ele aprende.
    final chosen = [for (final s in (set?['moves'] as List?) ?? const []) '$s'].where((s) => s.isNotEmpty && damaging(s)).toList();
    final learnable = _trim(data, {for (final mv in row['moves'] as List) (mv as List).first as String}.where(damaging));
    final moves = chosen.isNotEmpty ? chosen : learnable;
    return _Fighter(pokemon, [for (final s in moves) data.move(s)!.name]);
  }

  /// Sem set: os 2 golpes mais fortes de cada tipo e categoria (e os de dano
  /// fixo). Dá o mesmo melhor golpe com bem menos contas.
  static List<String> _trim(DamageData data, Iterable<String> slugs) {
    final groups = <String, List<String>>{};
    final fixed = <String>[];
    for (final slug in slugs) {
      final info = data.move(slug)!;
      if (info.basePower <= 0) {
        fixed.add(slug);
      } else {
        groups.putIfAbsent('${info.type}/${info.category}', () => []).add(slug);
      }
    }
    return [
      for (final g in groups.values) ...(g..sort((a, b) => data.move(b)!.basePower.compareTo(data.move(a)!.basePower))).take(2),
      ...fixed,
    ];
  }

  static Hit _best(DamageData data, _Fighter a, _Fighter b) {
    var best = Hit.none;
    for (final name in a.moves) {
      try {
        final move = CalcMove(data, name, ability: a.pokemon.ability, item: a.pokemon.item);
        final result = calculateDamage(a.pokemon.clone(), b.pokemon.clone(), move, CalcField());
        final (lo, hi) = result.range();
        final hp = result.defender.maxHP();
        final pct = (lo + hi) / 2 / hp * 100;
        if (pct > best.pct) best = Hit(name, pct, pct <= 0 ? 99 : (100 / pct).ceil().clamp(1, 98));
      } catch (_) {}
    }
    return best;
  }

  /// Todos os confrontos: [i][j] = meu Pokémon i contra o dele j.
  static Future<List<List<Duel?>>> run(List<Member> mine, List<Member> theirs) async {
    final data = await DamageData.load();
    final a = [for (final m in mine) await _fighter(data, m)];
    final b = [for (final m in theirs) await _fighter(data, m)];
    return [
      for (final x in a)
        [
          for (final y in b)
            if (x == null || y == null)
              null
            else
              () {
                final sx = x.pokemon.stats['spe']!, sy = y.pokemon.stats['spe']!;
                return Duel(_best(data, x, y), _best(data, y, x), sx > sy, sx == sy);
              }(),
        ],
    ];
  }

  /// Quem vence [targetId]: todos os Pokémon totalmente evoluídos contra ele,
  /// 1 contra 1 (nível 50, sem set). Os que ganham com mais folga primeiro.
  static Future<List<(int, Duel)>> counters(int targetId, {bool legendaries = false, void Function(double done)? progress}) async {
    final data = await DamageData.load();
    final target = await _fighter(data, (targetId, null));
    if (target == null) return const [];
    final rows = await LocalDatabase.instance.defaultPokemon();
    final species = await LocalDatabase.instance.speciesById();
    bool special(int id) => species[id]?['is_legendary'] == true || species[id]?['is_mythical'] == true;
    final pool = [
      for (final r in rows)
        if (r['id'] != targetId &&
            (legendaries || !special(r['id'] as int)) &&
            !(data.species[toId(data.speciesName(r['name'] as String))]?.nfe ?? false))
          r['id'] as int,
    ];
    final out = <(int, Duel)>[];
    for (var i = 0; i < pool.length; i++) {
      final x = await _fighter(data, (pool[i], null));
      if (x != null) {
        final sx = x.pokemon.stats['spe']!, sy = target.pokemon.stats['spe']!;
        final d = Duel(_best(data, x, target), _best(data, target, x), sx > sy, sx == sy);
        if (d.result == 1) out.add((pool[i], d));
      }
      // Deixa a tela respirar de vez em quando.
      if (i % 8 == 7) {
        progress?.call((i + 1) / pool.length);
        await Future<void>.delayed(Duration.zero);
      }
    }
    progress?.call(1);
    out.sort((a, b) {
      final ma = a.$2.theirs.hits - a.$2.mine.hits, mb = b.$2.theirs.hits - b.$2.mine.hits;
      if (ma != mb) return mb.compareTo(ma);
      return b.$2.mine.pct.compareTo(a.$2.mine.pct);
    });
    return out;
  }
}
