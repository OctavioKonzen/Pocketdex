// lib/services/dex_seals.dart
//
// Selos da Pokédex: completar os Pokémon de uma região (geração) ou de um tipo.
// "Capturado" é o mesmo da Pokédex (lib/services/dex_marks.dart). Só as formas
// normais (sem as regionais e as Megas) contam. Igual ao site (web-site/src/lib/dexSeals.js).

class DexSeal {
  const DexSeal(this.id, this.icon, this.label, this.ids);
  final String id;
  final String icon;
  final String label;
  final Set<int> ids;

  int have(Set<int> caught) => ids.where(caught.contains).length;
  bool done(Set<int> caught) => ids.isNotEmpty && have(caught) == ids.length;
}

class DexSeals {
  DexSeals._();

  /// As regiões: o último número da Pokédex de cada geração.
  static const regions = [
    ('kanto', 'Kanto', 151), ('johto', 'Johto', 251), ('hoenn', 'Hoenn', 386), ('sinnoh', 'Sinnoh', 493), ('unova', 'Unova', 649),
    ('kalos', 'Kalos', 721), ('alola', 'Alola', 809), ('galar', 'Galar', 905), ('paldea', 'Paldea', 1025),
  ];
  static const types = [
    'normal', 'fire', 'water', 'grass', 'electric', 'ice', 'fighting', 'poison', 'ground',
    'flying', 'psychic', 'bug', 'rock', 'ghost', 'dragon', 'dark', 'steel', 'fairy',
  ];
  static const _typeIcons = {
    'normal': '⚪', 'fire': '🔥', 'water': '💧', 'grass': '🌿', 'electric': '⚡', 'ice': '❄️', 'fighting': '🥊', 'poison': '☠️', 'ground': '⛰️',
    'flying': '🪶', 'psychic': '🔮', 'bug': '🐛', 'rock': '🪨', 'ghost': '👻', 'dragon': '🐉', 'dark': '🌑', 'steel': '⚙️', 'fairy': '🧚',
  };

  /// Os 27 selos (9 regiões e 18 tipos) a partir das linhas de pokemon.json.
  static List<DexSeal> build(List<Map<String, dynamic>> rows) {
    final base = [for (final r in rows) if (r['is_default'] == true && (r['id'] as num).toInt() <= 1025) r];
    var from = 1;
    final out = <DexSeal>[];
    for (final (id, label, last) in regions) {
      out.add(DexSeal(id, '🗺️', label, {for (final r in base) if ((r['id'] as num).toInt() >= from && (r['id'] as num).toInt() <= last) (r['id'] as num).toInt()}));
      from = last + 1;
    }
    for (final t in types) {
      out.add(DexSeal('type-$t', _typeIcons[t]!, '${t[0].toUpperCase()}${t.substring(1)}',
          {for (final r in base) if (((r['types'] as List?) ?? const []).contains(t)) (r['id'] as num).toInt()}));
    }
    return out;
  }

  /// Os selos completos (para o perfil público).
  static List<String> doneIds(List<DexSeal> seals, Set<int> caught) => [for (final s in seals) if (s.done(caught)) s.id];
}
